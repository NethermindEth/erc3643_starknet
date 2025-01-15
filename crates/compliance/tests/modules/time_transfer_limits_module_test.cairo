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

    // Describe: when calling directly

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_when_not_compliance_should_panic() {
        let setup = setup();
        // Context: when caller is not compliance
        // Action: update the limit
        setup.module.set_time_transfer_limit(Limit { limit_time: 1, limit_value: 100 });
        // Check: should panic
    }

    // Describe: when calling via compliance

    #[test]
    fn test_when_limit_exists_should_update_the_limit() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;

        // Context: when limit exists and caller is compliance
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_time_transfer_limit(Limit { limit_time: 1, limit_value: 100 });
        let mut spy = spy_events();

        // Action: update the limit
        setup.module.set_time_transfer_limit(Limit { limit_time: 1, limit_value: 50 });

        // Context end
        stop_cheat_caller_address(setup.module.contract_address);

        // Check: should update the limit
        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TimeTransferLimitsModule::Event::TimeTransferLimitUpdated(
                            TimeTransferLimitsModule::TimeTransferLimitUpdated {
                                compliance, limit_time: 1, limit_value: 50,
                            },
                        ),
                    ),
                ],
            );
        // TODO(+): also check directly limit?
    }

    #[test]
    #[should_panic(expected: 'LimitsArraySizeExceeded')]
    fn test_when_4_limits_then_update_limit_should_panic() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;

        // Context: when 4 limits and caller is compliance
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_time_transfer_limit(Limit { limit_time: 1, limit_value: 100 });
        setup.module.set_time_transfer_limit(Limit { limit_time: 7, limit_value: 1000 });
        setup.module.set_time_transfer_limit(Limit { limit_time: 30, limit_value: 10000 });
        setup.module.set_time_transfer_limit(Limit { limit_time: 365, limit_value: 100000 });

        // Action: update the limit
        setup.module.set_time_transfer_limit(Limit { limit_time: 3650, limit_value: 1000000 });

        // Context end
        stop_cheat_caller_address(setup.module.contract_address);
        // Check: should panic
    }

    #[test]
    fn test_when_no_limit_then_update_limit_should_create_a_new_limit() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;

        // Context: when no limit and caller is compliance
        start_cheat_caller_address(setup.module.contract_address, compliance);
        let mut spy = spy_events();

        // Action: update the limit
        setup.module.set_time_transfer_limit(Limit { limit_time: 1, limit_value: 100 });

        // Context end
        stop_cheat_caller_address(setup.module.contract_address);

        // Check: should create a new limit
        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TimeTransferLimitsModule::Event::TimeTransferLimitUpdated(
                            TimeTransferLimitsModule::TimeTransferLimitUpdated {
                                compliance, limit_time: 1, limit_value: 100,
                            },
                        ),
                    ),
                ],
            );
        // TODO(+): also check directly limit?
    }
}

pub mod batch_set_time_transfer_limit {
    use compliance::modules::time_transfer_limits_module::{
        ITimeTransferLimitsModuleDispatcherTrait, Limit, TimeTransferLimitsModule,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    // Describe: when calling directly

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_when_not_compliance_should_panic() {
        let setup = setup();
        // Context: when caller is not compliance
        // Action: batch update limits
        setup
            .module
            .batch_set_time_transfer_limit(
                array![
                    Limit { limit_time: 1, limit_value: 100 },
                    Limit { limit_time: 2, limit_value: 200 },
                ]
                    .span(),
            );
        // Check: should panic
    }

    // Describe: when calling via compliance

    #[test]
    fn test_when_compliance_should_update_limits() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;

        // Context: when caller is compliance
        start_cheat_caller_address(setup.module.contract_address, compliance);
        let mut spy = spy_events();

        // Action: batch update limits
        setup
            .module
            .batch_set_time_transfer_limit(
                array![
                    Limit { limit_time: 1, limit_value: 100 },
                    Limit { limit_time: 2, limit_value: 200 },
                ]
                    .span(),
            );

        // Context end
        stop_cheat_caller_address(setup.module.contract_address);

        // Check: should update the limits
        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TimeTransferLimitsModule::Event::TimeTransferLimitUpdated(
                            TimeTransferLimitsModule::TimeTransferLimitUpdated {
                                compliance, limit_time: 1, limit_value: 100,
                            },
                        ),
                    ),
                    (
                        setup.module.contract_address,
                        TimeTransferLimitsModule::Event::TimeTransferLimitUpdated(
                            TimeTransferLimitsModule::TimeTransferLimitUpdated {
                                compliance, limit_time: 2, limit_value: 200,
                            },
                        ),
                    ),
                ],
            );
        // TODO(+): also check directly limits?
    }
}

