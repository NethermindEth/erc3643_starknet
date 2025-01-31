use core::num::traits::Zero;
use dva::dva_transfer_manager::DVATransferManager;
use dva::dva_transfer_manager::DVATransferManager::SNIP12MetadataImpl;
use dva::idva_transfer_manager::{
    DelegatedApproval, DelegatedApprovalMessage, DelegatedApprovalMessageStructHash, Events::*,
    IDVATransferManagerDispatcher, IDVATransferManagerDispatcherTrait, TransferStatus,
};
use factory::tests_common::{Account, FullSuiteSetup, generate_account, setup_full_suite};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin_utils::cryptography::snip12::OffchainMessageHash;
use registry::interface::iidentity_registry::IIdentityRegistryDispatcherTrait;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare,
    signature::{
        SignerTrait,
        stark_curve::{StarkCurveKeyPairImpl, StarkCurveSignerImpl, StarkCurveVerifierImpl},
    },
    spy_events, start_cheat_caller_address, stop_cheat_caller_address,
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

fn sign_transfer(transfer_id: felt252, signer: Account) -> DelegatedApproval {
    let approval = DelegatedApprovalMessage { transfer_id };
    let approval_hash = approval.get_message_hash(signer.account.contract_address);
    let (r, s) = signer.key_pair.sign(approval_hash).unwrap();
    DelegatedApproval { signer: signer.account.contract_address, signature: array![r, s] }
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

mod initiate_transfer {
    use super::*;

    #[test]
    #[should_panic(expected: 'Token is not registered')]
    fn test_when_token_is_not_registered_should_panic() {
        let (setup, transfer_manager) = setup_full_suite_with_transfer_manager();

        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        transfer_manager
            .initiate_transfer(
                setup.token.contract_address, setup.accounts.bob.account.contract_address, 10,
            );
        stop_cheat_caller_address(transfer_manager.contract_address);
    }

    // Describe: When token is registered to the DVA manager

    #[test]
    #[should_panic(expected: 'Recipient is not verified')]
    fn test_when_recipient_is_not_verified_for_the_token_should_panic() {
        let (setup, transfer_manager) = setup_full_suite_with_verified_transfer_manager();
        let token_address = setup.token.contract_address;

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
                    setup.accounts.charlie.account.contract_address,
                    starknet::contract_address_const::<'ANOTHER_WALLET'>(),
                ]
                    .span(),
            );
        stop_cheat_caller_address(transfer_manager.contract_address);

        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        transfer_manager
            .initiate_transfer(
                token_address, starknet::contract_address_const::<'ANOTHER_WALLET'>(), 10,
            );
        stop_cheat_caller_address(transfer_manager.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Insufficient available balance')]
    fn test_when_amount_is_higher_than_sender_balance_should_panic() {
        let (setup, transfer_manager) = setup_full_suite_with_verified_transfer_manager();
        let token_address = setup.token.contract_address;

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
                    setup.accounts.charlie.account.contract_address,
                    starknet::contract_address_const::<'ANOTHER_WALLET'>(),
                ]
                    .span(),
            );
        stop_cheat_caller_address(transfer_manager.contract_address);

        start_cheat_caller_address(token_address, setup.accounts.alice.account.contract_address);
        IERC20Dispatcher { contract_address: token_address }
            .approve(transfer_manager.contract_address, 100000);
        stop_cheat_caller_address(token_address);

        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        transfer_manager
            .initiate_transfer(token_address, setup.accounts.bob.account.contract_address, 100000);
        stop_cheat_caller_address(transfer_manager.contract_address);
    }

    // Describe: When sender has enough balance

    #[test]
    fn test_when_include_recipient_approver_is_true_should_initiate_transfer_with_recipient_approver() {
        let (setup, transfer_manager) = setup_full_suite_with_verified_transfer_manager();
        let token_address = setup.token.contract_address;
        let alice = setup.accounts.alice.account.contract_address;
        let bob = setup.accounts.bob.account.contract_address;

        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        transfer_manager.set_approval_criteria(token_address, true, false, true, array![].span());
        stop_cheat_caller_address(transfer_manager.contract_address);

        start_cheat_caller_address(token_address, alice);
        IERC20Dispatcher { contract_address: token_address }
            .approve(transfer_manager.contract_address, 100000);
        stop_cheat_caller_address(token_address);

        let transfer_id = transfer_manager.calculate_transfer_id(0, alice, bob, 100);

        let mut spy = spy_events();
        start_cheat_caller_address(transfer_manager.contract_address, alice);
        transfer_manager.initiate_transfer(token_address, bob, 100);
        stop_cheat_caller_address(transfer_manager.contract_address);

        let transfer = transfer_manager.get_transfer(transfer_id);
        assert_eq!(transfer.approvers.len(), 1);
        assert_eq!(*transfer.approvers.at(0).wallet, bob);
        assert_eq!(*transfer.approvers.at(0).approved, false);
        spy
            .assert_emitted(
                @array![
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferInitiated(
                            TransferInitiated {
                                transfer_id,
                                token_address,
                                sender: alice,
                                recipient: bob,
                                amount: 100,
                                approval_criteria_hash: transfer_manager
                                    .get_approval_criteria(token_address)
                                    .hash,
                            },
                        ),
                    ),
                ],
            )
    }

    #[test]
    fn test_when_include_agent_approver_is_true_should_initiate_transfer_with_token_agent_approver() {
        let (setup, transfer_manager) = setup_full_suite_with_verified_transfer_manager();
        let token_address = setup.token.contract_address;
        let alice = setup.accounts.alice.account.contract_address;
        let bob = setup.accounts.bob.account.contract_address;

        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        transfer_manager.set_approval_criteria(token_address, false, true, true, array![].span());
        stop_cheat_caller_address(transfer_manager.contract_address);

        start_cheat_caller_address(token_address, alice);
        IERC20Dispatcher { contract_address: token_address }
            .approve(transfer_manager.contract_address, 100000);
        stop_cheat_caller_address(token_address);

        let transfer_id = transfer_manager.calculate_transfer_id(0, alice, bob, 100);

        let mut spy = spy_events();
        start_cheat_caller_address(transfer_manager.contract_address, alice);
        transfer_manager.initiate_transfer(token_address, bob, 100);
        stop_cheat_caller_address(transfer_manager.contract_address);

        let transfer = transfer_manager.get_transfer(transfer_id);
        assert_eq!(transfer.approvers.len(), 1);
        assert_eq!(*transfer.approvers.at(0).wallet, Zero::zero());
        assert_eq!(*transfer.approvers.at(0).approved, false);
        spy
            .assert_emitted(
                @array![
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferInitiated(
                            TransferInitiated {
                                transfer_id,
                                token_address,
                                sender: alice,
                                recipient: bob,
                                amount: 100,
                                approval_criteria_hash: transfer_manager
                                    .get_approval_criteria(token_address)
                                    .hash,
                            },
                        ),
                    ),
                ],
            )
    }

    #[test]
    fn test_when_additional_approvers_exist_should_initiate_transfer_with_token_agent_approver() {
        let (setup, transfer_manager) = setup_full_suite_with_verified_transfer_manager();
        let token_address = setup.token.contract_address;
        let alice = setup.accounts.alice.account.contract_address;
        let bob = setup.accounts.bob.account.contract_address;
        let charlie = setup.accounts.charlie.account.contract_address;
        let another_wallet = starknet::contract_address_const::<'ANOTHER_WALLET'>();

        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        transfer_manager
            .set_approval_criteria(
                token_address, false, false, true, array![charlie, another_wallet].span(),
            );
        stop_cheat_caller_address(transfer_manager.contract_address);

        start_cheat_caller_address(token_address, alice);
        IERC20Dispatcher { contract_address: token_address }
            .approve(transfer_manager.contract_address, 100000);
        stop_cheat_caller_address(token_address);

        let transfer_id = transfer_manager.calculate_transfer_id(0, alice, bob, 100);

        let mut spy = spy_events();
        start_cheat_caller_address(transfer_manager.contract_address, alice);
        transfer_manager.initiate_transfer(token_address, bob, 100);
        stop_cheat_caller_address(transfer_manager.contract_address);

        let transfer = transfer_manager.get_transfer(transfer_id);
        assert_eq!(transfer.approvers.len(), 2);
        assert_eq!(*transfer.approvers.at(0).wallet, charlie);
        assert_eq!(*transfer.approvers.at(0).approved, false);
        assert_eq!(*transfer.approvers.at(1).wallet, another_wallet);
        assert_eq!(*transfer.approvers.at(1).approved, false);
        spy
            .assert_emitted(
                @array![
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferInitiated(
                            TransferInitiated {
                                transfer_id,
                                token_address,
                                sender: alice,
                                recipient: bob,
                                amount: 100,
                                approval_criteria_hash: transfer_manager
                                    .get_approval_criteria(token_address)
                                    .hash,
                            },
                        ),
                    ),
                ],
            )
    }

    #[test]
    fn test_when_all_criteria_are_enabled_should_initiate_the_transfer_with_all_approvers() {
        let (setup, transfer_manager) = setup_full_suite_with_verified_transfer_manager();
        let token_address = setup.token.contract_address;
        let alice = setup.accounts.alice.account.contract_address;
        let bob = setup.accounts.bob.account.contract_address;
        let charlie = setup.accounts.charlie.account.contract_address;
        let another_wallet = starknet::contract_address_const::<'ANOTHER_WALLET'>();
        let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };

        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        transfer_manager
            .set_approval_criteria(
                token_address, true, true, true, array![charlie, another_wallet].span(),
            );
        stop_cheat_caller_address(transfer_manager.contract_address);

        start_cheat_caller_address(token_address, alice);
        erc20_dispatcher.approve(transfer_manager.contract_address, 100000);
        stop_cheat_caller_address(token_address);

        let transfer_id = transfer_manager.calculate_transfer_id(0, alice, bob, 100);

        let mut spy = spy_events();
        start_cheat_caller_address(transfer_manager.contract_address, alice);
        transfer_manager.initiate_transfer(token_address, bob, 100);
        stop_cheat_caller_address(transfer_manager.contract_address);

        let transfer = transfer_manager.get_transfer(transfer_id);
        assert_eq!(transfer.approvers.len(), 4);
        assert_eq!(*transfer.approvers.at(0).wallet, bob);
        assert_eq!(*transfer.approvers.at(0).approved, false);
        assert_eq!(*transfer.approvers.at(1).wallet, Zero::zero());
        assert_eq!(*transfer.approvers.at(1).approved, false);
        assert_eq!(*transfer.approvers.at(2).wallet, charlie);
        assert_eq!(*transfer.approvers.at(2).approved, false);
        assert_eq!(*transfer.approvers.at(3).wallet, another_wallet);
        assert_eq!(*transfer.approvers.at(3).approved, false);

        assert_eq!(erc20_dispatcher.balance_of(alice), 900);
        assert_eq!(erc20_dispatcher.balance_of(transfer_manager.contract_address), 100);

        spy
            .assert_emitted(
                @array![
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferInitiated(
                            TransferInitiated {
                                transfer_id,
                                token_address,
                                sender: alice,
                                recipient: bob,
                                amount: 100,
                                approval_criteria_hash: transfer_manager
                                    .get_approval_criteria(token_address)
                                    .hash,
                            },
                        ),
                    ),
                ],
            )
    }
}

