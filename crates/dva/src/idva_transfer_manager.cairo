use core::num::traits::Zero;
use starknet::ContractAddress;
use starknet::secp256_trait::Signature;
use starknet::storage::Vec;

#[derive(Serde, Default, Drop, PartialEq, starknet::Store)]
pub enum TransferStatus {
    #[default]
    PENDING,
    COMPLETED,
    CANCELLED,
    REJECTED,
}

/// Criteria for approving transfers of a specific token
#[derive(Serde, Drop)]
pub struct ApprovalCriteria {
    /// Determines whether the recipient is included in the approver list
    pub include_recipient_approver: bool,
    /// Determines whether the agent is included in the approver list
    pub include_agent_approver: bool,
    /// Determines whether approvals must be sequential
    pub sequential_approval: bool,
    /// Addresses of additional approvers to be added to the approver list
    pub additional_approvers: Array<ContractAddress>,
    /// Hash of the approval criteria
    pub hash: felt252,
}

/// Storage struct for ApprovalCriteria
#[starknet::storage_node]
pub struct ApprovalCriteriaStore {
    pub include_recipient_approver: bool,
    pub include_agent_approver: bool,
    pub sequential_approval: bool,
    pub additional_approvers: Vec<ContractAddress>,
    pub hash: felt252,
}

/// Represents a transfer request with its current state and approval requirements
#[derive(Serde, Drop)]
pub struct Transfer {
    pub token_address: ContractAddress,
    pub sender: ContractAddress,
    pub recipient: ContractAddress,
    pub amount: u256,
    pub status: TransferStatus,
    pub approvers: Array<Approver>,
    pub approval_criteria_hash: felt252,
}

/// Storage struct for Transfer
#[starknet::storage_node]
pub struct TransferStore {
    pub token_address: ContractAddress,
    pub sender: ContractAddress,
    pub recipient: ContractAddress,
    pub amount: u256,
    pub status: TransferStatus,
    pub approvers: Vec<Approver>,
    pub approval_criteria_hash: felt252,
}

/// Represents an approver for a transfer with their approval status
#[derive(Serde, Copy, Drop, starknet::Store)]
pub struct Approver {
    /// Address of the approver. If any_token_agent is true, it will be zero on initialization
    pub wallet: ContractAddress,
    /// Indicates if this approver can approve transfers for any token
    pub any_token_agent: bool,
    /// Indicates if this approver has approved the transfer
    pub approved: bool,
}

pub mod Events {
    use starknet::ContractAddress;

    /// Emitted when an approval criteria of a token is modified
    #[derive(Drop, starknet::Event)]
    pub struct ApprovalCriteriaSet {
        #[key]
        pub token_address: ContractAddress,
        pub include_recipient_approver: bool,
        pub include_agent_approver: bool,
        pub sequential_approval: bool,
        pub additional_approvers: Span<ContractAddress>,
        pub hash: felt252,
    }

    /// Emitted when a new transfer is initiated
    #[derive(Drop, starknet::Event)]
    pub struct TransferInitiated {
        #[key]
        pub transfer_id: felt252,
        pub token_address: ContractAddress,
        pub sender: ContractAddress,
        pub recipient: ContractAddress,
        pub amount: u256,
        pub approval_criteria_hash: felt252,
    }

    /// Emitted when a transfer is approved by an approver
    #[derive(Drop, starknet::Event)]
    pub struct TransferApproved {
        #[key]
        pub transfer_id: felt252,
        pub approver: ContractAddress,
    }

    /// Emitted when a transfer is rejected by an approver
    #[derive(Drop, starknet::Event)]
    pub struct TransferRejected {
        #[key]
        pub transfer_id: felt252,
        pub rejected_by: ContractAddress,
    }

    /// Emitted when a transfer is cancelled by the sender
    #[derive(Drop, starknet::Event)]
    pub struct TransferCancelled {
        #[key]
        pub transfer_id: felt252,
    }

    /// Emitted when all approvers have approved a transfer and it is completed
    #[derive(Drop, starknet::Event)]
    pub struct TransferCompleted {
        #[key]
        pub transfer_id: felt252,
        pub token_address: ContractAddress,
        pub sender: ContractAddress,
        pub recipient: ContractAddress,
        pub amount: u256,
    }

    /// Emitted when a transfer's approval criteria are reset
    #[derive(Drop, starknet::Event)]
    pub struct TransferApprovalReset {
        #[key]
        pub transfer_id: felt252,
        pub approval_criteria_hash: felt252,
    }
}