pub mod remove_time_transfer_limit {
    use compliance::modules::time_transfer_limits_module::{
        ITimeTransferLimitsModuleDispatcherTrait, Limit, TimeTransferLimitsModule,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    // Describe: when calling directly

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_when_not_compliance_should_panic() {
        let setup = setup();
        // Context: when caller is not compliance
        // Action: remove limits
        setup.module.remove_time_transfer_limit(10)
        // Check: should panic
    }

    // Describe: when calling via compliance

    #[test]
    #[should_panic(expected: 'LimitTimeNotFound')]
    fn test_when_limit_time_missing_should_panic() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;

        // Context: when time limit is missing and caller is compliance
        start_cheat_caller_address(setup.module.contract_address, compliance);

        // Action: remove the limit
        setup.module.remove_time_transfer_limit(10);

        // Context end
        stop_cheat_caller_address(setup.module.contract_address);
        // Check: should panic
    }

    #[test]
    fn test_when_limit_time_is_last_element_should_remove_limit() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;

        // Context: when time limit is last element and caller is compliance
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup
            .module
            .batch_set_time_transfer_limit(
                array![
                    Limit { limit_time: 1, limit_value: 100 },
                    Limit { limit_time: 2, limit_value: 200 },
                    Limit { limit_time: 3, limit_value: 300 },
                ]
                    .span(),
            );
        let limit_to_remove = 3;
        let mut spy = spy_events();

        // Action: remove the last limit
        setup.module.remove_time_transfer_limit(limit_to_remove);

        // Context end
        stop_cheat_caller_address(setup.module.contract_address);

        // Check: should remove the limit
        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TimeTransferLimitsModule::Event::TimeTransferLimitRemoved(
                            TimeTransferLimitsModule::TimeTransferLimitRemoved {
                                compliance, limit_time: limit_to_remove,
                            },
                        ),
                    ),
                ],
            );
        let limits = setup.module.get_time_transfer_limit(compliance);
        assert_eq!(limits.len(), 2);
        assert_eq!(*limits[0].limit_time, 1);
        assert_eq!(*limits[0].limit_value, 100);
        assert_eq!(*limits[1].limit_time, 2);
        assert_eq!(*limits[1].limit_value, 200);
    }

    #[test]
    fn test_when_limit_time_is_not_last_element_should_remove_limit() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;

        // Context: when time limit is not last element and caller is compliance
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup
            .module
            .batch_set_time_transfer_limit(
                array![
                    Limit { limit_time: 1, limit_value: 100 },
                    Limit { limit_time: 2, limit_value: 200 },
                    Limit { limit_time: 3, limit_value: 300 },
                ]
                    .span(),
            );
        let limit_to_remove = 2;
        let mut spy = spy_events();

        // Action: remove the last limit
        setup.module.remove_time_transfer_limit(limit_to_remove);

        // Context end
        stop_cheat_caller_address(setup.module.contract_address);

        // Check: should remove the limit
        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TimeTransferLimitsModule::Event::TimeTransferLimitRemoved(
                            TimeTransferLimitsModule::TimeTransferLimitRemoved {
                                compliance, limit_time: limit_to_remove,
                            },
                        ),
                    ),
                ],
            );
        let limits = setup.module.get_time_transfer_limit(compliance);
        assert_eq!(limits.len(), 2);
        assert_eq!(*limits[0].limit_time, 1);
        assert_eq!(*limits[0].limit_value, 100);
        assert_eq!(*limits[1].limit_time, 3);
        assert_eq!(*limits[1].limit_value, 300);
    }
}

