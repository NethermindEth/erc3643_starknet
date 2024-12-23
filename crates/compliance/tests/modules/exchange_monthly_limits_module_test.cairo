use compliance::{
    imodular_compliance::IModularComplianceDispatcherTrait,
    modules::{
        exchange_monthly_limits_module::IExchangeMonthlyLimitsModuleDispatcher,
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
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
    module: IExchangeMonthlyLimitsModuleDispatcher,
    mock_contract: ContractAddress,
    exchange_id: ContractAddress,
    investor_id: ContractAddress,
}

pub fn setup() -> Setup {
    let mc_setup = mc_setup();

    let compliance_module_contract = declare("ExchangeMonthlyLimitsModule")
        .unwrap()
        .contract_class();
    let (deployed_address, _) = compliance_module_contract
        .deploy(@array![starknet::get_contract_address().into()])
        .unwrap();

    mc_setup.compliance.add_module(deployed_address);

    let (mock_contract, _) = declare("MockContract")
        .unwrap()
        .contract_class()
        .deploy(@array![])
        .unwrap();

    let exchange_id = starknet::contract_address_const::<'BOB_IDENTITY'>();
    let investor_id = starknet::contract_address_const::<'ALICE_IDENTITY'>();

    let mock_dispatcher = IMockContractDispatcher { contract_address: mock_contract };
    mock_dispatcher.set_identity(mc_setup.alice, investor_id);
    mock_dispatcher.set_identity(mc_setup.bob, exchange_id);

    mc_setup.compliance.bind_token(mock_contract);

    Setup {
        mc_setup,
        module: IExchangeMonthlyLimitsModuleDispatcher { contract_address: deployed_address },
        mock_contract,
        investor_id,
        exchange_id,
    }
}

#[test]
fn test_should_return_the_name_of_the_module() {
    let setup = setup();
    let module_dispatcher = IModuleDispatcher { contract_address: setup.module.contract_address };
    assert(module_dispatcher.name() == "ExchangeMonthlyLimitsModule", 'Names does not match!');
}

#[test]
fn test_plug_and_play_should_return_true() {
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

pub mod set_exchange_monthly_limit {
    use compliance::modules::exchange_monthly_limits_module::{
        ExchangeMonthlyLimitsModule, IExchangeMonthlyLimitsModuleDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        let setup = setup();

        setup.module.set_exchange_monthly_limit(setup.mc_setup.another_wallet, 1);
    }

    #[test]
    fn test_should_update_the_limit() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        let exchange_id = setup.mc_setup.another_wallet;
        let mut spy = spy_events();

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_exchange_monthly_limit(exchange_id, 1);
        stop_cheat_caller_address(setup.module.contract_address);

        assert(
            setup.module.get_exchange_monthly_limit(compliance, exchange_id) == 1,
            'Limits does not match',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        ExchangeMonthlyLimitsModule::Event::ExchangeMonthlyLimitUpdated(
                            ExchangeMonthlyLimitsModule::ExchangeMonthlyLimitUpdated {
                                compliance, exchange_id, new_exchange_monthly_limit: 1,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod get_exchange_monthly_limit {
    use compliance::modules::exchange_monthly_limits_module::IExchangeMonthlyLimitsModuleDispatcherTrait;
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    fn test_should_return_monthly_limit() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        let exchange_id = setup.mc_setup.another_wallet;

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_exchange_monthly_limit(exchange_id, 100);
        stop_cheat_caller_address(setup.module.contract_address);

        assert(
            setup.module.get_exchange_monthly_limit(compliance, exchange_id) == 100,
            'Limits does not match',
        );
    }
}

pub mod add_exchange_id {
    use compliance::modules::exchange_monthly_limits_module::{
        ExchangeMonthlyLimitsModule, IExchangeMonthlyLimitsModuleDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_the_owner() {
        let setup = setup();

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.alice);
        setup.module.add_exchange_id(setup.mc_setup.another_wallet);
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    fn test_should_tag_onchainid_as_exchange_when_exchange_id_is_not_tagged() {
        let setup = setup();

        let exchange_id = setup.mc_setup.another_wallet;
        let mut spy = spy_events();

        setup.module.add_exchange_id(setup.mc_setup.another_wallet);

        assert(setup.module.is_exchange_id(setup.mc_setup.another_wallet), 'Exchange id not added');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        ExchangeMonthlyLimitsModule::Event::ExchangeIDAdded(
                            ExchangeMonthlyLimitsModule::ExchangeIDAdded {
                                new_exchange_id: exchange_id,
                            },
                        ),
                    ),
                ],
            );
    }

    /// TODO: assert for exact error message. use safe-dispatcher
    #[test]
    #[should_panic]
    fn test_should_panic_when_exchange_id_is_already_tagged() {
        let setup = setup();

        let exchange_id = setup.mc_setup.another_wallet;

        setup.module.add_exchange_id(exchange_id);
        /// Adding second time should panic
        setup.module.add_exchange_id(exchange_id);
    }
}

pub mod remove_exchange_id {
    use compliance::modules::exchange_monthly_limits_module::{
        ExchangeMonthlyLimitsModule, IExchangeMonthlyLimitsModuleDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_the_owner() {
        let setup = setup();

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.alice);
        setup.module.remove_exchange_id(setup.mc_setup.another_wallet);
        stop_cheat_caller_address(setup.module.contract_address);
    }

    /// TODO:  Assert exact error message. Use safe-dispatcher
    #[test]
    #[should_panic]
    fn test_should_panic_when_exchange_id_is_not_being_tagged() {
        let setup = setup();

        setup.module.remove_exchange_id(setup.mc_setup.another_wallet);
    }

    #[test]
    fn test_should_untag_the_exchange_id_when_exchange_id_is_tagged() {
        let setup = setup();

        let exchange_id = setup.mc_setup.another_wallet;
        setup.module.add_exchange_id(exchange_id);

        let mut spy = spy_events();
        setup.module.remove_exchange_id(exchange_id);

        assert(!setup.module.is_exchange_id(exchange_id), 'Exchange id not removed');

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        ExchangeMonthlyLimitsModule::Event::ExchangeIDRemoved(
                            ExchangeMonthlyLimitsModule::ExchangeIDRemoved { exchange_id },
                        ),
                    ),
                ],
            );
    }
}

