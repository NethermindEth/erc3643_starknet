use crate::compliance::tests::modular_compliance_test::{Setup as MCSetup, setup as mc_setup};
use crate::compliance::{
    imodular_compliance::IModularComplianceDispatcherTrait,
    modules::{
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
        transfer_fees_module::ITransferFeesModuleDispatcher,
    },
};
use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, mock_call};
use starknet::ContractAddress;
use test_commons::mocks::mock_contract::{IMockContractDispatcher, IMockContractDispatcherTrait};

#[derive(Drop, Copy)]
struct Setup {
    mc_setup: MCSetup,
    module: ITransferFeesModuleDispatcher,
    mock_contract: ContractAddress,
    alice_id: ContractAddress,
    bob_id: ContractAddress,
    fee_collector: ContractAddress,
    fee_collector_id: ContractAddress,
}

pub fn setup() -> Setup {
    let mc_setup = mc_setup();

    let compliance_module_contract = declare("TransferFeesModule").unwrap().contract_class();
    let (deployed_address, _) = compliance_module_contract
        .deploy(@array![starknet::get_contract_address().into()])
        .unwrap();

    let (mock_contract, _) = declare("MockContract")
        .unwrap()
        .contract_class()
        .deploy(@array![])
        .unwrap();

    mock_call(mock_contract, selector!("is_agent"), true, 1);
    mc_setup.compliance.bind_token(mock_contract);
    mc_setup.compliance.add_module(deployed_address);

    let alice_id = starknet::contract_address_const::<'ALICE_IDENTITY'>();
    let bob_id = starknet::contract_address_const::<'BOB_IDENTITY'>();

    let fee_collector = starknet::contract_address_const::<'FEE_COLLECTOR'>();
    let fee_collector_id = starknet::contract_address_const::<'FEE_COLLECTOR_IDENTITY'>();
    let mock_dispatcher = IMockContractDispatcher { contract_address: mock_contract };
    mock_dispatcher.set_identity(fee_collector, fee_collector_id);
    mock_dispatcher.set_identity(mc_setup.bob, bob_id);
    /// Both share the same id
    mock_dispatcher.set_identity(mc_setup.alice, alice_id);
    mock_dispatcher.set_identity(mc_setup.another_wallet, alice_id);

    Setup {
        mc_setup,
        module: ITransferFeesModuleDispatcher { contract_address: deployed_address },
        mock_contract,
        alice_id,
        bob_id,
        fee_collector,
        fee_collector_id,
    }
}

#[test]
fn test_should_deploy_the_transfer_fees_contract_and_bind_it_to_the_compliance() {
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
    assert(module_dispatcher.name() == "TransferFeesModule", 'Names does not match!');
}

#[test]
fn test_is_plug_and_play_should_return_false() {
    let setup = setup();
    let module_dispatcher = IModuleDispatcher { contract_address: setup.module.contract_address };
    assert(!module_dispatcher.is_plug_and_play(), 'Is plug and play');
}

pub mod can_compliance_bind {
    use crate::compliance::modules::imodule::{IModuleDispatcher, IModuleDispatcherTrait};
    use snforge_std::mock_call;
    use super::setup;

    #[test]
    fn test_should_return_false_when_module_is_not_registered_as_token_agent() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        mock_call(setup.mock_contract, selector!("is_agent"), false, 1);
        let can_bind = module_dispatcher
            .can_compliance_bind(setup.mc_setup.compliance.contract_address);
        assert(!can_bind, 'Shouldnt be able to bind');
    }

    #[test]
    fn test_should_return_true_when_module_is_registered_as_token_agent() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        mock_call(setup.mock_contract, selector!("is_agent"), true, 1);
        let can_bind = module_dispatcher
            .can_compliance_bind(setup.mc_setup.compliance.contract_address);
        assert(can_bind, 'Should be able to bind');
    }
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

pub mod set_fee {
    use crate::compliance::modules::transfer_fees_module::{
        ITransferFeesModuleDispatcherTrait, TransferFeesModule,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, mock_call, spy_events, start_cheat_caller_address,
        stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        let setup = setup();

        setup.module.set_fee(1, setup.fee_collector);
    }