pub mod batch_remove_time_transfer_limit {
    use compliance::modules::time_transfer_limits_module::{
        ITimeTransferLimitsModuleDispatcherTrait, Limit, TimeTransferLimitsModule,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    // Describe: when calling directly

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_when_not_compliance_should_panic() {
        let setup = setup();
        // Context: when caller is not compliance
        // Action: batch remove limits
        setup.module.batch_remove_time_transfer_limit(array![10, 20].span());
        // Check: should panic
    }

    // Describe: when calling via compliance

    #[test]
    fn test_when_compliance_should_remove_limits() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;

        // Context: when caller is compliance
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup
            .module
            .batch_set_time_transfer_limit(
                array![
                    Limit { limit_time: 1, limit_value: 100 },
                    Limit { limit_time: 2, limit_value: 200 },
                    Limit { limit_time: 3, limit_value: 300 },
                ]
                    .span(),
            );
        let mut spy = spy_events();

        // Action: remove given limits
        let limits_to_remove = array![1, 3].span();
        setup.module.batch_remove_time_transfer_limit(limits_to_remove);

        // Context end
        stop_cheat_caller_address(setup.module.contract_address);

        // Check: should remove the limits
        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TimeTransferLimitsModule::Event::TimeTransferLimitRemoved(
                            TimeTransferLimitsModule::TimeTransferLimitRemoved {
                                compliance, limit_time: *limits_to_remove[0],
                            },
                        ),
                    ),
                    (
                        setup.module.contract_address,
                        TimeTransferLimitsModule::Event::TimeTransferLimitRemoved(
                            TimeTransferLimitsModule::TimeTransferLimitRemoved {
                                compliance, limit_time: *limits_to_remove[1],
                            },
                        ),
                    ),
                ],
            );
        let limits = setup.module.get_time_transfer_limit(compliance);
        assert_eq!(limits.len(), 1);
        assert_eq!(*limits[0].limit_time, 2);
        assert_eq!(*limits[0].limit_value, 200);
    }
}

pub mod get_time_transfer_limits {
    use compliance::modules::time_transfer_limits_module::{
        ITimeTransferLimitsModuleDispatcherTrait, Limit,
    };
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    fn test_when_no_limit_should_return_empty_array() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;
        // Context: when there is no time transfer limit
        // Action: get limits
        let limits = setup.module.get_time_transfer_limit(compliance);
        // Check: should return empty array
        assert_eq!(limits.len(), 0);
    }

    #[test]
    fn test_when_limits_set_should_return_limits() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;

        // Context: when there are time transfer limits
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup
            .module
            .batch_set_time_transfer_limit(
                array![
                    Limit { limit_time: 10, limit_value: 120 },
                    Limit { limit_time: 15, limit_value: 100 },
                ]
                    .span(),
            );
        stop_cheat_caller_address(setup.module.contract_address);

        // Action: get limits
        let limits = setup.module.get_time_transfer_limit(compliance);

        // Check: should return limits
        assert_eq!(limits.len(), 2);
        assert_eq!(*limits[0].limit_time, 10);
        assert_eq!(*limits[0].limit_value, 120);
        assert_eq!(*limits[1].limit_time, 15);
        assert_eq!(*limits[1].limit_value, 100);
    }
}

pub mod module_transfer_action {
    use compliance::modules::{
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
        time_transfer_limits_module::{
            TimeTransferLimitsModule, ITimeTransferLimitsModuleDispatcherTrait, Limit,
        },
    };
    use core::num::traits::Zero;
    use snforge_std::{
        start_cheat_caller_address, stop_cheat_caller_address, start_cheat_block_timestamp_global,
        stop_cheat_block_timestamp_global,
    };
    use starknet::{storage::{StoragePathEntry, StoragePointerReadAccess}};
    use super::setup;

    // Describe: when calling directly

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_when_not_compliance_should_panic() {
        let setup = setup();
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        // Context: when caller is not compliance
        // Action: transfer action
        module_dispatcher.module_transfer_action(from, to, 10);
        // Check: should panic
    }

    // Describe: when calling via compliance

    #[test]
    fn test_when_counters_not_initialized_should_set_counters() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;
        let sender_identity = setup
            .investor_id; // TODO: should we use identityRegistry.identity(from)?
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        // Context: when counters not initialized and caller is compliance
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup
            .module
            .batch_set_time_transfer_limit(
                array![
                    Limit { limit_time: 10, limit_value: 120 },
                    Limit { limit_time: 15, limit_value: 100 },
                ]
                    .span(),
            );

        // Action: transfer action
        module_dispatcher.module_transfer_action(from, to, 80);

        // Context end
        stop_cheat_caller_address(setup.module.contract_address);