pub mod is_exchange_id {
    use compliance::modules::exchange_monthly_limits_module::IExchangeMonthlyLimitsModuleDispatcherTrait;
    use super::setup;

    #[test]
    fn test_should_return_false_when_exchange_id_is_not_tagged() {
        let setup = setup();

        let exchange_id = setup.mc_setup.another_wallet;
        assert(!setup.module.is_exchange_id(exchange_id), 'Should return false');
    }

    #[test]
    fn test_should_return_true_when_exchange_id_is_tagged() {
        let setup = setup();

        let exchange_id = setup.mc_setup.another_wallet;
        setup.module.add_exchange_id(exchange_id);
        assert(setup.module.is_exchange_id(exchange_id), 'Should return true');
    }
}

pub mod module_transfer_action {
    use compliance::modules::{
        exchange_monthly_limits_module::IExchangeMonthlyLimitsModuleDispatcherTrait,
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
    };
    use core::num::traits::Zero;
    use snforge_std::{mock_call, start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        module_dispatcher.module_transfer_action(setup.mc_setup.alice, setup.mc_setup.bob, 10);
    }

    #[test]
    fn test_should_increase_exchange_counter_when_exchange_monthly_limit_not_exceeded() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        mock_call(setup.mock_contract, selector!("is_agent"), false, 1);
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        setup.module.add_exchange_id(setup.exchange_id);
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_exchange_monthly_limit(setup.exchange_id, 100);

