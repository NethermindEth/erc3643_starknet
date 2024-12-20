use starknet::ContractAddress;

#[derive(Serde, Drop)]
pub enum TransferStatus {
    PENDING,
    COMPLETED,
    CANCELLED,
    REJECTED,
}

#[derive(Serde, Drop)]
pub struct ApprovalCriteria {
    include_recipient_approver: bool,
    include_agent_approver: bool,
    sequential_approval: bool,
    additional_approvers: Array<ContractAddress>,
    hash: felt252,
}

#[derive(Serde, Drop)]
pub struct Transfer {
    token_address: ContractAddress,
    sender: ContractAddress,
    recipient: ContractAddress,
    amount: u256,
    status: TransferStatus,
    approvers: Array<Approver>,
    approval_criteria_hash: felt252,
}

#[derive(Serde, Drop)]
pub struct Approver {
    wallet: ContractAddress,
    any_token_agent: bool,
    approved: bool,
}

#[derive(Serde, Drop)]
pub struct Signature {
    v: u8,
    r: felt252,
    s: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct ApprovalCriteriaSet {
    #[key]
    token_address: ContractAddress,
    include_recipient_approver: bool,
    include_agent_approver: bool,
    sequential_approval: bool,
    additional_approvers: Span<ContractAddress>,
    hash: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct TransferInitiated {
    #[key]
    transfer_id: felt252,
    token_address: ContractAddress,
    sender: ContractAddress,
    recipient: ContractAddress,
    amount: u256,
    approval_criteria_hash: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct TransferApproved {
    #[key]
    transfer_id: felt252,
    approver: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct TransferRejected {
    #[key]
    transfer_id: felt252,
    rejected_by: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct TransferCancelled {
    #[key]
    transfer_id: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct TransferCompleted {
    #[key]
    transfer_id: felt252,
    token_address: ContractAddress,
    sender: ContractAddress,
    recipient: ContractAddress,
    amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct TransferApprovalReset {
    #[key]
    transfer_id: felt252,
    approval_criteria_hash: felt252,
}

pub mod Errors {
    use starknet::ContractAddress;

    pub fn OnlyTokenAgentCanCall(token_address: ContractAddress) {// panic!("{:?}", );
    }
    pub fn OnlyTransferSenderCanCall(transfer_id: felt252) {// panic!("{:?}", );
    }
    pub fn TokenIsNotRegistered(token_address: ContractAddress) {// panic!("{:?}", );
    }
    pub fn RecipientIsNotVerified(token_address: ContractAddress, recipient: ContractAddress) {// panic!("{:?}", );
    }
    pub fn DVAManagerIsNotVerifiedForTheToken(token_address: ContractAddress) {// panic!("{:?}", );
    }
    pub fn InvalidTransferID(transfer_id: felt252) {// panic!("{:?}", );
    }
    pub fn TransferIsNotInPendingStatus(transfer_id: felt252) {// panic!("{:?}", );
    }
    pub fn ApprovalsMustBeSequential(transfer_id: felt252) {// panic!("{:?}", );
    }
    pub fn ApproverNotFound(transfer_id: felt252, approver: ContractAddress) {// panic!("{:?}", );
    }
    pub fn SignaturesCanNotBeEmpty(transfer_id: felt252) {// panic!("{:?}", );
    }
}

#[starknet::interface]
pub trait IDVATransferManager<TContractState> {
    fn set_approval_criteria(
        ref self: TContractState,
        token_address: ContractAddress,
        include_recipient_approver: bool,
        include_agent_approver: bool,
        sequential_approval: bool,
        additional_approvers: Array<ContractAddress>,
    );
    fn initiate_transfer(
        ref self: TContractState,
        token_address: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
    );
    fn approve_transfer(ref self: TContractState, transfer_id: felt252);
    fn delegate_approve_transfer(
        ref self: TContractState, transfer_id: felt252, signatures: Span<Signature>,
    );
    fn cancel_transfer(ref self: TContractState, transfer_id: felt252);
    fn reject_transfer(ref self: TContractState, transfer_id: felt252);
    fn get_approval_criteria(
        self: @TContractState, token_address: ContractAddress,
    ) -> ApprovalCriteria;
    fn get_transfer(self: @TContractState, transfer_id: felt252) -> Transfer;
    fn get_next_approver(self: @TContractState, transfer_id: felt252) -> (ContractAddress, bool);
    fn get_next_tx_nonce(self: @TContractState) -> u256;
    fn name(self: @TContractState) -> ByteArray;
    fn calculate_transfer_id(
        self: @TContractState,
        nonce: u256,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
    ) -> felt252;
}
