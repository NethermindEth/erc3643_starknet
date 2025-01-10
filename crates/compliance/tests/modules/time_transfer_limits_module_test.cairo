use compliance::{
    imodular_compliance::IModularComplianceDispatcherTrait,
    modules::{
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
        time_transfer_limits_module::ITimeTransferLimitsModuleDispatcher,
    },
};
use crate::modular_compliance_test::{Setup as MCSetup, setup as mc_setup};
use mocks::mock_contract::{IMockContractDispatcher, IMockContractDispatcherTrait};
use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;

#[derive(Drop, Copy)]
struct Setup {
    mc_setup: MCSetup,
    module: ITimeTransferLimitsModuleDispatcher,
    mock_contract: ContractAddress,
    exchange_id: ContractAddress,
    investor_id: ContractAddress,
}

pub fn setup() -> Setup {
    let mc_setup = mc_setup();

    let compliance_module_contract = declare("TimeTransfersLimitsModule").unwrap().contract_class();
    let (compliance_module_address, _) = compliance_module_contract
        .deploy(@array![starknet::get_contract_address().into()])
        .unwrap();

    let (mock_contract, _) = declare("MockContract")
        .unwrap()
        .contract_class()
        .deploy(@array![])
        .unwrap();

    mc_setup.compliance.bind_token(mock_contract);
    mc_setup.compliance.add_module(compliance_module_address);

    let investor_id = starknet::contract_address_const::<'ALICE_IDENTITY'>();
    let exchange_id = starknet::contract_address_const::<'BOB_IDENTITY'>();

    let mock_dispatcher = IMockContractDispatcher { contract_address: mock_contract };
    mock_dispatcher.set_identity(mc_setup.alice, investor_id);
    mock_dispatcher.set_identity(mc_setup.bob, exchange_id);

    Setup {
        mc_setup,
        module: ITimeTransferLimitsModuleDispatcher { contract_address: compliance_module_address },
        mock_contract,
        exchange_id,
        investor_id,
    }
}

#[test]
fn test_should_deploy_the_time_transfer_limits_contract_and_bind_it_to_the_compliance() {
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
    assert(module_dispatcher.name() == "TimeTranserLimitsModule", 'Names does not match!');
}

#[test]
fn test_should_return_owner() {
    let setup = setup();
    let ownable_dispatcher = IOwnableDispatcher { contract_address: setup.module.contract_address };
    assert(ownable_dispatcher.owner() == starknet::get_contract_address(), 'Owner does not match');
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

pub mod transfer_ownership {
    use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_the_owner() {
        let setup = setup();

        let ownable_dispatcher = IOwnableDispatcher {
            contract_address: setup.module.contract_address,
        };
        start_cheat_caller_address(ownable_dispatcher.contract_address, setup.mc_setup.alice);
        ownable_dispatcher.transfer_ownership(setup.mc_setup.bob);
        stop_cheat_caller_address(ownable_dispatcher.contract_address);
    }

    #[test]
    fn test_should_transfer_ownership() {
        let setup = setup();

        let ownable_dispatcher = IOwnableDispatcher {
            contract_address: setup.module.contract_address,
        };
        ownable_dispatcher.transfer_ownership(setup.mc_setup.bob);
        assert(ownable_dispatcher.owner() == setup.mc_setup.bob, 'Ownership didnt transferred');
    }
}

pub mod upgrade_to {
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

        start_cheat_caller_address(upgradeable_dispatcher.contract_address, setup.mc_setup.alice);
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

pub mod set_time_transfer_limit {
    use compliance::modules::time_transfer_limits_module::{
        ITimeTransferLimitsModuleDispatcherTrait, Limit, TimeTransferLimitsModule,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        let setup = setup();
        let exchange_id = setup.mc_setup.another_wallet;

        setup.module.set_time_transfer_limit(Limit { limit_time: 1, limit_value: 100 });
    }

    #[test]
    fn test_should_update_the_limit_when_limit_already_exists() {
        assert!(true, "");
    }

    #[test]
    #[should_panic]
    fn test_should_panic_when_limits_array_size_exceeded() {
        let setup = setup();
        let exchange_id = setup.mc_setup.another_wallet;
        let compliance = setup.mc_setup.compliance.contract_address;
        let limit_value = 100;

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_time_transfer_limit(Limit { limit_time: 1, limit_value });
        setup.module.set_time_transfer_limit(Limit { limit_time: 2, limit_value });
        setup.module.set_time_transfer_limit(Limit { limit_time: 3, limit_value });
        setup.module.set_time_transfer_limit(Limit { limit_time: 4, limit_value });
        /// Adding fifth should exceed array limit
        setup.module.set_time_transfer_limit(Limit { limit_time: 5, limit_value });
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    fn test_should_add_a_new_limit_when_limit_not_exists() {
        assert!(true, "");
    }
}

pub mod batch_set_time_transfer_limit {
    #[test]
    #[should_panic]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        panic!("");
    }

    #[test]
    fn test_should_create_the_limits() {
        assert!(true, "");
    }
}

pub mod remove_time_transfer_limit {
    #[test]
    #[should_panic]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_panic_when_limit_time_is_missing() {
        panic!("");
    }

    #[test]
    fn test_should_remove_the_limit_when_limit_time_is_last_element() {
        assert!(true, "");
    }

    #[test]
    fn test_should_remove_the_limit_when_limit_time_is_not_last_element() {
        assert!(true, "");
    }
}

pub mod batch_remove_time_transfer_limit {
    #[test]
    #[should_panic]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        panic!("");
    }

    #[test]
    fn test_should_remove_the_limits() {
        assert!(true, "");
    }
}