        module_dispatcher.module_transfer_action(setup.mc_setup.alice, setup.mc_setup.bob, 10);
        stop_cheat_caller_address(setup.module.contract_address);
        let counter = setup
            .module
            .get_monthly_counter(compliance, setup.exchange_id, setup.investor_id);
        assert(counter == 10, 'Counter not increased');
    }

    #[test]
    fn test_should_set_monthly_timer_when_exchange_month_is_finished() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        mock_call(setup.mock_contract, selector!("is_agent"), false, 1);
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        setup.module.add_exchange_id(setup.exchange_id);
        start_cheat_caller_address(setup.module.contract_address, compliance);

        module_dispatcher.module_transfer_action(setup.mc_setup.alice, setup.mc_setup.bob, 10);
        stop_cheat_caller_address(setup.module.contract_address);
        let timer = setup
            .module
            .get_monthly_timer(compliance, setup.exchange_id, setup.investor_id);
        assert(timer.is_non_zero(), 'Timer resetted');
    }

    #[test]
    fn test_should_not_update_monthly_timer_when_exchange_month_is_not_finished() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        mock_call(setup.mock_contract, selector!("is_agent"), false, 2);
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        setup.module.add_exchange_id(setup.exchange_id);
        start_cheat_caller_address(setup.module.contract_address, compliance);

        module_dispatcher.module_transfer_action(setup.mc_setup.alice, setup.mc_setup.bob, 10);
        let previous_timer = setup
            .module
            .get_monthly_timer(compliance, setup.exchange_id, setup.investor_id);

        module_dispatcher.module_transfer_action(setup.mc_setup.alice, setup.mc_setup.bob, 11);
        stop_cheat_caller_address(setup.module.contract_address);
        let timer = setup
            .module
            .get_monthly_timer(compliance, setup.exchange_id, setup.investor_id);
        assert(timer == previous_timer, 'Monthly timer updated');
    }

    #[test]
    fn test_should_not_set_limits_when_sender_is_a_token_agent() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        mock_call(setup.mock_contract, selector!("is_agent"), true, 1);
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        setup.module.add_exchange_id(setup.exchange_id);
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_exchange_monthly_limit(setup.exchange_id, 100);

        module_dispatcher.module_transfer_action(setup.mc_setup.alice, setup.mc_setup.bob, 10);
        stop_cheat_caller_address(setup.module.contract_address);

        let counter = setup
            .module
            .get_monthly_counter(compliance, setup.exchange_id, setup.investor_id);
        assert(counter.is_zero(), 'Monthly counter set');

        let timer = setup
            .module
            .get_monthly_timer(compliance, setup.exchange_id, setup.investor_id);
        assert(timer.is_zero(), 'Monthly timer set');
    }

    #[test]
    fn test_should_not_set_limits_when_receiver_is_not_exchange_and_sender_is_not_token_agent() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        mock_call(setup.mock_contract, selector!("is_agent"), false, 1);
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        start_cheat_caller_address(setup.module.contract_address, compliance);

        module_dispatcher.module_transfer_action(setup.mc_setup.alice, setup.mc_setup.bob, 10);
        stop_cheat_caller_address(setup.module.contract_address);

        let counter = setup
            .module
            .get_monthly_counter(compliance, setup.exchange_id, setup.investor_id);
        assert(counter.is_zero(), 'Monthly counter set');

        let timer = setup
            .module
            .get_monthly_timer(compliance, setup.exchange_id, setup.investor_id);
        assert(timer.is_zero(), 'Monthly timer set');
    }

    #[test]
    fn test_should_not_set_limits_when_receiver_is_not_exchange_and_sender_is_a_token_agent() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        mock_call(setup.mock_contract, selector!("is_agent"), true, 1);
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        start_cheat_caller_address(setup.module.contract_address, compliance);

        module_dispatcher.module_transfer_action(setup.mc_setup.alice, setup.mc_setup.bob, 10);
        stop_cheat_caller_address(setup.module.contract_address);

        let counter = setup
            .module
            .get_monthly_counter(compliance, setup.exchange_id, setup.investor_id);
        assert(counter.is_zero(), 'Monthly counter set');

        let timer = setup
            .module
            .get_monthly_timer(compliance, setup.exchange_id, setup.investor_id);
        assert(timer.is_zero(), 'Monthly timer set');
    }
}

