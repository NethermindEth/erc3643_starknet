use core::num::traits::Zero;
use dva::dva_transfer_manager::DVATransferManager;
use dva::idva_transfer_manager::{
    DelegatedApproval, DelegatedApprovalMessage, DelegatedApprovalMessageStructHash, Events::*,
    IDVATransferManagerDispatcher, IDVATransferManagerDispatcherTrait, TransferStatus,
};
use factory::tests_common::{FullSuiteSetup, setup_full_suite};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use registry::interface::iidentity_registry::IIdentityRegistryDispatcherTrait;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};

fn setup_full_suite_with_transfer_manager() -> (FullSuiteSetup, IDVATransferManagerDispatcher) {
    let setup = setup_full_suite();
    let transfer_manager_contract = declare("DVATransferManager").unwrap().contract_class();
    let (transfer_manager_address, _) = transfer_manager_contract.deploy(@array![]).unwrap();
    (setup, IDVATransferManagerDispatcher { contract_address: transfer_manager_address })
}

fn setup_full_suite_with_verified_transfer_manager() -> (
    FullSuiteSetup, IDVATransferManagerDispatcher,
) {
    let (setup, transfer_manager) = setup_full_suite_with_transfer_manager();
    let alice_identity = setup.onchain_id.alice_identity.contract_address;

    start_cheat_caller_address(
        setup.identity_registry.contract_address,
        setup.accounts.token_agent.account.contract_address,
    );
    setup.identity_registry.register_identity(transfer_manager.contract_address, alice_identity, 0);
    stop_cheat_caller_address(setup.identity_registry.contract_address);

    (setup, transfer_manager)
}

fn setup_full_suite_with_transfer(
    sequential_approval: bool,
) -> (FullSuiteSetup, IDVATransferManagerDispatcher, felt252) {
    let (setup, transfer_manager) = setup_full_suite_with_verified_transfer_manager();
    let token_address = setup.token.contract_address;
    let alice = setup.accounts.alice.account.contract_address;
    let bob = setup.accounts.bob.account.contract_address;
    let charlie = setup.accounts.charlie.account.contract_address;

    start_cheat_caller_address(
        transfer_manager.contract_address, setup.accounts.token_agent.account.contract_address,
    );
    transfer_manager
        .set_approval_criteria(
            token_address, true, true, sequential_approval, array![charlie].span(),
        );
    stop_cheat_caller_address(transfer_manager.contract_address);

    start_cheat_caller_address(token_address, alice);
    IERC20Dispatcher { contract_address: token_address }
        .approve(transfer_manager.contract_address, 100000);
    stop_cheat_caller_address(token_address);

    let transfer_id = transfer_manager.calculate_transfer_id(0, alice, bob, 100);

    start_cheat_caller_address(transfer_manager.contract_address, alice);
    transfer_manager.initiate_transfer(token_address, bob, 100);
    stop_cheat_caller_address(transfer_manager.contract_address);

    (setup, transfer_manager, transfer_id)
}

fn sign_transfer(transfer_id: felt252, signer: starknet::ContractAddress) -> DelegatedApproval {
    let signature = DelegatedApprovalMessageStructHash::hash_struct(
        @DelegatedApprovalMessage { transfer_id },
    );
    DelegatedApproval { signer, signature: array![signature] }
}

mod set_approval_criteria {
    use super::*;

    #[test]
    #[should_panic(expected: 'Only token agent can call')]
    fn test_when_sender_is_not_token_agent_should_panic() {
        let (setup, transfer_manager) = setup_full_suite_with_transfer_manager();

        start_cheat_caller_address(
            transfer_manager.contract_address,
            starknet::contract_address_const::<'NOT_TOKEN_AGENT'>(),
        );
        transfer_manager
            .set_approval_criteria(
                setup.token.contract_address, false, true, true, array![].span(),
            );
        stop_cheat_caller_address(transfer_manager.contract_address);
    }

    // Describe: When sender is token agent

