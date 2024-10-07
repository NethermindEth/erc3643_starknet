use starknet::ContractAddress;

#[starknet::interface]
trait ITransferRestrictedModule<TContractState> {
    fn allow_user(ref self: TContractState, user_address: ContractAddress);
    fn batch_allow_users(ref self: TContractState, user_addresses: Array<ContractAddress>);
    fn disallow_user(ref self: TContractState, user_address: ContractAddress);
    fn batch_disallow_users(ref self: TContractState, user_addresses: Array<ContractAddress>);
    fn is_user_allowed(
        self: @TContractState, compliance: ContractAddress, user_address: ContractAddress
    ) -> bool;
}

#[starknet::contract]
mod TransferRestrictModule {
    use compliance::modular::modules::abstract_module_upgradeable;
    use starknet::ContractAddress;
    use starknet::storage::{Map, StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    struct Storage {
        allowed_user_addresses: Map<(ContractAddress, ContractAddress), bool>,
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}
}
