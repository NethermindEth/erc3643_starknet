use starknet::ContractAddress;

#[starknet::interface]
trait IApproveTransfer<TContractState> {
    fn remove_approval(ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256);
    fn approval_and_transfer(ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256);
    fn approval_transfer(ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256);
    fn compliance_check_approve_transfer(self: @TContractState, from: ContractAddress, to: ContractAddress, amount: u256) -> bool;
}


#[starknet::component]
mod ApproveTransfer {
    // use path::to::BasicCompliance; 
    use starknet::storage::{
        Map, StoragePathEntry, StorageMapReadAccess,
        StorageMapWriteAccess
    };

    #[storage]
    struct Storage {
        transfer_approved: Map<felt252, bool>
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
    }

}