    #[test]
    #[should_panic(expected: 'DVA Mngr not verified for token')]
    fn test_when_dva_manager_is_not_verified_for_the_token() {
        let (setup, transfer_manager) = setup_full_suite_with_transfer_manager();

        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        transfer_manager
            .set_approval_criteria(
                setup.token.contract_address, false, true, true, array![].span(),
            );
        stop_cheat_caller_address(transfer_manager.contract_address);
    }

    // Describe: When dva manager is verified for the token, and sender is token agent

    #[test]
    fn test_when_token_is_not_already_registered_should_modify_approval_criteria() {
        let (setup, transfer_manager) = setup_full_suite_with_transfer_manager();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;
        let token_address = setup.token.contract_address;

        start_cheat_caller_address(
            setup.identity_registry.contract_address,
            setup.accounts.token_agent.account.contract_address,
        );
        setup
            .identity_registry
            .register_identity(transfer_manager.contract_address, alice_identity, 0);
        stop_cheat_caller_address(setup.identity_registry.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        transfer_manager
            .set_approval_criteria(
                token_address,
                true,
                true,
                true,
                array![
                    starknet::contract_address_const::<'ANOTHER_WALLET'>(),
                    setup.accounts.bob.account.contract_address,
                ]
                    .span(),
            );
        stop_cheat_caller_address(transfer_manager.contract_address);

        let approval_criteria = transfer_manager.get_approval_criteria(token_address);
        assert_eq!(approval_criteria.include_recipient_approver, true);
        assert_eq!(approval_criteria.include_agent_approver, true);
        assert_eq!(approval_criteria.sequential_approval, true);
        assert_eq!(
            approval_criteria.additional_approvers,
            array![
                starknet::contract_address_const::<'ANOTHER_WALLET'>(),
                setup.accounts.bob.account.contract_address,
            ],
        );

        spy
            .assert_emitted(
                @array![
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::ApprovalCriteriaSet(
                            ApprovalCriteriaSet {
                                token_address,
                                include_recipient_approver: true,
                                include_agent_approver: true,
                                sequential_approval: true,
                                additional_approvers: array![
                                    starknet::contract_address_const::<'ANOTHER_WALLET'>(),
                                    setup.accounts.bob.account.contract_address,
                                ]
                                    .span(),
                                hash: approval_criteria.hash,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_when_token_is_already_registered_should_modify_approval_criteria() {
        let (setup, transfer_manager) = setup_full_suite_with_transfer_manager();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;
        let token_address = setup.token.contract_address;

        start_cheat_caller_address(
            setup.identity_registry.contract_address,
            setup.accounts.token_agent.account.contract_address,
        );
        setup
            .identity_registry
            .register_identity(transfer_manager.contract_address, alice_identity, 0);
        stop_cheat_caller_address(setup.identity_registry.contract_address);

        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        transfer_manager
            .set_approval_criteria(
                token_address,
                true,
                true,
                true,
                array![
                    starknet::contract_address_const::<'ANOTHER_WALLET'>(),
                    setup.accounts.bob.account.contract_address,
                ]
                    .span(),
            );
        stop_cheat_caller_address(transfer_manager.contract_address);
        let previous_approval_criteria = transfer_manager.get_approval_criteria(token_address);

        let mut spy = spy_events();
        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        transfer_manager
            .set_approval_criteria(
                token_address,
                false,
                false,
                false,
                array![setup.accounts.david.account.contract_address].span(),
            );
        stop_cheat_caller_address(transfer_manager.contract_address);
        let approval_criteria = transfer_manager.get_approval_criteria(token_address);

        assert_eq!(approval_criteria.include_recipient_approver, false);
        assert_eq!(approval_criteria.include_agent_approver, false);
        assert_eq!(approval_criteria.sequential_approval, false);
        assert_eq!(
            approval_criteria.additional_approvers,
            array![setup.accounts.david.account.contract_address],
        );
        assert_ne!(previous_approval_criteria.hash, approval_criteria.hash);

        spy
            .assert_emitted(
                @array![
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::ApprovalCriteriaSet(
                            ApprovalCriteriaSet {
                                token_address,
                                include_recipient_approver: false,
                                include_agent_approver: false,
                                sequential_approval: false,
                                additional_approvers: array![
                                    setup.accounts.david.account.contract_address,
                                ]
                                    .span(),
                                hash: approval_criteria.hash,
                            },
                        ),
                    ),
                ],
            );
    }
}

mod cancel_transfer {
    use super::*;

    #[test]
    #[should_panic(expected: 'Invalid transfer ID')]
    fn test_when_transfer_does_not_exist_should_panic() {
        let (setup, transfer_manager) = setup_full_suite_with_verified_transfer_manager();
        let transfer_id = transfer_manager
            .calculate_transfer_id(
                0,
                setup.accounts.alice.account.contract_address,
                setup.accounts.bob.account.contract_address,
                100,
            );
        transfer_manager.cancel_transfer(transfer_id);
    }

    #[test]
    #[should_panic(expected: 'Only transfer sender can call')]
    fn test_when_caller_is_not_sender_should_panic() {
        let (setup, transfer_manager, transfer_id) = setup_full_suite_with_transfer(false);
        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.bob.account.contract_address,
        );
        transfer_manager.cancel_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Transfer not in pending status')]
    fn test_when_transfer_status_is_not_pending_should_panic() {
        let (setup, transfer_manager, transfer_id) = setup_full_suite_with_transfer(false);
        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        transfer_manager.cancel_transfer(transfer_id);
        // Second time should panic
        transfer_manager.cancel_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);
    }

    #[test]
    fn test_when_transfer_status_is_pending_should_cancel() {
        let (setup, transfer_manager, transfer_id) = setup_full_suite_with_transfer(false);
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };

        let mut spy = spy_events();
        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        transfer_manager.cancel_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferCancelled(
                            TransferCancelled { transfer_id },
                        ),
                    ),
                ],
            );

        let transfer = transfer_manager.get_transfer(transfer_id);
        assert_eq!(transfer.status, TransferStatus::CANCELLED);

        assert_eq!(
            erc20_dispatcher.balance_of(setup.accounts.alice.account.contract_address), 1000,
        );
    }
}