    #[test]
    #[should_panic]
    fn test_should_panic_when_rate_is_greater_than_the_max() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.set_fee(10_001, setup.fee_collector);
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    #[should_panic]
    fn test_should_panic_when_collector_address_is_not_verified() {
        let setup = setup();

        mock_call(setup.mock_contract, selector!("is_verified"), false, 1);
        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.set_fee(1, setup.fee_collector);
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    fn test_should_set_the_fee_when_collector_address_is_verified() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;

        mock_call(setup.mock_contract, selector!("is_verified"), true, 1);

        let mut spy = spy_events();

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_fee(1, setup.fee_collector);
        stop_cheat_caller_address(setup.module.contract_address);
        let fee = setup.module.get_fee(compliance);

        assert(fee.rate == 1, 'Fee rate mismatch');
        assert(fee.collector == setup.fee_collector, 'Fee collector mismatch');

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TransferFeesModule::Event::FeeUpdated(
                            TransferFeesModule::FeeUpdated {
                                compliance, rate: 1, collector: setup.fee_collector,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod get_fee {
    use crate::compliance::modules::transfer_fees_module::ITransferFeesModuleDispatcherTrait;
    use snforge_std::{mock_call, start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    fn test_should_return_the_fee() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;

        mock_call(setup.mock_contract, selector!("is_verified"), true, 1);
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_fee(1, setup.fee_collector);
        stop_cheat_caller_address(setup.module.contract_address);
        let fee = setup.module.get_fee(compliance);

        assert(fee.rate == 1, 'Fee rate mismatch');
        assert(fee.collector == setup.fee_collector, 'Fee collector mismatch');
    }
}

pub mod module_transfer_action {
    use core::num::traits::Zero;
    use crate::compliance::modules::{
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
        transfer_fees_module::ITransferFeesModuleDispatcherTrait,
    };
    use openzeppelin_token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
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
        module_dispatcher.module_transfer_action(from, to, 80);
    }

    #[test]
    fn test_should_do_nothing_when_from_and_to_belong_to_same_identity() {
        let setup = setup();
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.another_wallet;
        let compliance = setup.mc_setup.compliance.contract_address;
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        mock_call(setup.mock_contract, selector!("is_verified"), true, 1);

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_fee(1000, setup.fee_collector);
        module_dispatcher.module_transfer_action(from, to, 80);
        stop_cheat_caller_address(setup.module.contract_address);

        let erc20_dispatcher = ERC20ABIDispatcher { contract_address: setup.mock_contract };
        let collected_amount = erc20_dispatcher.balance_of(setup.fee_collector);
        assert(collected_amount.is_zero(), 'Fee transferred');
    }

    #[test]
    fn test_should_do_nothing_when_fee_is_zero() {
        let setup = setup();
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;
        let compliance = setup.mc_setup.compliance.contract_address;
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        mock_call(setup.mock_contract, selector!("is_verified"), true, 1);

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_fee(0, setup.fee_collector);

        module_dispatcher.module_transfer_action(from, to, 80);
        stop_cheat_caller_address(setup.module.contract_address);

        let erc20_dispatcher = ERC20ABIDispatcher { contract_address: setup.mock_contract };
        let collected_amount = erc20_dispatcher.balance_of(setup.fee_collector);
        assert(collected_amount.is_zero(), 'Fee transferred');
    }

    #[test]
    fn test_should_do_nothing_when_sender_is_the_collector() {
        let setup = setup();

        let from = setup.fee_collector;
        let to = setup.mc_setup.bob;
        let compliance = setup.mc_setup.compliance.contract_address;
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        mock_call(setup.mock_contract, selector!("is_verified"), true, 1);

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_fee(1000, setup.fee_collector);
        module_dispatcher.module_transfer_action(from, to, 80);
        stop_cheat_caller_address(setup.module.contract_address);

        let erc20_dispatcher = ERC20ABIDispatcher { contract_address: setup.mock_contract };
        let collected_amount = erc20_dispatcher.balance_of(setup.fee_collector);
        assert(collected_amount.is_zero(), 'Fee transferred');
    }

    #[test]
    fn test_should_do_nothing_when_receiver_is_the_collector() {
        let setup = setup();

        let from = setup.mc_setup.alice;
        let to = setup.fee_collector;
        let compliance = setup.mc_setup.compliance.contract_address;
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        mock_call(setup.mock_contract, selector!("is_verified"), true, 1);

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_fee(1000, setup.fee_collector);
        module_dispatcher.module_transfer_action(from, to, 80);
        stop_cheat_caller_address(setup.module.contract_address);

        let erc20_dispatcher = ERC20ABIDispatcher { contract_address: setup.mock_contract };
        let collected_amount = erc20_dispatcher.balance_of(setup.fee_collector);
        assert(collected_amount.is_zero(), 'Fee transferred');
    }

    #[test]
    fn test_should_do_nothing_when_calculated_fee_amount_is_zero() {
        let setup = setup();

        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;
        let compliance = setup.mc_setup.compliance.contract_address;
        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        mock_call(setup.mock_contract, selector!("is_verified"), true, 1);

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_fee(1, setup.fee_collector);
        module_dispatcher.module_transfer_action(from, to, 80);
        stop_cheat_caller_address(setup.module.contract_address);

        let erc20_dispatcher = ERC20ABIDispatcher { contract_address: setup.mock_contract };
        let collected_amount = erc20_dispatcher.balance_of(setup.fee_collector);
        assert(collected_amount.is_zero(), 'Fee transferred');
    }

    #[test]
    fn test_should_transfer_the_fee_amount_when_calculated_fee_amount_is_higher_than_zero() {
        let setup = setup();

        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;
        let compliance = setup.mc_setup.compliance.contract_address;

        let erc20_dispatcher = ERC20ABIDispatcher { contract_address: setup.mock_contract };
        /// fee is taken from receiver
        erc20_dispatcher.transfer(to, 100);

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        mock_call(setup.mock_contract, selector!("is_verified"), true, 1);

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.set_fee(1000, setup.fee_collector);
        module_dispatcher.module_transfer_action(from, to, 80);
        stop_cheat_caller_address(setup.module.contract_address);

        let collected_amount = erc20_dispatcher.balance_of(setup.fee_collector);
        assert(collected_amount == 8, 'Fee is not transferred');
        let to_balance = erc20_dispatcher.balance_of(to);
        assert(to_balance == 92, 'To balance mismatch');
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

pub mod module_check {
    use crate::compliance::modules::imodule::{IModuleDispatcher, IModuleDispatcherTrait};
    use super::setup;

    #[test]
    fn test_should_return_true() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let check_result = module_dispatcher
            .module_check(
                setup.mc_setup.alice,
                setup.mc_setup.bob,
                10,
                setup.mc_setup.compliance.contract_address,
            );

        assert(check_result, 'Should return true');
    }
}
