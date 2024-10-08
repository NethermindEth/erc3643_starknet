use starknet::ContractAddress;

#[starknet::interface]
trait ISupplyLimitModule<TContractState> {
    fn set_supply_limit(ref self: TContractState, limit: u256);
    fn get_supply_limit(self: @TContractState, compliance: ContractAddress) -> u256;
}

#[starknet::contract]
mod SupplyLimitModule {
    use starknet::ContractAddress;
    use starknet::storage::{Map, //StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess
    };
    #[storage]
    struct Storage {
        supply_limits: Map<ContractAddress, u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SupplyLimitSet: SupplyLimitSet
    }

    #[derive(Drop, starknet::Event)]
    struct SupplyLimitSet {
        compliance: ContractAddress,
        limit: u256
    }
}