mod get_transfer {
    use super::*;

    #[test]
    #[should_panic(expected: 'Invalid transfer ID')]
    fn test_when_transfer_does_not_exist_should_panic() {
        let (setup, transfer_manager) = setup_full_suite_with_verified_transfer_manager();
        let transfer_id = transfer_manager
            .calculate_transfer_id(
                0,
                setup.accounts.alice.account.contract_address,
                setup.accounts.bob.account.contract_address,
                100,
            );
        transfer_manager.get_transfer(transfer_id);
    }

    #[test]
    fn test_when_transfer_exists_should_return_transfer() {
        let (setup, transfer_manager, transfer_id) = setup_full_suite_with_transfer(false);

        let transfer = transfer_manager.get_transfer(transfer_id);
        assert_eq!(transfer.token_address, setup.token.contract_address);
        assert_eq!(transfer.sender, setup.accounts.alice.account.contract_address);
        assert_eq!(transfer.recipient, setup.accounts.bob.account.contract_address);
        assert_eq!(transfer.amount, 100);
        assert_eq!(transfer.status, TransferStatus::PENDING);
        assert_eq!(transfer.approvers.len(), 3);
        assert_eq!(*transfer.approvers.at(0).wallet, setup.accounts.bob.account.contract_address);
        assert_eq!(*transfer.approvers.at(0).approved, false);
        assert_eq!(*transfer.approvers.at(1).wallet, Zero::zero());
        assert_eq!(*transfer.approvers.at(1).approved, false);
        assert_eq!(
            *transfer.approvers.at(2).wallet, setup.accounts.charlie.account.contract_address,
        );
        assert_eq!(*transfer.approvers.at(2).approved, false);
    }
}

