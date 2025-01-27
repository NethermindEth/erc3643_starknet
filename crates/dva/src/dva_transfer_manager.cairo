#[starknet::contract]
pub mod DVATransferManager {
    use core::num::traits::Zero;
    use core::poseidon::poseidon_hash_span;
    use dva::idva_transfer_manager::IDVATransferManager;
    use dva::idva_transfer_manager::{
        ApprovalCriteria, ApprovalCriteriaStore, ApprovalCriteriaStoreStorageNode,
    };
    use dva::idva_transfer_manager::{Approver, Errors, Events::*, TransferStatus};
    use dva::idva_transfer_manager::{DelegatedApproval, DelegatedApprovalMessage};
    use dva::idva_transfer_manager::{
        Transfer, TransferStore, TransferStoreStorageNode, TransferStoreStorageNodeMut,
    };
    use openzeppelin_account::interface::{ISRC6Dispatcher, ISRC6DispatcherTrait, ISRC6_ID};
    use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_utils::cryptography::snip12::{OffchainMessageHash, SNIP12Metadata};
    use registry::interface::iidentity_registry::IIdentityRegistryDispatcherTrait;
    use roles::agent_role::{IAgentRoleDispatcher, IAgentRoleDispatcherTrait};
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageAsPath, StorageNode, StorageNodeMut, StoragePathEntry, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use storage::storage_array::{
        MutableStorageArrayContractAddressImpl, MutableStorageArrayContractAddressIndexView,
        PathableMutableStorageArrayApproverImpl, PathableStorageArrayApproverImpl,
        StorageArrayContractAddressImpl, StorageArrayContractAddressIndexView,
    };
    use token::itoken::{ITokenDispatcher, ITokenDispatcherTrait};

    #[storage]
    struct Storage {
        /// Mapping for token approval criteria
        pub approval_criteria: Map<ContractAddress, ApprovalCriteriaStore>,
        /// Mapping for transfer requests
        pub transfers: Map<felt252, TransferStore>,
        tx_nonce: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ApprovalCriteriaSet: ApprovalCriteriaSet,
        TransferInitiated: TransferInitiated,
        TransferApproved: TransferApproved,
        TransferRejected: TransferRejected,
        TransferCancelled: TransferCancelled,
        TransferCompleted: TransferCompleted,
        TransferApprovalStateReset: TransferApprovalStateReset,
    }

    #[abi(embed_v0)]
    impl DVATransferManager of IDVATransferManager<ContractState> {
        fn set_approval_criteria(
            ref self: ContractState,
            token_address: ContractAddress,
            include_recipient_approver: bool,
            include_agent_approver: bool,
            sequential_approval: bool,
            additional_approvers: Span<ContractAddress>,
        ) {
            assert(
                IAgentRoleDispatcher { contract_address: token_address }
                    .is_agent(starknet::get_caller_address()),
                Errors::ONLY_TOKEN_AGENT_CAN_CALL,
            );

            assert(
                ITokenDispatcher { contract_address: token_address }
                    .identity_registry()
                    .is_verified(starknet::get_contract_address()),
                Errors::DVA_MANAGER_IS_NOT_VERIFIED_FOR_THE_TOKEN,
            );

            // Calculate approval criteria hash based on abi
            let mut abi_encoded: Array<felt252> = array![];
            token_address.serialize(ref abi_encoded);
            include_recipient_approver.serialize(ref abi_encoded);
            include_agent_approver.serialize(ref abi_encoded);
            sequential_approval.serialize(ref abi_encoded);
            additional_approvers.serialize(ref abi_encoded);
            let hash = poseidon_hash_span(abi_encoded.span());

            // Write approval criteria
            let mut approval_criteria = self.approval_criteria.entry(token_address);
            approval_criteria.include_recipient_approver.write(include_recipient_approver);
            approval_criteria.include_agent_approver.write(include_agent_approver);
            approval_criteria.sequential_approval.write(sequential_approval);
            approval_criteria.additional_approvers.as_path().clear();
            for approver in additional_approvers {
                approval_criteria.additional_approvers.as_path().append().write(*approver);
            };
            approval_criteria.hash.write(hash);

            self
                .emit(
                    ApprovalCriteriaSet {
                        token_address,
                        include_recipient_approver,
                        include_agent_approver,
                        sequential_approval,
                        additional_approvers,
                        hash,
                    },
                );
        }