mod approve_transfer {
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
        transfer_manager.approve_transfer(transfer_id);
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

        transfer_manager.approve_transfer(transfer_id);
    }

    // Describe: When approval criteria are changed after the transfer has been initiated

    #[test]
    fn test_when_trying_to_approve_before_approval_state_reset_should_reset_approvers() {
        let (setup, transfer_manager, transfer_id) = setup_full_suite_with_transfer(false);
        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        transfer_manager
            .set_approval_criteria(
                setup.token.contract_address,
                false,
                false,
                false,
                array![setup.accounts.david.account.contract_address].span(),
            );
        stop_cheat_caller_address(transfer_manager.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.charlie.account.contract_address,
        );
        transfer_manager.approve_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);
        spy
            .assert_emitted(
                @array![
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferApprovalStateReset(
                            TransferApprovalStateReset {
                                transfer_id,
                                approval_criteria_hash: transfer_manager
                                    .get_approval_criteria(setup.token.contract_address)
                                    .hash,
                            },
                        ),
                    ),
                ],
            );

        let transfer = transfer_manager.get_transfer(transfer_id);
        assert_eq!(transfer.approvers.len(), 1);
        assert_eq!(*transfer.approvers.at(0).wallet, setup.accounts.david.account.contract_address);
        assert_eq!(*transfer.approvers.at(0).approved, false);
    }

    #[test]
    fn test_when_trying_to_approve_after_approval_state_reset_should_approve() {
        let (setup, transfer_manager, transfer_id) = setup_full_suite_with_transfer(false);
        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        transfer_manager
            .set_approval_criteria(
                setup.token.contract_address,
                false,
                false,
                false,
                array![setup.accounts.david.account.contract_address].span(),
            );
        stop_cheat_caller_address(transfer_manager.contract_address);

        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.charlie.account.contract_address,
        );
        transfer_manager.approve_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.david.account.contract_address,
        );
        transfer_manager.approve_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);
        spy
            .assert_emitted(
                @array![
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferApproved(
                            TransferApproved {
                                transfer_id,
                                approver: setup.accounts.david.account.contract_address,
                            },
                        ),
                    ),
                ],
            );
    }

    // Describe: When sequential approval is disabled

    #[test]
    #[should_panic(expected: 'Approver not found')]
    fn test_when_caller_is_not_an_approver_should_panic() {
        let (_, transfer_manager, transfer_id) = setup_full_suite_with_transfer(false);
        transfer_manager.approve_transfer(transfer_id);
    }

    #[test]
    fn test_when_caller_is_the_last_approver_should_approve() {
        let (setup, transfer_manager, transfer_id) = setup_full_suite_with_transfer(false);
        let mut spy = spy_events();
        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.charlie.account.contract_address,
        );
        transfer_manager.approve_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);
        spy
            .assert_emitted(
                @array![
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferApproved(
                            TransferApproved {
                                transfer_id,
                                approver: setup.accounts.charlie.account.contract_address,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_when_all_parties_approve_the_transfer_should_complete() {
        let (setup, transfer_manager, transfer_id) = setup_full_suite_with_transfer(false);
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };

        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        transfer_manager.approve_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);
        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.bob.account.contract_address,
        );
        transfer_manager.approve_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.charlie.account.contract_address,
        );
        transfer_manager.approve_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferApproved(
                            TransferApproved {
                                transfer_id,
                                approver: setup.accounts.charlie.account.contract_address,
                            },
                        ),
                    ),
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferCompleted(
                            TransferCompleted {
                                transfer_id,
                                token_address: setup.token.contract_address,
                                sender: setup.accounts.alice.account.contract_address,
                                recipient: setup.accounts.bob.account.contract_address,
                                amount: 100,
                            },
                        ),
                    ),
                ],
            );
        let transfer = transfer_manager.get_transfer(transfer_id);
        assert_eq!(transfer.status, TransferStatus::COMPLETED);

        assert_eq!(erc20_dispatcher.balance_of(setup.accounts.alice.account.contract_address), 900);
        assert_eq!(erc20_dispatcher.balance_of(setup.accounts.bob.account.contract_address), 600);
        assert_eq!(erc20_dispatcher.balance_of(transfer_manager.contract_address), 0);
    }

    // Describe: When sequential approval is enabled

    #[test]
    #[should_panic(expected: 'Approvals must be sequential')]
    fn test_when_caller_is_not_the_next_approver_should_panic() {
        let (setup, transfer_manager, transfer_id) = setup_full_suite_with_transfer(true);
        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.charlie.account.contract_address,
        );
        transfer_manager.approve_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);
    }

    #[test]
    fn test_when_caller_is_the_next_approver_and_is_token_agent_should_approve() {
        let (setup, transfer_manager, transfer_id) = setup_full_suite_with_transfer(true);

        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.bob.account.contract_address,
        );
        transfer_manager.approve_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        transfer_manager.approve_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferApproved(
                            TransferApproved {
                                transfer_id,
                                approver: setup.accounts.token_agent.account.contract_address,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_when_all_parties_approve_the_transfer_should_complete_sequential() {
        let (setup, transfer_manager, transfer_id) = setup_full_suite_with_transfer(true);
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };

        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.bob.account.contract_address,
        );
        transfer_manager.approve_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);
        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        transfer_manager.approve_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.charlie.account.contract_address,
        );
        transfer_manager.approve_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);
        spy
            .assert_emitted(
                @array![
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferApproved(
                            TransferApproved {
                                transfer_id,
                                approver: setup.accounts.charlie.account.contract_address,
                            },
                        ),
                    ),
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferCompleted(
                            TransferCompleted {
                                transfer_id,
                                token_address: setup.token.contract_address,
                                sender: setup.accounts.alice.account.contract_address,
                                recipient: setup.accounts.bob.account.contract_address,
                                amount: 100,
                            },
                        ),
                    ),
                ],
            );

        let transfer = transfer_manager.get_transfer(transfer_id);
        assert_eq!(transfer.status, TransferStatus::COMPLETED);

        assert_eq!(erc20_dispatcher.balance_of(setup.accounts.alice.account.contract_address), 900);
        assert_eq!(erc20_dispatcher.balance_of(setup.accounts.bob.account.contract_address), 600);
        assert_eq!(erc20_dispatcher.balance_of(transfer_manager.contract_address), 0);
    }
}

