use compliance::{
    imodular_compliance::IModularComplianceDispatcherTrait,
    modules::{
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
        time_exchange_limits_module::ITimeExchangeLimitsModuleDispatcher,
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
    module: ITimeExchangeLimitsModuleDispatcher,
    mock_contract: ContractAddress,
    exchange_id: ContractAddress,
    investor_id: ContractAddress,
}

pub fn setup() -> Setup {
    let mc_setup = mc_setup();

    let compliance_module_contract = declare("TimeExchangeLimitsModule").unwrap().contract_class();
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
    let investor_id = starknet::contract_address_const::<'ALICE_IDENTITY'>();
    let exchange_id = starknet::contract_address_const::<'BOB_IDENTITY'>();

    let mock_dispatcher = IMockContractDispatcher { contract_address: mock_contract };
    mock_dispatcher.set_identity(mc_setup.alice, investor_id);
    mock_dispatcher.set_identity(mc_setup.bob, exchange_id);

    Setup {
        mc_setup,
        module: ITimeExchangeLimitsModuleDispatcher { contract_address: deployed_address },
        mock_contract,
        exchange_id,
        investor_id,
    }
}

#[test]
fn test_should_deploy_the_time_exchange_limits_contract_and_bind_it_to_the_compliance() {
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
    assert(module_dispatcher.name() == "TimeExchangeLimitsModule", 'Names does not match!');
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

pub mod set_exchange_limit {
    use compliance::modules::time_exchange_limits_module::{
        ITimeExchangeLimitsModuleDispatcherTrait, Limit, TimeExchangeLimitsModule,
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

        setup.module.set_exchange_limit(exchange_id, Limit { limit_time: 1, limit_value: 100 });
    }

    #[test]
    fn test_should_add_new_limit_when_limit_time_does_not_exist_and_limit_array_size_not_exceeded() {
        let setup = setup();
        let exchange_id = setup.mc_setup.another_wallet;
        let compliance = setup.mc_setup.compliance.contract_address;
        let limit_time = 1;
        let limit_value = 100;

        let mut spy = spy_events();

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_exchange_limit(exchange_id, Limit { limit_time, limit_value });
        stop_cheat_caller_address(setup.module.contract_address);
        let limits = setup.module.get_exchange_limits(compliance, exchange_id);
        assert(limits.len() == 1, 'Limits len mismatch');
        let limit = *limits.at(0);
        assert(limit.limit_time == limit_time, 'Limit time mismatch');
        assert(limit.limit_value == limit_value, 'Limit value mismatch');

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TimeExchangeLimitsModule::Event::ExchangeLimitUpdated(
                            TimeExchangeLimitsModule::ExchangeLimitUpdated {
                                compliance, exchange_id, limit_value, limit_time,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic]
    fn test_should_panic_when_limit_time_does_not_exist_and_limit_array_size_exceeded() {
        let setup = setup();
        let exchange_id = setup.mc_setup.another_wallet;
        let compliance = setup.mc_setup.compliance.contract_address;
        let limit_value = 100;

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_exchange_limit(exchange_id, Limit { limit_time: 1, limit_value });
        setup.module.set_exchange_limit(exchange_id, Limit { limit_time: 2, limit_value });
        setup.module.set_exchange_limit(exchange_id, Limit { limit_time: 3, limit_value });
        setup.module.set_exchange_limit(exchange_id, Limit { limit_time: 4, limit_value });
        /// Adding fifth should exceed array limit
        setup.module.set_exchange_limit(exchange_id, Limit { limit_time: 5, limit_value });
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    fn test_should_update_the_limit_when_limit_time_already_exists() {
        let setup = setup();
        let exchange_id = setup.mc_setup.another_wallet;
        let compliance = setup.mc_setup.compliance.contract_address;
        let limit_time = 1;

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_exchange_limit(exchange_id, Limit { limit_time, limit_value: 100 });

        let mut spy = spy_events();
        setup.module.set_exchange_limit(exchange_id, Limit { limit_time, limit_value: 200 });
        stop_cheat_caller_address(setup.module.contract_address);
        let limits = setup.module.get_exchange_limits(compliance, exchange_id);
        assert(limits.len() == 1, 'Limits len mismatch');
        let limit = *limits.at(0);
        assert(limit.limit_time == limit_time, 'Limit time mismatch');
        assert(limit.limit_value == 200, 'Limit value mismatch');

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TimeExchangeLimitsModule::Event::ExchangeLimitUpdated(
                            TimeExchangeLimitsModule::ExchangeLimitUpdated {
                                compliance, exchange_id, limit_value: 200, limit_time,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod get_exchange_limits {
    use compliance::modules::time_exchange_limits_module::{
        ITimeExchangeLimitsModuleDispatcherTrait, Limit,
    };
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    fn test_should_return_limits() {
        let setup = setup();
        let exchange_id = setup.mc_setup.another_wallet;
        let compliance = setup.mc_setup.compliance.contract_address;
        let limit_time = 1;
        let limit_value = 100;

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_exchange_limit(exchange_id, Limit { limit_time, limit_value });
        stop_cheat_caller_address(setup.module.contract_address);
        let limits = setup.module.get_exchange_limits(compliance, exchange_id);
        assert(limits.len() == 1, 'Limits len mismatch');
        let limit = *limits.at(0);
        assert(limit.limit_time == limit_time, 'Limit time mismatch');
        assert(limit.limit_value == limit_value, 'Limit value mismatch');
    }
}

pub mod get_exchange_counter {
    use compliance::{
        modules::{
            imodule::{IModuleDispatcher, IModuleDispatcherTrait},
            time_exchange_limits_module::{ITimeExchangeLimitsModuleDispatcherTrait, Limit},
        },
    };
    use snforge_std::{mock_call, start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    fn test_should_return_counter() {
        let setup = setup();

        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;
        let compliance = setup.mc_setup.compliance.contract_address;

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        setup.module.add_exchange_id(setup.exchange_id);
        mock_call(setup.mock_contract, selector!("is_agent"), false, 1);
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup
            .module
            .set_exchange_limit(setup.exchange_id, Limit { limit_time: 10_000, limit_value: 100 });

        module_dispatcher.module_transfer_action(from, to, 10);
        stop_cheat_caller_address(setup.module.contract_address);

        let counter = setup
            .module
            .get_exchange_counter(compliance, setup.exchange_id, setup.investor_id, 10_000);
        assert(counter.value == 10, 'Counter value does not match');
    }
}

pub mod add_exchange_id {
    use compliance::modules::time_exchange_limits_module::{
        ITimeExchangeLimitsModuleDispatcherTrait, TimeExchangeLimitsModule,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_the_owner() {
        let setup = setup();

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.another_wallet);
        setup.module.add_exchange_id(setup.exchange_id);
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    fn test_should_tag_onchainid_as_exchange_when_exchange_id_not_tagged() {
        let setup = setup();
        let mut spy = spy_events();

        setup.module.add_exchange_id(setup.exchange_id);

        assert(setup.module.is_exchange_id(setup.exchange_id), 'Exchange id not registered');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TimeExchangeLimitsModule::Event::ExchangeIDAdded(
                            TimeExchangeLimitsModule::ExchangeIDAdded {
                                new_exchange_id: setup.exchange_id,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic]
    fn test_should_panic_when_exchange_id_already_tagged() {
        let setup = setup();

        setup.module.add_exchange_id(setup.exchange_id);
        /// Registering same exchange twice should panic
        setup.module.add_exchange_id(setup.exchange_id);
    }
}

pub mod remove_exchange_id {
    use compliance::modules::time_exchange_limits_module::{
        ITimeExchangeLimitsModuleDispatcherTrait, TimeExchangeLimitsModule,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_the_owner() {
        let setup = setup();

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.another_wallet);
        setup.module.remove_exchange_id(setup.exchange_id);
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    fn test_should_untag_the_exchangeid_when_exchange_id_tagged_and_caller_is_compliance() {
        let setup = setup();

        setup.module.add_exchange_id(setup.exchange_id);

        let mut spy = spy_events();
        setup.module.remove_exchange_id(setup.exchange_id);

        assert(!setup.module.is_exchange_id(setup.exchange_id), 'Exchange id not removed');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TimeExchangeLimitsModule::Event::ExchangeIDRemoved(
                            TimeExchangeLimitsModule::ExchangeIDRemoved {
                                exchange_id: setup.exchange_id,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic]
    fn test_should_panic_when_exchange_id_not_tagged_and_caller_is_compliance() {
        let setup = setup();

        setup.module.remove_exchange_id(setup.exchange_id);
    }
}

pub mod is_exchange_id {
    use compliance::modules::time_exchange_limits_module::ITimeExchangeLimitsModuleDispatcherTrait;
    use super::setup;

    #[test]
    fn test_should_return_false_when_exchange_id_not_tagged() {
        let setup = setup();

        let is_exchange_id = setup.module.is_exchange_id(setup.exchange_id);
        assert(!is_exchange_id, 'Should return false');
    }

    #[test]
    fn test_should_return_true_when_exchange_id_tagged() {
        let setup = setup();

        setup.module.add_exchange_id(setup.exchange_id);

        let is_exchange_id = setup.module.is_exchange_id(setup.exchange_id);
        assert(is_exchange_id, 'Should return true');
    }
}

pub mod module_transfer_action {
    use compliance::modules::{
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
        time_exchange_limits_module::{ITimeExchangeLimitsModuleDispatcherTrait, Limit},
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
    fn test_should_increase_exchange_counter_when_receiver_is_exchange_and_sender_not_token_agent_and_exchange_limit_not_exceeded() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        setup.module.add_exchange_id(setup.exchange_id);
        mock_call(setup.mock_contract, selector!("is_agent"), false, 1);

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup
            .module
            .set_exchange_limit(setup.exchange_id, Limit { limit_time: 10_000, limit_value: 100 });

        module_dispatcher.module_transfer_action(from, to, 10);
        stop_cheat_caller_address(setup.module.contract_address);

        let counter = setup
            .module
            .get_exchange_counter(compliance, setup.exchange_id, setup.investor_id, 10_000);
        assert(counter.value == 10, 'Counter value does not match');
    }

    #[test]
    fn test_should_set_timer_when_receiver_is_exchange_and_sender_not_token_agent_and_exchange_timer_finished() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        setup.module.add_exchange_id(setup.exchange_id);
        mock_call(setup.mock_contract, selector!("is_agent"), false, 1);

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup
            .module
            .set_exchange_limit(setup.exchange_id, Limit { limit_time: 10_000, limit_value: 100 });

        module_dispatcher.module_transfer_action(from, to, 10);
        stop_cheat_caller_address(setup.module.contract_address);

        let counter = setup
            .module
            .get_exchange_counter(compliance, setup.exchange_id, setup.investor_id, 10_000);
        assert(counter.timer > 0, 'Exchange timer not set');
    }

    #[test]
    fn test_should_not_update_timer_when_receiver_is_exchange_and_sender_not_token_agent_and_exchange_month_not_finished() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        setup.module.add_exchange_id(setup.exchange_id);
        mock_call(setup.mock_contract, selector!("is_agent"), false, 2);

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup
            .module
            .set_exchange_limit(setup.exchange_id, Limit { limit_time: 10_000, limit_value: 100 });

        module_dispatcher.module_transfer_action(from, to, 10);
        let previous_counter = setup
            .module
            .get_exchange_counter(compliance, setup.exchange_id, setup.investor_id, 10_000);

        module_dispatcher.module_transfer_action(from, to, 11);
        stop_cheat_caller_address(setup.module.contract_address);

        let current_counter = setup
            .module
            .get_exchange_counter(compliance, setup.exchange_id, setup.investor_id, 10_000);
        assert(current_counter.timer == previous_counter.timer, 'Exhange timers does not match');
    }

    #[test]
    fn test_should_not_set_limits_when_receiver_is_exchange_and_sender_is_token_agent() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        setup.module.add_exchange_id(setup.exchange_id);
        mock_call(setup.mock_contract, selector!("is_agent"), true, 1);

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup
            .module
            .set_exchange_limit(setup.exchange_id, Limit { limit_time: 10_000, limit_value: 100 });

        module_dispatcher.module_transfer_action(from, to, 10);
        stop_cheat_caller_address(setup.module.contract_address);

        let counter = setup
            .module
            .get_exchange_counter(compliance, setup.exchange_id, setup.investor_id, 10_000);
        assert(counter.timer.is_zero(), 'Exhange timer set');
        assert(counter.value.is_zero(), 'Exhange counter value set');
    }

    #[test]
    fn test_should_not_set_limits_when_receiver_is_not_exchange_and_sender_not_token_agent() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        mock_call(setup.mock_contract, selector!("is_agent"), false, 1);

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup
            .module
            .set_exchange_limit(setup.exchange_id, Limit { limit_time: 10_000, limit_value: 100 });

        module_dispatcher.module_transfer_action(from, to, 10);
        stop_cheat_caller_address(setup.module.contract_address);

        let counter = setup
            .module
            .get_exchange_counter(compliance, setup.exchange_id, setup.investor_id, 10_000);
        assert(counter.timer.is_zero(), 'Exhange timer set');
        assert(counter.value.is_zero(), 'Exhange counter value set');
    }

    #[test]
    fn test_should_not_set_limits_when_receiver_is_not_exchange_and_sender_is_token_agent() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        mock_call(setup.mock_contract, selector!("is_agent"), true, 1);

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup
            .module
            .set_exchange_limit(setup.exchange_id, Limit { limit_time: 10_000, limit_value: 100 });

        module_dispatcher.module_transfer_action(from, to, 10);
        stop_cheat_caller_address(setup.module.contract_address);

        let counter = setup
            .module
            .get_exchange_counter(compliance, setup.exchange_id, setup.investor_id, 10_000);
        assert(counter.timer.is_zero(), 'Exhange timer set');
        assert(counter.value.is_zero(), 'Exhange counter value set');
    }
}

pub mod module_check {
    use compliance::modules::{
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
        time_exchange_limits_module::{ITimeExchangeLimitsModuleDispatcherTrait, Limit},
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
    fn test_should_return_true_when_receiver_is_not_exchange() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        mock_call(setup.mock_contract, selector!("is_agent"), false, 1);
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
    fn test_should_return_true_when_receiver_is_exchange_and_sender_is_exchange() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        setup.module.add_exchange_id(setup.investor_id);
        setup.module.add_exchange_id(setup.exchange_id);

        mock_call(setup.mock_contract, selector!("is_agent"), false, 1);
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup
            .module
            .set_exchange_limit(setup.exchange_id, Limit { limit_time: 10_000, limit_value: 90 });
        stop_cheat_caller_address(setup.module.contract_address);

        let check_result = module_dispatcher.module_check(from, to, 100, compliance);
        assert(check_result, 'Should return true');
    }

    #[test]
    fn test_should_return_false_when_receiver_is_exchange_and_value_exceeds_limit() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        setup.module.add_exchange_id(setup.exchange_id);

        mock_call(setup.mock_contract, selector!("is_agent"), false, 1);
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup
            .module
            .set_exchange_limit(setup.exchange_id, Limit { limit_time: 10_000, limit_value: 90 });
        stop_cheat_caller_address(setup.module.contract_address);

        let check_result = module_dispatcher.module_check(from, to, 100, compliance);
        assert(!check_result, 'Should return false');
    }

    #[test]
    fn test_should_return_true_when_receiver_is_exchange_and_exchange_month_finished() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        setup.module.add_exchange_id(setup.exchange_id);

        mock_call(setup.mock_contract, selector!("is_agent"), false, 1);
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup
            .module
            .set_exchange_limit(setup.exchange_id, Limit { limit_time: 10_000, limit_value: 150 });
        stop_cheat_caller_address(setup.module.contract_address);

        let check_result = module_dispatcher.module_check(from, to, 100, compliance);
        assert(check_result, 'Should return true');
    }

    #[test]
    fn test_should_return_false_when_receiver_is_exchange_and_counter_exceeds_limit() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        setup.module.add_exchange_id(setup.exchange_id);

        mock_call(setup.mock_contract, selector!("is_agent"), false, 2);
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup
            .module
            .set_exchange_limit(setup.exchange_id, Limit { limit_time: 10_000, limit_value: 150 });

        module_dispatcher.module_transfer_action(from, to, 100);
        stop_cheat_caller_address(setup.module.contract_address);

        let check_result = module_dispatcher.module_check(from, to, 100, compliance);
        assert(!check_result, 'Should return false');
    }

    #[test]
    fn test_should_return_true_when_receiver_is_exchange_and_counter_does_not_exceed_limit() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        setup.module.add_exchange_id(setup.exchange_id);

        mock_call(setup.mock_contract, selector!("is_agent"), false, 2);
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup
            .module
            .set_exchange_limit(setup.exchange_id, Limit { limit_time: 10_000, limit_value: 150 });

        module_dispatcher.module_transfer_action(from, to, 100);
        stop_cheat_caller_address(setup.module.contract_address);

        let check_result = module_dispatcher.module_check(from, to, 40, compliance);
        assert(check_result, 'Should return true');
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
