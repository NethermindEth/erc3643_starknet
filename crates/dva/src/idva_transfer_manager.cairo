use starknet::ContractAddress;

#[derive(Serde, Drop)]
enum TransferStatus {
    PENDING,
    COMPLETED,
    CANCELLED,
    REJECTED
}

#[derive(Serde, Drop)]
struct ApprovalCriteria {
    include_recipient_approver: bool,
    include_agent_approver: bool,
    sequantial_approval: bool,
    additional_approvers: Array<ContractAddress>,
    hash: felt252
}

#[derive(Serde, Drop)]
struct Transfer {
    token_address: ContractAddress,
    sender: ContractAddress,
    recipient: ContractAddress,
    amount: u256,
    status: TransferStatus,
    approvers: Array<Approver>,
    approval_criteria_hash: felt252
}

#[derive(Serde, Drop)]
struct Approver {
    wallet: ContractAddress,
    any_token_agent: bool,
    approve: bool
}

#[derive(Serde, Drop)]
struct Signature {
    v: u8,
    r: u256,
    s: u256
}

#[starknet::interface]
pub trait IDVATransferManager<TContractState> {
    fn set_approval_criteria(
        ref self: TContractState,
        token_address: ContractAddress,
        include_recipient_approver: bool,
        include_agent_approver: bool,
        sequantial_approval: bool,
        additional_approvers: Array<ContractAddress>
    );
    fn initiate_transfer(
        ref self: TContractState,
        token_address: ContractAddress,
        recipient: ContractAddress,
        amount: u256
    );
    fn approve_transfer(ref self: TContractState, transfer_id: felt252);
    fn delegate_approve_transfer(
        ref self: TContractState, transfer_id: felt252, signatures: Array<Signature>
    );
    fn cancel_transfer(ref self: TContractState, transfer_id: felt252);
    fn reject_transfer(ref self: TContractState, transfer_id: felt252);
    fn get_approval_criteria(
        self: @TContractState, token_address: ContractAddress
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
        amount: u256
    ) -> felt252;
}
