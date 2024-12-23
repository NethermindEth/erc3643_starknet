//! TODO: Assert for exact panic messages for strings
use compliance::{
    imodular_compliance::IModularComplianceDispatcherTrait,
    modules::{
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
        max_balance_module::IMaxBalanceModuleDispatcher,
    },
};
use crate::modular_compliance_test::{Setup as MCSetup, setup as mc_setup};
use mocks::mock_contract::{IMockContractDispatcher, IMockContractDispatcherTrait};
use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, mock_call};
use starknet::ContractAddress;

#[derive(Drop, Copy)]
struct Setup {
    mc_setup: MCSetup,
    module: IMaxBalanceModuleDispatcher,
    mock_contract: ContractAddress,
    sender_id: ContractAddress,
    receiver_id: ContractAddress,
}

pub fn setup() -> Setup {
    let mc_setup = mc_setup();

    let compliance_module_contract = declare("MaxBalanceModule").unwrap().contract_class();
    let (deployed_address, _) = compliance_module_contract
        .deploy(@array![starknet::get_contract_address().into()])
        .unwrap();

    let (mock_contract, _) = declare("MockContract")
        .unwrap()
        .contract_class()
        .deploy(@array![])
        .unwrap();
    mc_setup.compliance.bind_token(mock_contract);

    mock_call(mock_contract, selector!("total_supply"), 0_u256, 1);
    mc_setup.compliance.add_module(deployed_address);

    let sender_id = starknet::contract_address_const::<'ALICE_IDENTITY'>();
    let receiver_id = starknet::contract_address_const::<'BOB_IDENTITY'>();

    let mock_dispatcher = IMockContractDispatcher { contract_address: mock_contract };
    mock_dispatcher.set_identity(mc_setup.alice, sender_id);
    mock_dispatcher.set_identity(mc_setup.bob, receiver_id);

    Setup {
        mc_setup,
        module: IMaxBalanceModuleDispatcher { contract_address: deployed_address },
        mock_contract,
        sender_id,
        receiver_id,
    }
}

#[test]
fn test_should_deploy_the_max_balance_contract_and_bind_it_to_the_compliance() {
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
    assert(module_dispatcher.name() == "MaxBalanceModule", 'Names does not match!');
}


#[test]
fn test_is_plug_and_play_should_return_false() {
    let setup = setup();
    let module_dispatcher = IModuleDispatcher { contract_address: setup.module.contract_address };
    assert(!module_dispatcher.is_plug_and_play(), 'Is plug and play');
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

pub mod can_compliance_bind {
    use compliance::modules::{
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
        max_balance_module::IMaxBalanceModuleDispatcherTrait,
    };
    use snforge_std::mock_call;
    use super::setup;

    #[test]
    fn test_should_return_false_when_token_total_supply_is_greater_than_zero_and_compliance_preset_status_is_false() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;

        mock_call(setup.mock_contract, selector!("total_supply"), 100_u256, 1);

        let can_compliance_bind = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        }
            .can_compliance_bind(compliance);
        assert!(!can_compliance_bind, "Compliance shouldnt able to bind");
    }

    #[test]
    fn test_should_return_true_when_token_total_supply_is_greater_than_zero_and_compliance_preset_status_is_true() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;

        mock_call(setup.mock_contract, selector!("total_supply"), 100, 1);
        setup.module.preset_completed(compliance);

        let can_compliance_bind = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        }
            .can_compliance_bind(compliance);
        assert!(can_compliance_bind, "Compliance should able to bind");
    }

    #[test]
    fn test_should_return_true_when_token_total_supply_is_zero() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;

        mock_call(setup.mock_contract, selector!("total_supply"), 0, 1);
        setup.module.preset_completed(compliance);

        let can_compliance_bind = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        }
            .can_compliance_bind(compliance);
        assert!(can_compliance_bind, "Compliance should able to bind");
    }
}

pub mod set_max_balance {
    use compliance::modules::max_balance_module::{
        IMaxBalanceModuleDispatcherTrait, MaxBalanceModule,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, load, map_entry_address, spy_events, start_cheat_caller_address,
        stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        let setup = setup();
        setup.module.set_max_balance(100);
    }

    #[test]
    fn test_should_set_max_balance() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;
        let mut spy = spy_events();

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_max_balance(100);
        stop_cheat_caller_address(setup.module.contract_address);

        let mut loaded = load(
            setup.module.contract_address,
            map_entry_address(selector!("max_balance"), array![compliance.into()].span()),
            2,
        )
            .span();
        let loaded_max_balance = Serde::<u256>::deserialize(ref loaded).unwrap();
        assert(loaded_max_balance == 100, 'Max Balances does not match');

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        MaxBalanceModule::Event::MaxBalanceSet(
                            MaxBalanceModule::MaxBalanceSet { compliance, max_balance: 100 },
                        ),
                    ),
                ],
            );
    }
}