        // Check: should set counters
        let block_timestamp = starknet::get_block_info().unbox().block_timestamp;
        let mut state =
            TimeTransferLimitsModule::contract_state_for_testing(); // TODO: check if correct with snforge?
        starknet::testing::set_contract_address( // https://foundry-rs.github.io/starknet-foundry/snforge-advanced-features/storage-cheatcodes.html
            setup.module.contract_address,
        );
        let counter1 = state.users_counter.entry((compliance, sender_identity, 10)).read();
        assert_eq!(counter1.value, 80);
        assert_eq!(counter1.timer, block_timestamp + 10);
        let counter2 = state.users_counter.entry((compliance, sender_identity, 15)).read();
        assert_eq!(counter2.value, 80);
        assert_eq!(counter2.timer, block_timestamp + 15);
    }

    #[test]
    fn test_when_counters_already_initialized_should_increase_counters() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;
        let sender_identity = setup
            .investor_id; // TODO: should we use identityRegistry.identity(from)?
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        // Context: when counters already initialized and caller is compliance
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup
            .module
            .batch_set_time_transfer_limit(
                array![
                    Limit { limit_time: 100, limit_value: 120 },
                    Limit { limit_time: 150, limit_value: 100 },
                ]
                    .span(),
            );
        module_dispatcher.module_transfer_action(from, to, 20);
        let block_timestamp = starknet::get_block_info().unbox().block_timestamp;
        start_cheat_block_timestamp_global(block_timestamp + 10);

        // Action: transfer action
        module_dispatcher.module_transfer_action(from, to, 30);

        // Check: should increase counters
        let mut state =
            TimeTransferLimitsModule::contract_state_for_testing(); // TODO: check if correct with snforge?
        starknet::testing::set_contract_address( // https://foundry-rs.github.io/starknet-foundry/snforge-advanced-features/storage-cheatcodes.html
            setup.module.contract_address,
        );
        let counter1 = state.users_counter.entry((compliance, sender_identity, 100)).read();
        assert_eq!(counter1.value, 50);
        assert_eq!(counter1.timer, block_timestamp + 100);
        let counter2 = state.users_counter.entry((compliance, sender_identity, 150)).read();
        assert_eq!(counter2.value, 50);
        assert_eq!(counter2.timer, block_timestamp + 150);

        // Context end
        stop_cheat_caller_address(setup.module.contract_address);
        stop_cheat_block_timestamp_global();
    }

    #[test]
    fn test_when_counter_is_finished_should_reset_and_increase_counters() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;
        let sender_identity = setup
            .investor_id; // TODO: should we use identityRegistry.identity(from)?
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        // Context: when counter is finished and caller is compliance
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup
            .module
            .batch_set_time_transfer_limit(
                array![
                    Limit { limit_time: 10, limit_value: 120 },
                    Limit { limit_time: 150, limit_value: 100 },
                ]
                    .span(),
            );
        module_dispatcher.module_transfer_action(from, to, 20);
        let block_timestamp = starknet::get_block_info().unbox().block_timestamp;
        start_cheat_block_timestamp_global(block_timestamp + 30);

        // Action: transfer action on finished counter
        module_dispatcher.module_transfer_action(from, to, 30);

        // Check: should reset and increase counters
        let reset_timestamp = starknet::get_block_info().unbox().block_timestamp;
        let mut state =
            TimeTransferLimitsModule::contract_state_for_testing(); // TODO: check if correct with snforge?
        starknet::testing::set_contract_address( // https://foundry-rs.github.io/starknet-foundry/snforge-advanced-features/storage-cheatcodes.html
            setup.module.contract_address,
        );
        let counter1 = state.users_counter.entry((compliance, sender_identity, 10)).read();
        assert_eq!(counter1.value, 30);
        assert_eq!(counter1.timer, reset_timestamp + 10);
        let counter2 = state.users_counter.entry((compliance, sender_identity, 150)).read();
        assert_eq!(counter2.value, 50);
        assert_eq!(counter2.timer, reset_timestamp + 150);

        // Context end
        stop_cheat_caller_address(setup.module.contract_address);
        stop_cheat_block_timestamp_global();
    }
}

pub mod module_check {
    use compliance::modules::{
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
        time_transfer_limits_module::{ITimeTransferLimitsModuleDispatcherTrait, Limit},
    };
    use core::num::traits::Zero;
    use snforge_std::{
        mock_call, start_cheat_caller_address, stop_cheat_caller_address,
        start_cheat_block_timestamp_global, stop_cheat_block_timestamp_global,
    };
    use super::setup;

    #[test]
    fn test_when_from_is_zero_address_should_return_true() {
        let setup = setup();
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        let compliance = setup.mc_setup.compliance.contract_address;
        let to = setup.mc_setup.bob;

        // Context: when from is zero address
        let from = Zero::zero();
        mock_call(setup.mock_contract, selector!("is_agent"), false, 1);

        // Action: module check
        let check_result = module_dispatcher.module_check(from, to, 100, compliance);

        // Check: should return true
        assert_eq!(check_result, true);
    }