pub mod module_check {
    use compliance::modules::{
        exchange_monthly_limits_module::IExchangeMonthlyLimitsModuleDispatcherTrait,
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
    };
    use core::num::traits::Zero;
    use snforge_std::{mock_call, start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    fn test_should_return_true_when_from_is_zero_address() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        mock_call(setup.mock_contract, selector!("is_agent"), false, 1);
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let check_result = module_dispatcher
            .module_check(Zero::zero(), setup.mc_setup.bob, 100, compliance);
        assert(check_result, 'Module check failed');
    }

    #[test]
    fn test_should_return_true_when_from_is_token_agent() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        mock_call(setup.mock_contract, selector!("is_agent"), true, 1);
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let check_result = module_dispatcher
            .module_check(setup.mc_setup.alice, setup.mc_setup.bob, 100, compliance);
        assert(check_result, 'Module check failed');
    }

    #[test]
    fn test_should_return_true_when_receiver_is_not_exchange() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        mock_call(setup.mock_contract, selector!("is_agent"), false, 1);
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let check_result = module_dispatcher
            .module_check(setup.mc_setup.alice, setup.mc_setup.bob, 100, compliance);
        assert(check_result, 'Module check failed');
    }

    #[test]
    fn test_should_return_true_when_receiver_is_exchange_and_sender_is_exchange() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;

        setup.module.add_exchange_id(setup.exchange_id);
        setup.module.add_exchange_id(setup.investor_id);

        mock_call(setup.mock_contract, selector!("is_agent"), false, 1);
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let check_result = module_dispatcher
            .module_check(setup.mc_setup.alice, setup.mc_setup.bob, 100, compliance);
        assert(check_result, 'Module check failed');
    }

    #[test]
    fn test_should_return_false_when_receiver_is_exchange_when_value_exceeds_the_monthly_limit() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;

        setup.module.add_exchange_id(setup.exchange_id);

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_exchange_monthly_limit(setup.exchange_id, 90);
        stop_cheat_caller_address(setup.module.contract_address);

        mock_call(setup.mock_contract, selector!("is_agent"), false, 1);
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let check_result = module_dispatcher
            .module_check(setup.mc_setup.alice, setup.mc_setup.bob, 100, compliance);
        assert(!check_result, 'Module check success');
    }

    #[test]
    fn test_should_return_true_when_receiver_is_exchange_when_exchange_month_is_finished() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;

        setup.module.add_exchange_id(setup.exchange_id);

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_exchange_monthly_limit(setup.exchange_id, 150);
        stop_cheat_caller_address(setup.module.contract_address);

        mock_call(setup.mock_contract, selector!("is_agent"), false, 1);
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let check_result = module_dispatcher
            .module_check(setup.mc_setup.alice, setup.mc_setup.bob, 100, compliance);
        assert(check_result, 'Module check failed');
    }

    #[test]
    fn test_should_return_false_when_receiver_is_exchange_when_monthly_counter_exceeds_the_monthly_limit() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        mock_call(setup.mock_contract, selector!("is_agent"), false, 2);
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        setup.module.add_exchange_id(setup.exchange_id);

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_exchange_monthly_limit(setup.exchange_id, 150);

        module_dispatcher.module_transfer_action(setup.mc_setup.alice, setup.mc_setup.bob, 100);
        stop_cheat_caller_address(setup.module.contract_address);

        let check_result = module_dispatcher
            .module_check(setup.mc_setup.alice, setup.mc_setup.bob, 100, compliance);
        assert(!check_result, 'Module check success');
    }

    #[test]
    fn test_should_return_true_when_receiver_is_exchange_when_monthly_counter_does_not_exceed_the_monthly_limit() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        mock_call(setup.mock_contract, selector!("is_agent"), false, 2);
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        setup.module.add_exchange_id(setup.exchange_id);

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_exchange_monthly_limit(setup.exchange_id, 150);

        module_dispatcher.module_transfer_action(setup.mc_setup.alice, setup.mc_setup.bob, 100);
        stop_cheat_caller_address(setup.module.contract_address);

        let check_result = module_dispatcher
            .module_check(setup.mc_setup.alice, setup.mc_setup.bob, 40, compliance);
        assert(check_result, 'Module check failed');
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

pub mod module_mint_action {
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