pub mod pre_set_module_state {
    use compliance::modules::max_balance_module::{
        IMaxBalanceModuleDispatcher, IMaxBalanceModuleDispatcherTrait, MaxBalanceModule,
    };
    use snforge_std::{
        ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
        start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic]
    fn test_should_panic_when_caller_is_not_compliance_owner() {
        let setup = setup();

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.another_wallet);
        setup
            .module
            .preset_module_state(
                setup.mc_setup.compliance.contract_address, setup.mc_setup.alice, 100,
            );
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    #[should_panic]
    fn test_should_panic_when_compliance_already_bound() {
        let setup = setup();

        setup
            .module
            .preset_module_state(
                setup.mc_setup.compliance.contract_address, setup.mc_setup.alice, 100,
            );
    }

    #[test]
    fn test_should_preset_when_compliance_is_not_yet_bound() {
        let setup = setup();

        let compliance_module_contract = declare("MaxBalanceModule").unwrap().contract_class();
        let (deployed_address, _) = compliance_module_contract
            .deploy(@array![starknet::get_contract_address().into()])
            .unwrap();
        let max_balance_module = IMaxBalanceModuleDispatcher { contract_address: deployed_address };
        let compliance = setup.mc_setup.compliance.contract_address;
        let mut spy = spy_events();

        max_balance_module.preset_module_state(compliance, setup.mc_setup.alice, 100);

        assert!(
            max_balance_module.get_id_balance(compliance, setup.mc_setup.alice) == 100,
            "Balance not set",
        );
        spy
            .assert_emitted(
                @array![
                    (
                        max_balance_module.contract_address,
                        MaxBalanceModule::Event::IDBalancePreSet(
                            MaxBalanceModule::IDBalancePreSet {
                                compliance, id: setup.mc_setup.alice, balance: 100,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod preset_completed {
    use compliance::modules::max_balance_module::{
        IMaxBalanceModuleDispatcherTrait, MaxBalanceModule,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, load, map_entry_address, spy_events, start_cheat_caller_address,
        stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic]
    fn test_should_panic_when_caller_is_not_compliance_owner() {
        let setup = setup();

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.another_wallet);
        setup.module.preset_completed(setup.mc_setup.compliance.contract_address);
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    fn test_should_update_preset_status_as_true() {
        let setup = setup();

        let mut spy = spy_events();

        let compliance = setup.mc_setup.compliance.contract_address;
        setup.module.preset_completed(compliance);

        let mut loaded = load(
            setup.module.contract_address,
            map_entry_address(
                selector!("compliance_preset_status"), array![compliance.into()].span(),
            ),
            1,
        )
            .span();
        let loaded_preset_status = Serde::<bool>::deserialize(ref loaded).unwrap();
        assert(loaded_preset_status, 'Preset not set');

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        MaxBalanceModule::Event::PresetCompleted(
                            MaxBalanceModule::PresetCompleted { compliance },
                        ),
                    ),
                ],
            );
    }
}

pub mod batch_pre_set_module_state {
    use compliance::modules::max_balance_module::{
        IMaxBalanceModuleDispatcher, IMaxBalanceModuleDispatcherTrait, MaxBalanceModule,
    };
    use snforge_std::{
        ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
        start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic]
    fn test_should_panic_when_caller_is_not_compliance_owner() {
        let setup = setup();

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.another_wallet);
        setup
            .module
            .batch_preset_module_state(
                setup.mc_setup.compliance.contract_address,
                [setup.mc_setup.alice].span(),
                [100].span(),
            );
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    #[should_panic]
    fn test_should_panic_when_id_array_is_empty() {
        let setup = setup();

        setup
            .module
            .batch_preset_module_state(
                setup.mc_setup.compliance.contract_address, [].span(), [].span(),
            );
    }

    #[test]
    #[should_panic]
    fn test_should_panic_when_lengths_of_id_and_balance_arrays_not_equal() {
        let setup = setup();

        setup
            .module
            .batch_preset_module_state(
                setup.mc_setup.compliance.contract_address,
                [setup.mc_setup.alice].span(),
                [100, 200].span(),
            );
    }

    #[test]
    #[should_panic]
    fn test_should_panic_when_compliance_already_bound() {
        let setup = setup();

        setup
            .module
            .batch_preset_module_state(
                setup.mc_setup.compliance.contract_address,
                [setup.mc_setup.alice].span(),
                [100].span(),
            );
    }

    #[test]
    fn test_should_preset_when_compliance_is_not_yet_bound() {
        let setup = setup();

        let compliance_module_contract = declare("MaxBalanceModule").unwrap().contract_class();
        let (deployed_address, _) = compliance_module_contract
            .deploy(@array![starknet::get_contract_address().into()])
            .unwrap();
        let max_balance_module = IMaxBalanceModuleDispatcher { contract_address: deployed_address };
        let compliance = setup.mc_setup.compliance.contract_address;
        let mut spy = spy_events();

        max_balance_module
            .batch_preset_module_state(
                compliance, [setup.mc_setup.alice, setup.mc_setup.bob].span(), [100, 200].span(),
            );

        assert!(
            max_balance_module.get_id_balance(compliance, setup.mc_setup.alice) == 100,
            "Alice balance not set",
        );
        assert!(
            max_balance_module.get_id_balance(compliance, setup.mc_setup.alice) == 100,
            "Bob balance not set",
        );
        spy
            .assert_emitted(
                @array![
                    (
                        max_balance_module.contract_address,
                        MaxBalanceModule::Event::IDBalancePreSet(
                            MaxBalanceModule::IDBalancePreSet {
                                compliance, id: setup.mc_setup.alice, balance: 100,
                            },
                        ),
                    ),
                    (
                        max_balance_module.contract_address,
                        MaxBalanceModule::Event::IDBalancePreSet(
                            MaxBalanceModule::IDBalancePreSet {
                                compliance, id: setup.mc_setup.bob, balance: 200,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod module_transfer_action {
    use compliance::modules::{
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
        max_balance_module::IMaxBalanceModuleDispatcherTrait,
    };
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        module_dispatcher.module_transfer_action(from, to, 100);
    }

    #[test]
    #[should_panic]
    fn test_should_panic_when_value_exceeds_the_max_balance() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.set_max_balance(150);

        module_dispatcher.module_transfer_action(from, to, 151);
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    fn test_should_update_receiver_and_sender_balances_when_value_does_not_exceed_the_max_balance() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_max_balance(150);
        module_dispatcher.module_mint_action(from, 150);

        module_dispatcher.module_transfer_action(from, to, 120);
        stop_cheat_caller_address(setup.module.contract_address);

        assert(
            setup.module.get_id_balance(compliance, setup.sender_id) == 30,
            'From id balance does not match',
        );
        assert(
            setup.module.get_id_balance(compliance, setup.receiver_id) == 120,
            'To id balance does not match',
        );
    }
}

pub mod module_mint_action {
    use compliance::modules::{
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
        max_balance_module::IMaxBalanceModuleDispatcherTrait,
    };
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let to = setup.mc_setup.alice;

        module_dispatcher.module_mint_action(to, 10);
    }

    #[test]
    #[should_panic]
    fn test_should_panic_when_value_exceeds_the_max_balance() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let compliance = setup.mc_setup.compliance.contract_address;
        let to = setup.mc_setup.alice;

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_max_balance(150);

        module_dispatcher.module_mint_action(to, 160);
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    fn test_should_update_minter_balance_when_value_does_not_exceed_the_max_balance() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let compliance = setup.mc_setup.compliance.contract_address;
        let to = setup.mc_setup.bob;

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_max_balance(150);

        module_dispatcher.module_mint_action(to, 150);
        stop_cheat_caller_address(setup.module.contract_address);
        assert(
            setup.module.get_id_balance(compliance, setup.receiver_id) == 150,
            'ID balance does not match',
        );
    }
}

pub mod module_burn_action {
    use compliance::modules::{
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
        max_balance_module::IMaxBalanceModuleDispatcherTrait,
    };
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        let from = setup.mc_setup.alice;

        module_dispatcher.module_burn_action(from, 10);
    }

    #[test]
    fn test_should_update_sender_balance() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let alice_identity = setup.sender_id;

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_max_balance(150);
        module_dispatcher.module_mint_action(from, 100);

        module_dispatcher.module_burn_action(from, 90);
        stop_cheat_caller_address(setup.module.contract_address);
        assert(
            setup.module.get_id_balance(compliance, alice_identity) == 10,
            'ID balance does not match',
        );
    }
}

pub mod module_check {
    use compliance::modules::{
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
        max_balance_module::IMaxBalanceModuleDispatcherTrait,
    };
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Identity not found')]
    fn test_should_panic_when_identity_not_found() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.another_wallet;

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_max_balance(150);

        module_dispatcher.module_check(from, to, 10, compliance);
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    fn test_should_return_false_when_value_exceeds_compliance_max_balance() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_max_balance(150);

        let check_result = module_dispatcher.module_check(from, to, 170, compliance);
        stop_cheat_caller_address(setup.module.contract_address);
        assert(!check_result, 'Should have returned false');
    }

    #[test]
    fn test_should_return_false_when_user_balance_exceeds_compliance_max_balance() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_max_balance(150);
        module_dispatcher.module_mint_action(to, 100);

        let check_result = module_dispatcher.module_check(from, to, 170, compliance);
        stop_cheat_caller_address(setup.module.contract_address);
        assert(!check_result, 'Should have returned false');
    }

    #[test]
    fn test_should_return_true_when_user_balance_does_not_exceed_compliance_max_balance() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_max_balance(150);

        let check_result = module_dispatcher.module_check(from, to, 70, compliance);
        stop_cheat_caller_address(setup.module.contract_address);
        assert(check_result, 'Should have returned true');
    }
}