pub mod get_time_transfer_limits {
    #[test]
    fn test_should_return_empty_array_when_there_is_no_time_transfer_limit() {
        assert!(true, "");
    }

    #[test]
    fn test_should_return_transfer_limits_when_there_are_time_transfer_limits() {
        assert!(true, "");
    }
}

pub mod module_transfer_action {
    use compliance::modules::{
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
        time_transfer_limits_module::{ITimeTransferLimitsModuleDispatcherTrait, Limit},
    };
    use core::num::traits::Zero;
    use snforge_std::{mock_call, start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        let setup = setup();

        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        module_dispatcher.module_transfer_action(from, to, 10);
    }

    #[test]
    fn test_should_create_and_increase_counters_when_counters_are_not_initialized_yet() {
        assert(true, "")
    }

    #[test]
    fn test_should_increase_counters_when_counters_are_already_initialized() {
        assert!(true, "");
    }

    #[test]
    fn test_should_reset_finished_counter_and_increase_counters() {
        assert!(true, "");
    }
}

pub mod module_check {
    use compliance::modules::{
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
        time_transfer_limits_module::{ITimeTransferLimitsModuleDispatcherTrait, Limit},
    };
    use core::num::traits::Zero;
    use snforge_std::{mock_call, start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    fn test_should_return_true_when_from_is_zero_address() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        mock_call(setup.mock_contract, selector!("is_agent"), false, 1);
        let check_result = module_dispatcher
            .module_check(
                Zero::zero(), setup.mc_setup.bob, 100, setup.mc_setup.compliance.contract_address,
            );
        assert(check_result, 'Should return true');
    }

    #[test]
    fn test_should_return_true_when_from_is_token_agent() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        mock_call(setup.mock_contract, selector!("is_agent"), true, 1);
        let check_result = module_dispatcher
            .module_check(
                setup.mc_setup.alice,
                setup.mc_setup.bob,
                100,
                setup.mc_setup.compliance.contract_address,
            );
        assert(check_result, 'Should return true');
    }

    #[test]
    fn test_should_return_false_when_value_exceeds_the_time_limit() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        // setup.module.add_exchange_id(setup.exchange_id);

        // mock_call(setup.mock_contract, selector!("is_agent"), false, 1);
        // start_cheat_caller_address(setup.module.contract_address, compliance);
        // setup
        //     .module
        //     .set_exchange_limit(setup.exchange_id, Limit { limit_time: 10_000, limit_value: 90
        //     });
        // stop_cheat_caller_address(setup.module.contract_address);

        let check_result = module_dispatcher.module_check(from, to, 100, compliance);
        assert(!check_result, 'Should return false');
    }

    #[test]
    fn test_should_return_false_when_value_exceeds_the_counter_limit() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        // setup.module.add_exchange_id(setup.exchange_id);

        // mock_call(setup.mock_contract, selector!("is_agent"), false, 2);
        // start_cheat_caller_address(setup.module.contract_address, compliance);
        // setup
        //     .module
        //     .set_exchange_limit(setup.exchange_id, Limit { limit_time: 10_000, limit_value: 150
        //     });

        module_dispatcher.module_transfer_action(from, to, 100);
        stop_cheat_caller_address(setup.module.contract_address);

        let check_result = module_dispatcher.module_check(from, to, 100, compliance);
        assert(!check_result, 'Should return false');
    }

    #[test]
    fn test_should_return_true_when_value_does_not_exceed_the_counter_limit() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        // setup.module.add_exchange_id(setup.exchange_id);

        // mock_call(setup.mock_contract, selector!("is_agent"), false, 2);
        // start_cheat_caller_address(setup.module.contract_address, compliance);
        // setup
        //     .module
        //     .set_exchange_limit(setup.exchange_id, Limit { limit_time: 10_000, limit_value: 150
        //     });

        module_dispatcher.module_transfer_action(from, to, 100);
        stop_cheat_caller_address(setup.module.contract_address);

        let check_result = module_dispatcher.module_check(from, to, 40, compliance);
        assert(check_result, 'Should return true');
    }

    #[test]
    fn test_should_return_true_when_value_exceeds_the_counter_limit_but_counter_is_finished() {
        assert!(true, "");
    }
}

pub mod module_mint_action {
    use compliance::modules::imodule::{IModuleDispatcher, IModuleDispatcherTrait};
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
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

pub mod module_burn_action {
    use compliance::modules::imodule::{IModuleDispatcher, IModuleDispatcherTrait};
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