pub mod Errors {
    pub const ONLY_TOKEN_AGENT_CAN_CALL: felt252 = 'Only token agent can call';
    pub const ONLY_TRANSFER_SENDER_CAN_CALL: felt252 = 'Only transfer sender can call';
    pub const TOKEN_IS_NOT_REGISTERED: felt252 = 'Token is not registered';
    pub const RECIPIENT_IS_NOT_VERIFIED: felt252 = 'Recipient is not verified';
    pub const DVA_MANAGER_IS_NOT_VERIFIED_FOR_THE_TOKEN: felt252 =
        'DVA Mngr not verified for token';
    pub const INVALID_TRANSFER_ID: felt252 = 'Invalid transfer ID';
    pub const TRANSFER_IS_NOT_IN_PENDING_STATUS: felt252 = 'Transfer not in pending status';
    pub const APPROVALS_MUST_BE_SEQUENTIAL: felt252 = 'Approvals must be sequential';
    pub const APPROVER_NOT_FOUND: felt252 = 'Approver not found';
    pub const SIGNATURES_CAN_NOT_BE_EMPTY: felt252 = 'Signatures can not be empty';
}

/// Interface for managing Dual Validation Authority (DVA) transfers
#[starknet::interface]
pub trait IDVATransferManager<TContractState> {
    /// Modifies the approval criteria for a specific token
    /// * `token_address` - The address of the token
    /// * `include_recipient_approver` - Whether to include recipient in approver list
    /// * `include_agent_approver` - Whether to include agent in approver list
    /// * `sequential_approval` - Whether approvals must be sequential
    /// * `additional_approvers` - Additional addresses to be added as approvers
    /// # Requirements
    /// * Only token owner can call this function
    /// * DVATransferManager must be an agent of the given token
    fn set_approval_criteria(
        ref self: TContractState,
        token_address: ContractAddress,
        include_recipient_approver: bool,
        include_agent_approver: bool,
        sequential_approval: bool,
        additional_approvers: Span<ContractAddress>,
    );

    /// Initiates a new transfer request
    /// * `token_address` - Address of the token to transfer
    /// * `recipient` - Address of the recipient
    /// * `amount` - Amount of tokens to transfer
    /// # Requirements
    /// * Approval criteria must be preset for the token address
    /// * Sender must give DVA an allowance of at least the specified amount
    /// * Receiver must be verified for the given token address
    fn initiate_transfer(
        ref self: TContractState,
        token_address: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
    );

    /// Approves a transfer
    /// * `transfer_id` - The unique ID of the transfer
    /// # Requirements
    /// * Caller must be an approver of the transfer
    fn approve_transfer(ref self: TContractState, transfer_id: felt252);

    /// Approves a transfer with delegated signatures
    /// * `transfer_id` - The unique ID of the transfer
    /// * `signatures` - Array of signatures from the approvers
    fn delegate_approve_transfer(
        ref self: TContractState, transfer_id: felt252, signatures: Span<Signature>,
    );

    /// Cancels a pending transfer
    /// * `transfer_id` - The unique ID of the transfer
    /// # Requirements
    /// * Caller must be the sender of the transfer
    fn cancel_transfer(ref self: TContractState, transfer_id: felt252);

    /// Rejects a pending transfer
    /// * `transfer_id` - The unique ID of the transfer
    /// # Requirements
    /// * Caller must be an approver of the transfer
    fn reject_transfer(ref self: TContractState, transfer_id: felt252);

    /// Gets the approval criteria for a specific token
    /// * `token_address` - The address of the token
    /// # Returns
    /// * The approval criteria for the token
    fn get_approval_criteria(
        self: @TContractState, token_address: ContractAddress,
    ) -> ApprovalCriteria;

    /// Gets the details of a specific transfer
    /// * `transfer_id` - The unique ID of the transfer
    /// # Returns
    /// * The transfer details
    fn get_transfer(self: @TContractState, transfer_id: felt252) -> Transfer;

    /// Gets the next approver for a pending transfer
    /// * `transfer_id` - The unique ID of the transfer
    /// # Returns
    /// * A tuple containing the next approver's address and whether they are an any-token agent
    fn get_next_approver(self: @TContractState, transfer_id: felt252) -> (ContractAddress, bool);

    /// Gets the next unique nonce value
    fn get_next_tx_nonce(self: @TContractState) -> u256;

    /// Gets the name of the manager
    fn name(self: @TContractState) -> ByteArray;

    /// Calculates an unique transfer ID
    /// * `nonce` - The unique nonce value
    /// * `sender` - The address of the sender
    /// * `recipient` - The address of the recipient
    /// * `amount` - The transfer amount
    /// # Returns
    /// * A unique transfer ID
    fn calculate_transfer_id(
        self: @TContractState,
        nonce: u256,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
    ) -> felt252;
}

impl ApproverZero of Zero<Approver> {
    fn zero() -> Approver {
        Approver { wallet: Zero::zero(), any_token_agent: false, approved: false }
    }
    #[inline]
    fn is_zero(self: @Approver) -> bool {
        self.wallet.is_zero() && !*self.any_token_agent && !*self.approved
    }
    #[inline]
    fn is_non_zero(self: @Approver) -> bool {
        !self.is_zero()
    }
}
