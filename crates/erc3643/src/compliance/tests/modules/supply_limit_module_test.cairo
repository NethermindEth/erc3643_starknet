use crate::compliance::tests::modular_compliance_test::{Setup as MCSetup, setup as mc_setup};
use crate::compliance::{
    imodular_compliance::IModularComplianceDispatcherTrait,
    modules::{
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
        supply_limit_module::ISupplyLimitModuleDispatcher,
    },
};
use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;

#[derive(Drop, Copy)]
struct Setup {
    mc_setup: MCSetup,
    module: ISupplyLimitModuleDispatcher,
    mock_contract: ContractAddress,
}

pub fn setup() -> Setup {
    let mc_setup = mc_setup();

    let compliance_module_contract = declare("SupplyLimitModule").unwrap().contract_class();
    let (deployed_address, _) = compliance_module_contract
        .deploy(@array![starknet::get_contract_address().into()])
        .unwrap();

    let (mock_contract, _) = declare("MockContract")
        .unwrap()
        .contract_class()
        .deploy(@array![])
        .unwrap();

    mc_setup.compliance.bind_token(mock_contract);
    mc_setup.compliance.add_module(deployed_address);

    Setup {
        mc_setup,
        module: ISupplyLimitModuleDispatcher { contract_address: deployed_address },
        mock_contract,
    }
}

#[test]
fn test_should_deploy_the_supply_limit_contract_and_bind_it_to_the_compliance() {
    let setup = setup();
    assert(
        setup.mc_setup.compliance.is_module_bound(setup.module.contract_address),
        'Compliance module not bound',
    );
}

#[test]
fn test_should_return_the_name_of_the_module() {
    let setup = setup();
    let module_dispatcher = IModuleDispatcher { contract_address: setup.module.contract_address };
    assert(module_dispatcher.name() == "SupplyLimitModule", 'Names does not match!');
}

#[test]
fn test_is_plug_and_play_should_return_true() {
    let setup = setup();
    let module_dispatcher = IModuleDispatcher { contract_address: setup.module.contract_address };
    assert(module_dispatcher.is_plug_and_play(), 'Is not plug and play');
}

#[test]
fn test_can_compliance_bind_should_return_true() {
    let setup = setup();
    let module_dispatcher = IModuleDispatcher { contract_address: setup.module.contract_address };
    assert(
        module_dispatcher.can_compliance_bind(setup.mc_setup.compliance.contract_address),
        'Compliance cannot bind',
    );
}

#[test]
fn test_should_return_owner() {
    let setup = setup();
    let ownable_dispatcher = IOwnableDispatcher { contract_address: setup.module.contract_address };
    assert(ownable_dispatcher.owner() == starknet::get_contract_address(), 'Owner does not match');
}

pub mod transfer_ownership {
    use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_not_called_by_owner() {
        let setup = setup();

        let ownable_dispatcher = IOwnableDispatcher {
            contract_address: setup.module.contract_address,
        };
        start_cheat_caller_address(ownable_dispatcher.contract_address, setup.mc_setup.bob);
        ownable_dispatcher.transfer_ownership(setup.mc_setup.alice);
        stop_cheat_caller_address(ownable_dispatcher.contract_address);
    }

    #[test]
    fn test_should_transfer_ownership_when_called_by_owner() {
        let setup = setup();

        let ownable_dispatcher = IOwnableDispatcher {
            contract_address: setup.module.contract_address,
        };
        ownable_dispatcher.transfer_ownership(setup.mc_setup.alice);
        assert(ownable_dispatcher.owner() == setup.mc_setup.alice, 'Ownership didnt transferred');
    }
}

pub mod upgrade {
    use openzeppelin_upgrades::interface::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};
    use snforge_std::{get_class_hash, start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_not_called_by_owner() {
        let setup = setup();
        let upgradeable_dispatcher = IUpgradeableDispatcher {
            contract_address: setup.module.contract_address,
        };
        let new_class_hash = get_class_hash(setup.mock_contract);

        start_cheat_caller_address(upgradeable_dispatcher.contract_address, setup.mc_setup.bob);
        upgradeable_dispatcher.upgrade(new_class_hash);
        stop_cheat_caller_address(upgradeable_dispatcher.contract_address);
    }

    #[test]
    fn test_should_upgrade() {
        let setup = setup();
        let upgradeable_dispatcher = IUpgradeableDispatcher {
            contract_address: setup.module.contract_address,
        };
        let new_class_hash = get_class_hash(setup.mock_contract);

        upgradeable_dispatcher.upgrade(new_class_hash);
        assert(
            get_class_hash(upgradeable_dispatcher.contract_address) == new_class_hash,
            'Contract not upgraded',
        );
    }
}

