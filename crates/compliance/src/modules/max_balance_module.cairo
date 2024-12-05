use starknet::ContractAddress;

#[starknet::interface]
trait IMaxBalanceModule<TContractState> {
    fn set_max_balance(ref self: TContractState, max: u256);
    fn preset_module_state(
        ref self: TContractState, compliance: ContractAddress, id: ContractAddress, balance: u256,
    );
    fn batch_preset_module_state(
        ref self: TContractState,
        compliance: ContractAddress,
        id: Array<ContractAddress>,
        balance: Array<u256>,
    );
    fn preset_completed(ref self: TContractState, compliance: ContractAddress);
    fn get_id_balance(
        self: @TContractState, compliance: ContractAddress, identity: ContractAddress,
    ) -> u256;
}


#[starknet::contract]
mod MaxBalanceModule {
    use starknet::ContractAddress;
    use starknet::storage::{Map //StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess
    };

    #[storage]
    struct Storage {
        compliance_preset_status: Map<ContractAddress, bool>,
        max_balance: Map<ContractAddress, u256>,
        id_balance: Map<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}
}