mod get_next_tx_nonce {
    use super::{
        IDVATransferManagerDispatcherTrait, setup_full_suite_with_transfer,
        setup_full_suite_with_verified_transfer_manager,
    };

    #[test]
    fn test_when_no_transfer_should_return_zero() {
        let (_, transfer_manager) = setup_full_suite_with_verified_transfer_manager();
        assert_eq!(transfer_manager.get_next_tx_nonce(), 0);
    }

    #[test]
    fn test_when_one_transfer_exists_should_return_one() {
        let (_, transfer_manager, _) = setup_full_suite_with_transfer(false);
        assert_eq!(transfer_manager.get_next_tx_nonce(), 1);
    }
}

mod get_next_approver {
    use super::*;

    #[test]
    #[should_panic(expected: 'Invalid transfer ID')]
    fn test_when_transfer_does_not_exist_should_panic() {
        let (setup, transfer_manager) = setup_full_suite_with_verified_transfer_manager();
        let transfer_id = transfer_manager
            .calculate_transfer_id(
                0,
                setup.accounts.alice.account.contract_address,
                setup.accounts.bob.account.contract_address,
                100,
            );
        transfer_manager.get_next_approver(transfer_id);
    }

    #[test]
    #[should_panic(expected: 'Transfer not in pending status')]
    fn test_when_transfer_status_is_not_pending_should_panic() {
        let (setup, transfer_manager, transfer_id) = setup_full_suite_with_transfer(false);

        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        transfer_manager.cancel_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);

        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        transfer_manager.get_next_approver(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);
    }

    #[test]
    fn test_when_no_one_approved_the_transfer_should_return_first_approver() {
        let (setup, transfer_manager, transfer_id) = setup_full_suite_with_transfer(true);
        let (next_approver, any_token_agent) = transfer_manager.get_next_approver(transfer_id);
        assert_eq!(next_approver, setup.accounts.bob.account.contract_address);
        assert_eq!(any_token_agent, false);
    }

    #[test]
    fn test_when_one_approver_approved_the_transfer_should_return_second_approver() {
        let (setup, transfer_manager, transfer_id) = setup_full_suite_with_transfer(true);

        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.bob.account.contract_address,
        );
        transfer_manager.approve_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);

        let (next_approver, any_token_agent) = transfer_manager.get_next_approver(transfer_id);
        assert_eq!(next_approver, Zero::zero());
        assert_eq!(any_token_agent, true);
    }
}

mod get_approval_criteria {
    use super::{
        IDVATransferManagerDispatcherTrait, setup_full_suite_with_transfer,
        setup_full_suite_with_verified_transfer_manager,
    };

    #[test]
    #[should_panic(expected: 'Token is not registered')]
    fn test_when_token_is_not_registered_should_panic() {
        let (setup, transfer_manager) = setup_full_suite_with_verified_transfer_manager();
        transfer_manager.get_approval_criteria(setup.token.contract_address);
    }

    #[test]
    fn test_when_token_is_registered_should_return_criteria() {
        let (setup, transfer_manager, _) = setup_full_suite_with_transfer(true);
        let approval_criteria = transfer_manager
            .get_approval_criteria(setup.token.contract_address);
        assert_eq!(approval_criteria.include_recipient_approver, true);
        assert_eq!(approval_criteria.include_agent_approver, true);
        assert_eq!(approval_criteria.sequential_approval, true);
        assert_eq!(
            approval_criteria.additional_approvers,
            array![setup.accounts.charlie.account.contract_address],
        );
    }
}

mod name {
    use super::{
        IDVATransferManagerDispatcherTrait, setup_full_suite_with_verified_transfer_manager,
    };

    #[test]
    fn test_should_return_module_name() {
        let (_, transfer_manager) = setup_full_suite_with_verified_transfer_manager();
        assert_eq!(transfer_manager.name(), "DVATransferManager");
    }
}