pub mod set_supply_limit {
    use crate::compliance::modules::supply_limit_module::{
        ISupplyLimitModuleDispatcherTrait, SupplyLimitModule,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        let setup = setup();

        setup.module.set_supply_limit(100);
    }

    #[test]
    fn test_should_set_supply_limit() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;
        let limit = 100;

        let mut spy = spy_events();
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_supply_limit(limit);
        stop_cheat_caller_address(setup.module.contract_address);

        assert(setup.module.get_supply_limit(compliance) == limit, 'Supply limits does not match');

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        SupplyLimitModule::Event::SupplyLimitSet(
                            SupplyLimitModule::SupplyLimitSet { compliance, limit },
                        ),
                    ),
                ],
            );
    }
}

pub mod get_supply_limit {
    use crate::compliance::modules::supply_limit_module::ISupplyLimitModuleDispatcherTrait;
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    fn test_should_return_supply_limit() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;
        let limit = 1600;

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_supply_limit(limit);
        stop_cheat_caller_address(setup.module.contract_address);

        assert(setup.module.get_supply_limit(compliance) == limit, 'Supply limits does not match');
    }
}

pub mod module_check {
    use core::num::traits::Zero;
    use crate::compliance::modules::imodule::{IModuleDispatcher, IModuleDispatcherTrait};
    use crate::compliance::modules::supply_limit_module::ISupplyLimitModuleDispatcherTrait;
    use snforge_std::{mock_call, start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    fn test_should_return_false_when_value_exceeds_compliance_supply_limit() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        let to = setup.mc_setup.alice;
        let from = Zero::zero();
        let limit = 1600;
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        mock_call(setup.mock_contract, selector!("total_supply"), limit, 1);
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_supply_limit(limit);
        stop_cheat_caller_address(setup.module.contract_address);

        let check_result = module_dispatcher.module_check(from, to, 100, compliance);
        assert(!check_result, 'Should return false');
    }

    #[test]
    fn test_should_return_true_when_supply_limit_does_not_exceed() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        let to = setup.mc_setup.alice;
        let from = Zero::zero();
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        mock_call(setup.mock_contract, selector!("total_supply"), 1500_u256, 1);
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_supply_limit(1600);
        stop_cheat_caller_address(setup.module.contract_address);

        let check_result = module_dispatcher.module_check(from, to, 100, compliance);
        assert(check_result, 'Should return true');
    }
}

pub mod module_burn_action {
    use crate::compliance::modules::imodule::{IModuleDispatcher, IModuleDispatcherTrait};
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        module_dispatcher.module_burn_action(setup.mc_setup.another_wallet, 10);
    }

    #[test]
    fn test_should_do_nothing() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        module_dispatcher.module_burn_action(setup.mc_setup.another_wallet, 10);
        stop_cheat_caller_address(setup.module.contract_address);
    }
}

pub mod module_mint_action {
    use crate::compliance::modules::imodule::{IModuleDispatcher, IModuleDispatcherTrait};
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        module_dispatcher.module_mint_action(setup.mc_setup.another_wallet, 10);
    }

    #[test]
    fn test_should_do_nothing() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        module_dispatcher.module_mint_action(setup.mc_setup.another_wallet, 10);
        stop_cheat_caller_address(setup.module.contract_address);
    }
}

pub mod module_transfer_action {
    use crate::compliance::modules::imodule::{IModuleDispatcher, IModuleDispatcherTrait};
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        module_dispatcher.module_transfer_action(setup.mc_setup.alice, setup.mc_setup.bob, 10);
    }

    #[test]
    fn test_should_do_nothing() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        module_dispatcher.module_transfer_action(setup.mc_setup.alice, setup.mc_setup.bob, 10);
        stop_cheat_caller_address(setup.module.contract_address);
    }
}