mod delegate_approve_transfer {
    use super::*;

    #[test]
    #[should_panic(expected: 'Signatures can not be empty')]
    fn test_when_signatures_array_is_empty_should_panic() {
        let (setup, transfer_manager) = setup_full_suite_with_verified_transfer_manager();
        let transfer_id = transfer_manager
            .calculate_transfer_id(
                0,
                setup.accounts.alice.account.contract_address,
                setup.accounts.bob.account.contract_address,
                100,
            );

        transfer_manager.delegate_approve_transfer(transfer_id, array![]);
    }

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
        transfer_manager
            .delegate_approve_transfer(
                transfer_id, array![sign_transfer(transfer_id, setup.accounts.charlie)],
            );
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

        transfer_manager
            .delegate_approve_transfer(
                transfer_id, array![sign_transfer(transfer_id, setup.accounts.charlie)],
            );
    }

    // Describe: When approval criteria are changed after the transfer has been initiated

    #[test]
    fn test_when_trying_to_approve_before_approval_state_reset_should_reset_approvers() {
        let (setup, transfer_manager, transfer_id) = setup_full_suite_with_transfer(false);
        let another_wallet = starknet::contract_address_const::<'ANOTHER_WALLET'>();

        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        transfer_manager
            .set_approval_criteria(
                setup.token.contract_address,
                false,
                false,
                false,
                array![setup.accounts.david.account.contract_address].span(),
            );
        stop_cheat_caller_address(transfer_manager.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(transfer_manager.contract_address, another_wallet);
        transfer_manager
            .delegate_approve_transfer(
                transfer_id, array![sign_transfer(transfer_id, setup.accounts.charlie)],
            );
        stop_cheat_caller_address(transfer_manager.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferApprovalStateReset(
                            TransferApprovalStateReset {
                                transfer_id,
                                approval_criteria_hash: transfer_manager
                                    .get_approval_criteria(setup.token.contract_address)
                                    .hash,
                            },
                        ),
                    ),
                ],
            );

        let transfer = transfer_manager.get_transfer(transfer_id);
        assert_eq!(transfer.approvers.len(), 1);
        assert_eq!(*transfer.approvers.at(0).wallet, setup.accounts.david.account.contract_address);
        assert_eq!(*transfer.approvers.at(0).approved, false);
    }

    #[test]
    fn test_when_trying_to_approve_after_approval_state_reset_should_approve() {
        let (setup, transfer_manager, transfer_id) = setup_full_suite_with_transfer(false);
        let another_wallet = starknet::contract_address_const::<'ANOTHER_WALLET'>();

        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        transfer_manager
            .set_approval_criteria(
                setup.token.contract_address,
                false,
                false,
                false,
                array![setup.accounts.david.account.contract_address].span(),
            );
        stop_cheat_caller_address(transfer_manager.contract_address);
        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.charlie.account.contract_address,
        );
        transfer_manager.approve_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(transfer_manager.contract_address, another_wallet);
        transfer_manager
            .delegate_approve_transfer(
                transfer_id, array![sign_transfer(transfer_id, setup.accounts.david)],
            );
        stop_cheat_caller_address(transfer_manager.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferApproved(
                            TransferApproved {
                                transfer_id,
                                approver: setup.accounts.david.account.contract_address,
                            },
                        ),
                    ),
                ],
            );
    }

    // Describe: When sequential approval is disabled

    #[test]
    #[should_panic(expected: 'Approver not found')]
    fn test_when_caller_is_not_an_approver_should_panic() {
        let (_, transfer_manager, transfer_id) = setup_full_suite_with_transfer(false);
        transfer_manager
            .delegate_approve_transfer(
                transfer_id, array![sign_transfer(transfer_id, generate_account())],
            );
    }

    #[test]
    fn test_when_signer_is_an_approver_should_approve() {
        let (setup, transfer_manager, transfer_id) = setup_full_suite_with_transfer(false);
        let another_wallet = starknet::contract_address_const::<'ANOTHER_WALLET'>();

        let mut spy = spy_events();
        start_cheat_caller_address(transfer_manager.contract_address, another_wallet);
        transfer_manager
            .delegate_approve_transfer(
                transfer_id, array![sign_transfer(transfer_id, setup.accounts.charlie)],
            );
        stop_cheat_caller_address(transfer_manager.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferApproved(
                            TransferApproved {
                                transfer_id,
                                approver: setup.accounts.charlie.account.contract_address,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_when_all_parties_approve_the_transfer_should_complete() {
        let (setup, transfer_manager, transfer_id) = setup_full_suite_with_transfer(false);
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };

        let mut spy = spy_events();
        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        transfer_manager
            .delegate_approve_transfer(
                transfer_id,
                array![
                    sign_transfer(transfer_id, setup.accounts.token_agent),
                    sign_transfer(transfer_id, setup.accounts.bob),
                    sign_transfer(transfer_id, setup.accounts.charlie),
                ],
            );
        stop_cheat_caller_address(transfer_manager.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferApproved(
                            TransferApproved {
                                transfer_id,
                                approver: setup.accounts.token_agent.account.contract_address,
                            },
                        ),
                    ),
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferApproved(
                            TransferApproved {
                                transfer_id, approver: setup.accounts.bob.account.contract_address,
                            },
                        ),
                    ),
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferApproved(
                            TransferApproved {
                                transfer_id,
                                approver: setup.accounts.charlie.account.contract_address,
                            },
                        ),
                    ),
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferCompleted(
                            TransferCompleted {
                                transfer_id,
                                token_address: setup.token.contract_address,
                                sender: setup.accounts.alice.account.contract_address,
                                recipient: setup.accounts.bob.account.contract_address,
                                amount: 100,
                            },
                        ),
                    ),
                ],
            );

        let transfer = transfer_manager.get_transfer(transfer_id);
        assert_eq!(transfer.status, TransferStatus::COMPLETED);

        assert_eq!(erc20_dispatcher.balance_of(setup.accounts.alice.account.contract_address), 900);
        assert_eq!(erc20_dispatcher.balance_of(setup.accounts.bob.account.contract_address), 600);
        assert_eq!(erc20_dispatcher.balance_of(transfer_manager.contract_address), 0);
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