    #[test]
    fn test_when_from_is_token_agent_should_return_true() {
        let setup = setup();
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        let compliance = setup.mc_setup.compliance.contract_address;
        let to = setup.mc_setup.bob;

        // Context: when from is token agent
        let from = setup.mc_setup.alice;
        mock_call(setup.mock_contract, selector!("is_agent"), true, 1);

        // Action: module check
        let check_result = module_dispatcher.module_check(from, to, 100, compliance);

        // Check: should return true
        assert_eq!(check_result, true);
    }

    #[test]
    fn test_when_value_exceeds_time_limit_should_return_false() {
        let setup = setup();
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        // Context: when value exceeds time limit
        mock_call(setup.mock_contract, selector!("is_agent"), false, 1);
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_time_transfer_limit(Limit { limit_time: 10, limit_value: 50 });
        stop_cheat_caller_address(setup.module.contract_address);
        let value = 100;

        // Action: module check
        let check_result = module_dispatcher.module_check(from, to, value, compliance);

        // Check: should return false
        assert_eq!(check_result, false);
    }

    // Describe: when value does not exceed time limit

    #[test]
    fn test_when_value_exceeds_counter_limit_should_return_false() {
        let setup = setup();
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        // Context: when value does not exceeds time limit and exceeds counter limit
        mock_call(setup.mock_contract, selector!("is_agent"), false, 1);
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_time_transfer_limit(Limit { limit_time: 10, limit_value: 120 });
        module_dispatcher.module_transfer_action(from, to, 100);
        stop_cheat_caller_address(setup.module.contract_address);
        let value = 100;

        // Action: module check
        let check_result = module_dispatcher.module_check(from, to, value, compliance);

        // Check: should return false
        assert_eq!(check_result, false);
    }

    #[test]
    fn test_when_value_does_not_exceed_counter_limit_should_return_true() {
        let setup = setup();
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        // Context: when value does not exceeds time limit and counter limit
        mock_call(setup.mock_contract, selector!("is_agent"), false, 1);
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_time_transfer_limit(Limit { limit_time: 10, limit_value: 120 });
        stop_cheat_caller_address(setup.module.contract_address);
        let value = 100;

        // Action: module check
        let check_result = module_dispatcher.module_check(from, to, value, compliance);

        // Check: should return true
        assert_eq!(check_result, true);
    }

    #[test]
    fn test_when_value_exceeds_counter_limit_but_limit_is_finished_should_return_true() {
        let setup = setup();
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        // Context: when value exceeds counter limit but the limit is finished
        mock_call(setup.mock_contract, selector!("is_agent"), false, 1);
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_time_transfer_limit(Limit { limit_time: 10, limit_value: 120 });
        stop_cheat_caller_address(setup.module.contract_address);
        let value = 100;
        let timestamp = starknet::get_block_info().unbox().block_timestamp;
        start_cheat_block_timestamp_global(timestamp + 30);

        // Action: module check
        let check_result = module_dispatcher.module_check(from, to, value, compliance);

        // Context end
        stop_cheat_block_timestamp_global();

        // Check: should return true
        assert_eq!(check_result, true);
    }
}

pub mod module_mint_action {
    use compliance::modules::imodule::{IModuleDispatcher, IModuleDispatcherTrait};
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_when_caller_is_not_compliance_contract_should_panic() {
        let setup = setup();
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        // Context: when caller is not compliance
        // Action: mint action
        module_dispatcher.module_mint_action(setup.mc_setup.another_wallet, 10);
        // Check: should panic
    }

    #[test]
    fn test_when_caller_is_compliance_should_do_nothing() {
        let setup = setup();
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        // Context: when caller is compliance
        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        // Action: mint action
        module_dispatcher.module_mint_action(setup.mc_setup.another_wallet, 10);
        // Context end
        stop_cheat_caller_address(setup.module.contract_address);
        // Check: should do nothing
    }
}

pub mod module_burn_action {
    use compliance::modules::imodule::{IModuleDispatcher, IModuleDispatcherTrait};
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_when_caller_is_not_compliance_should_panic() {
        let setup = setup();
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        // Context: when caller is not compliance
        // Action: burn action
        module_dispatcher.module_burn_action(setup.mc_setup.another_wallet, 10);
        // Check: should panic
    }

    #[test]
    fn test_when_caller_is_compliance_should_do_nothing() {
        let setup = setup();
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        // Context: when caller is compliance
        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        module_dispatcher.module_burn_action(setup.mc_setup.another_wallet, 10);
        // Context end
        stop_cheat_caller_address(setup.module.contract_address);
        // Check: should do nothing
    }
}
