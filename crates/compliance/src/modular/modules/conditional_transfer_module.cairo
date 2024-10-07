use starknet::ContractAddress;

#[starknet::interface]
pub trait IConditionalTransferModule<TContractState> {
    fn batch_approve_transfers(
        ref self: TContractState,
        from: Array<ContractAddress>,
        to: Array<ContractAddress>,
        amount: Array<u256>
    );
    fn batch_unapprove_transfers(
        ref self: TContractState,
        from: Array<ContractAddress>,
        to: Array<ContractAddress>,
        amount: Array<u256>
    );
    fn approve_transfer(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256
    );
    fn unapprove_transfer(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256
    );
    fn is_transfer_approved(
        self: @TContractState, compliance: ContractAddress, transfer_hash: felt252
    ) -> bool;
    fn get_transfer_approvals(
        self: @TContractState, compliance: ContractAddress, transfer_hash: felt252
    ) -> u256;
    fn calculate_transfer_hash(
        self: @TContractState,
        from: ContractAddress,
        to: ContractAddress,
        amount: u256,
        token: ContractAddress
    ) -> felt252;
}

#[starknet::contract]
pub mod ConditionalTransferModule {
    use compliance::modular::imodular_compliance::{
        IModularComplianceDispatcher, IModularComplianceDispatcherTrait
    };
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}
}