        fn initiate_transfer(
            ref self: ContractState,
            token_address: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {
            let approval_criteria = (@self).approval_criteria.entry(token_address);
            let approval_criteria_hash = approval_criteria.hash.read();
            assert(approval_criteria_hash.is_non_zero(), Errors::TOKEN_IS_NOT_REGISTERED);

            let token = ITokenDispatcher { contract_address: token_address };
            assert(
                token.identity_registry().is_verified(recipient), Errors::RECIPIENT_IS_NOT_VERIFIED,
            );

            let caller = starknet::get_caller_address();

            let token = IERC20Dispatcher { contract_address: token_address };
            token.transfer_from(caller, starknet::get_contract_address(), amount);

            let nonce = self.tx_nonce.read() + 1;
            self.tx_nonce.write(nonce);
            let transfer_id = self.calculate_transfer_id(nonce, caller, recipient, amount);

            // Write transfer
            let transfer = self.transfers.entry(transfer_id);
            transfer.token_address.write(token_address);
            transfer.sender.write(caller);
            transfer.recipient.write(recipient);
            transfer.amount.write(amount);
            transfer.status.write(TransferStatus::PENDING);
            transfer.approval_criteria_hash.write(approval_criteria_hash);

            self
                .add_approvers_to_transfer(
                    transfer.storage_node_mut(), approval_criteria.storage_node(),
                );
            self
                .emit(
                    TransferInitiated {
                        transfer_id,
                        token_address,
                        sender: caller,
                        recipient,
                        amount,
                        approval_criteria_hash,
                    },
                );
        }

        fn approve_transfer(ref self: ContractState, transfer_id: felt252) {
            let transfer = self.get_pending_transfer_mut(transfer_id);
            if (self.approval_criteria_changed(transfer_id, transfer)) {
                return;
            };

            let all_approved = self
                ._approve_transfer(transfer_id, transfer, starknet::get_caller_address());
            if (all_approved) {
                self.complete_transfer(transfer_id, transfer);
            };
        }

        fn delegate_approve_transfer(
            ref self: ContractState,
            transfer_id: felt252,
            delegated_approvals: Array<DelegatedApproval>,
        ) {
            assert(delegated_approvals.len().is_non_zero(), Errors::SIGNATURES_CAN_NOT_BE_EMPTY);

            let transfer = self.get_pending_transfer_mut(transfer_id);
            if (self.approval_criteria_changed(transfer_id, transfer)) {
                return;
            };

            let delegated_approval_message = DelegatedApprovalMessage { transfer_id };
            for delegated_approval in delegated_approvals {
                // We can't recover the public key from only a signature
                // Instead, we require to also pass the ContractAdress public key
                // And delegate the signature verification to the contract for the given public key
                // and message hash
                assert(
                    ISRC5Dispatcher { contract_address: delegated_approval.signer }
                        .supports_interface(ISRC6_ID),
                    Errors::SIGNER_DOES_NOT_SUPPORT_SRC6,
                );

                assert(
                    ISRC6Dispatcher { contract_address: delegated_approval.signer }
                        .is_valid_signature(
                            delegated_approval_message.get_message_hash(delegated_approval.signer),
                            delegated_approval.signature,
                        ) == starknet::VALIDATED,
                    Errors::SIGNATURE_IS_INVALID,
                );

                let all_approved = self
                    ._approve_transfer(transfer_id, transfer, delegated_approval.signer);
                if (all_approved) {
                    self.complete_transfer(transfer_id, transfer);
                    break;
                };
            };
        }

        fn cancel_transfer(ref self: ContractState, transfer_id: felt252) {
            let transfer = self.get_pending_transfer_mut(transfer_id);
            let transfer_sender = transfer.sender.read();
            assert(
                transfer_sender == starknet::get_caller_address(),
                Errors::ONLY_TRANSFER_SENDER_CAN_CALL,
            );

            transfer.status.write(TransferStatus::CANCELLED);
            self.transfer_tokens_to(transfer, transfer_sender);
            self.emit(TransferCancelled { transfer_id });
        }

        fn reject_transfer(ref self: ContractState, transfer_id: felt252) {
            let transfer = self.get_pending_transfer_mut(transfer_id);
            if (self.approval_criteria_changed(transfer_id, transfer)) {
                return;
            };

            let caller = starknet::get_caller_address();
            let mut rejected = false;
            let approval_criteria = (@self).approval_criteria.entry(transfer.token_address.read());
            let token_address = transfer.token_address.read();
            let sequential_approval = approval_criteria.sequential_approval.read();
            for i in 0..transfer.approvers.len() {
                let approver = transfer.approvers.at(i).read();
                if (approver.approved) {
                    continue;
                }

                if (self.can_approve(token_address, approver, caller)) {
                    rejected = true;
                    break;
                }

                assert(!sequential_approval, Errors::APPROVALS_MUST_BE_SEQUENTIAL);
            };

            assert(rejected, Errors::APPROVER_NOT_FOUND);

            transfer.status.write(TransferStatus::REJECTED);
            self.transfer_tokens_to(transfer, transfer.sender.read());
            self.emit(TransferRejected { transfer_id, rejected_by: caller });
        }

        fn get_approval_criteria(
            self: @ContractState, token_address: ContractAddress,
        ) -> ApprovalCriteria {
            let approval_criteria = self.approval_criteria.entry(token_address);
            let hash = approval_criteria.hash.read();
            assert(hash.is_non_zero(), Errors::TOKEN_IS_NOT_REGISTERED);

            let mut additional_approvers = array![];
            for i in 0..approval_criteria.additional_approvers.as_path().len() {
                additional_approvers
                    .append(approval_criteria.additional_approvers.as_path()[i].read());
            };
            ApprovalCriteria {
                include_recipient_approver: approval_criteria.include_recipient_approver.read(),
                include_agent_approver: approval_criteria.include_agent_approver.read(),
                sequential_approval: approval_criteria.sequential_approval.read(),
                additional_approvers,
                hash,
            }
        }

        fn get_transfer(self: @ContractState, transfer_id: felt252) -> Transfer {
            let transfer = self.transfers.entry(transfer_id);
            let token_address = transfer.token_address.read();
            assert(token_address.is_non_zero(), Errors::INVALID_TRANSFER_ID);

            let mut approvers = array![];
            for i in 0..transfer.approvers.len() {
                approvers.append(transfer.approvers.at(i).read());
            };
            Transfer {
                token_address,
                sender: transfer.sender.read(),
                recipient: transfer.recipient.read(),
                amount: transfer.amount.read(),
                status: transfer.status.read(),
                approvers,
                approval_criteria_hash: transfer.approval_criteria_hash.read(),
            }
        }

        fn get_next_approver(
            self: @ContractState, transfer_id: felt252,
        ) -> (ContractAddress, bool) {
            let transfer = self.get_pending_transfer(transfer_id);
            let mut approver = Zero::zero();
            for i in 0..transfer.approvers.len() {
                approver = transfer.approvers.at(i).read();
                if (approver.approved) {
                    continue;
                }
                break;
            };
            (approver.wallet, approver.any_token_agent)
        }

        fn get_next_tx_nonce(self: @ContractState) -> u256 {
            self.tx_nonce.read()
        }

        fn name(self: @ContractState) -> ByteArray {
            "DVATransferManager"
        }

        fn calculate_transfer_id(
            self: @ContractState,
            nonce: u256,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) -> felt252 {
            let mut abi_encoded: Array<felt252> = array![];
            nonce.serialize(ref abi_encoded);
            sender.serialize(ref abi_encoded);
            recipient.serialize(ref abi_encoded);
            amount.serialize(ref abi_encoded);
            poseidon_hash_span(abi_encoded.span())
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _approve_transfer(
            ref self: ContractState,
            transfer_id: felt252,
            transfer: TransferStoreStorageNodeMut,
            caller: ContractAddress,
        ) -> bool {
            let mut approved = false;
            let mut pending_approver_count = 0;
            let token_address = transfer.token_address.read();
            let approval_criteria = (@self).approval_criteria.entry(token_address);
            for i in 0..transfer.approvers.len() {
                let mut approver = transfer.approvers.at(i).read();
                if (approver.approved) {
                    continue;
                }

                if (approved) {
                    pending_approver_count += 1;
                    break;
                }

                if (self.can_approve(token_address, approver, caller)) {
                    approved = true;
                    approver.approved = true;
                    transfer.approvers.at(i).write(approver);

                    if (approver.wallet.is_zero()) {
                        approver.wallet = caller;
                    }

                    self.emit(TransferApproved { transfer_id, approver: caller });
                    continue;
                }

                assert(
                    !approval_criteria.sequential_approval.read(),
                    Errors::APPROVALS_MUST_BE_SEQUENTIAL,
                );

                pending_approver_count += 1;
            };

            assert(approved, Errors::APPROVER_NOT_FOUND);

            pending_approver_count == 0
        }

        fn complete_transfer(
            ref self: ContractState, transfer_id: felt252, transfer: TransferStoreStorageNodeMut,
        ) {
            transfer.status.write(TransferStatus::COMPLETED);
            let recipient = transfer.recipient.read();
            self.transfer_tokens_to(transfer, recipient);
            self
                .emit(
                    TransferCompleted {
                        transfer_id,
                        token_address: transfer.token_address.read(),
                        sender: transfer.sender.read(),
                        recipient,
                        amount: transfer.amount.read(),
                    },
                );
        }

        fn approval_criteria_changed(
            ref self: ContractState, transfer_id: felt252, transfer: TransferStoreStorageNodeMut,
        ) -> bool {
            let approval_criteria = (@self).approval_criteria.entry(transfer.token_address.read());
            let approval_criteria_hash = approval_criteria.hash.read();
            if (transfer.approval_criteria_hash.read() == approval_criteria_hash) {
                return false;
            }

            // delete transfer.approvers;
            transfer.approvers.clear();
            self.add_approvers_to_transfer(transfer, approval_criteria.storage_node());
            self.emit(TransferApprovalStateReset { transfer_id, approval_criteria_hash });

            true
        }

        fn add_approvers_to_transfer(
            ref self: ContractState,
            transfer: TransferStoreStorageNodeMut,
            approval_criteria: ApprovalCriteriaStoreStorageNode,
        ) {
            if (approval_criteria.include_recipient_approver.read()) {
                transfer
                    .approvers
                    .append()
                    .write(
                        Approver {
                            wallet: transfer.recipient.read(),
                            any_token_agent: false,
                            approved: false,
                        },
                    );
            };

            if (approval_criteria.include_agent_approver.read()) {
                transfer
                    .approvers
                    .append()
                    .write(
                        Approver { wallet: Zero::zero(), any_token_agent: true, approved: false },
                    );
            };

            for i in 0..approval_criteria.additional_approvers.as_path().len() {
                transfer
                    .approvers
                    .append()
                    .write(
                        Approver {
                            wallet: approval_criteria.additional_approvers.as_path()[i].read(),
                            any_token_agent: false,
                            approved: false,
                        },
                    );
            };
        }

        fn transfer_tokens_to(
            self: @ContractState, transfer: TransferStoreStorageNodeMut, to: ContractAddress,
        ) {
            IERC20Dispatcher { contract_address: transfer.token_address.read() }
                .transfer(to, transfer.amount.read());
        }

        fn can_approve(
            self: @ContractState,
            transfer_token_address: ContractAddress,
            approver: Approver,
            caller: ContractAddress,
        ) -> bool {
            approver.wallet == caller
                || (approver.any_token_agent
                    && approver.wallet.is_zero()
                    && IAgentRoleDispatcher { contract_address: transfer_token_address }
                        .is_agent(caller))
        }

        fn get_pending_transfer(
            self: @ContractState, transfer_id: felt252,
        ) -> TransferStoreStorageNode {
            let transfer = self.transfers.entry(transfer_id);
            assert(transfer.token_address.read().is_non_zero(), Errors::INVALID_TRANSFER_ID);

            assert(
                transfer.status.read() == TransferStatus::PENDING,
                Errors::TRANSFER_IS_NOT_IN_PENDING_STATUS,
            );

            transfer.storage_node()
        }

        fn get_pending_transfer_mut(
            ref self: ContractState, transfer_id: felt252,
        ) -> TransferStoreStorageNodeMut {
            let transfer = self.transfers.entry(transfer_id);
            assert(transfer.token_address.read().is_non_zero(), Errors::INVALID_TRANSFER_ID);

            assert(
                transfer.status.read() == TransferStatus::PENDING,
                Errors::TRANSFER_IS_NOT_IN_PENDING_STATUS,
            );

            transfer.storage_node_mut()
        }
    }

    impl SNIP12MetadataImpl of SNIP12Metadata {
        fn name() -> felt252 {
            unsafe_new_contract_state().name().at(0).unwrap().into()
        }
        fn version() -> felt252 {
            'v1'
        }
    }
}