mod reject_transfer {
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
        transfer_manager.reject_transfer(transfer_id);
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

        transfer_manager.reject_transfer(transfer_id);
    }

    // Describe: When sequential approval is disabled

    #[test]
    #[should_panic(expected: 'Approver not found')]
    fn test_when_caller_is_not_an_approver_should_panic() {
        let (_, transfer_manager, transfer_id) = setup_full_suite_with_transfer(false);
        transfer_manager.reject_transfer(transfer_id);
    }

    #[test]
    fn test_when_caller_is_the_last_approver_should_reject() {
        let (setup, transfer_manager, transfer_id) = setup_full_suite_with_transfer(false);
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };

        let mut spy = spy_events();
        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.charlie.account.contract_address,
        );
        transfer_manager.reject_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferRejected(
                            TransferRejected {
                                transfer_id,
                                rejected_by: setup.accounts.charlie.account.contract_address,
                            },
                        ),
                    ),
                ],
            );
        let transfer = transfer_manager.get_transfer(transfer_id);
        assert_eq!(transfer.status, TransferStatus::REJECTED);

        assert_eq!(
            erc20_dispatcher.balance_of(setup.accounts.alice.account.contract_address), 1000,
        );
    }

    // Describe: When sequential approval is enabled

    #[test]
    #[should_panic(expected: 'Approvals must be sequential')]
    fn test_when_caller_is_not_the_next_approver_should_panic() {
        let (setup, transfer_manager, transfer_id) = setup_full_suite_with_transfer(true);
        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.charlie.account.contract_address,
        );
        transfer_manager.reject_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);
    }

    #[test]
    fn test_when_caller_is_the_next_approver_and_is_token_agent_should_reject() {
        let (setup, transfer_manager, transfer_id) = setup_full_suite_with_transfer(true);
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };

        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.bob.account.contract_address,
        );
        transfer_manager.approve_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        transfer_manager.reject_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferRejected(
                            TransferRejected {
                                transfer_id,
                                rejected_by: setup.accounts.token_agent.account.contract_address,
                            },
                        ),
                    ),
                ],
            );

        let transfer = transfer_manager.get_transfer(transfer_id);
        assert_eq!(transfer.status, TransferStatus::REJECTED);

        assert_eq!(
            erc20_dispatcher.balance_of(setup.accounts.alice.account.contract_address), 1000,
        );
    }

    // Describe: When approval criteria are changed after the transfer has been initiated

    #[test]
    fn test_when_trying_to_reject_before_approval_state_reset_should_reset_approvers() {
        let (setup, transfer_manager, transfer_id) = setup_full_suite_with_transfer(false);

        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        transfer_manager
            .set_approval_criteria(
                setup.token.contract_address,
                false,
                false,
                false,
                array![setup.accounts.david.account.contract_address].span(),
            );
        stop_cheat_caller_address(transfer_manager.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.charlie.account.contract_address,
        );
        transfer_manager.reject_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferApprovalStateReset(
                            TransferApprovalStateReset {
                                transfer_id,
                                approval_criteria_hash: transfer_manager
                                    .get_approval_criteria(setup.token.contract_address)
                                    .hash,
                            },
                        ),
                    ),
                ],
            );

        let transfer = transfer_manager.get_transfer(transfer_id);
        assert_eq!(transfer.approvers.len(), 1);
        assert_eq!(*transfer.approvers.at(0).wallet, setup.accounts.david.account.contract_address);
        assert_eq!(*transfer.approvers.at(0).approved, false);
    }

    #[test]
    fn test_when_trying_to_reject_after_approval_state_reset_should_reject() {
        let (setup, transfer_manager, transfer_id) = setup_full_suite_with_transfer(false);
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };

        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        transfer_manager
            .set_approval_criteria(
                setup.token.contract_address,
                false,
                false,
                false,
                array![setup.accounts.david.account.contract_address].span(),
            );
        stop_cheat_caller_address(transfer_manager.contract_address);

        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.charlie.account.contract_address,
        );
        transfer_manager.reject_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(
            transfer_manager.contract_address, setup.accounts.david.account.contract_address,
        );
        transfer_manager.reject_transfer(transfer_id);
        stop_cheat_caller_address(transfer_manager.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        transfer_manager.contract_address,
                        DVATransferManager::Event::TransferRejected(
                            TransferRejected {
                                transfer_id,
                                rejected_by: setup.accounts.david.account.contract_address,
                            },
                        ),
                    ),
                ],
            );

        let transfer = transfer_manager.get_transfer(transfer_id);
        assert_eq!(transfer.status, TransferStatus::REJECTED);

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
