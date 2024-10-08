use starknet::ContractAddress;

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct ExchangeTransferCounter {
    value: u256,
    timer: u256
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct Limit {
    limit_time: u256,
    limit_value: u256
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct IndexLimit {
    attributed_limit: bool,
    limit_index: u8
}

#[starknet::interface]
pub trait ITimeExchangeLimitsModule<TContractState> {
    fn set_exchange_limit(ref self: TContractState, exchange_id: ContractAddress, limit: Limit);
    fn add_exchange_id(ref self: TContractState, exchange_id: ContractAddress);
    fn remove_exchange_id(ref self: TContractState, exchange_id: ContractAddress);
    fn get_exchange_counter(
        self: @TContractState,
        compliance: ContractAddress,
        exchange_id: ContractAddress,
        investor_id: ContractAddress,
        limit_time: u32
    ) -> ExchangeTransferCounter;
    fn get_exchange_limits(
        self: @TContractState, compliance: ContractAddress, exchange_id: ContractAddress
    ) -> Array<Limit>;
    fn is_exchange_id(self: @TContractState, exchange_id: ContractAddress) -> bool;
}

#[starknet::contract]
pub mod TimeExchangeLimitsModule {
    use starknet::ContractAddress;
    use starknet::storage::{
        Vec, //VecTrait, MutableVecTrait,
         Map, //StoragePathEntry, StorageMapReadAccess,
        //StorageMapWriteAccess
    };
    use super::{IndexLimit, Limit, ExchangeTransferCounter};
    #[storage]
    struct Storage {
        limit_value: Map<(ContractAddress, ContractAddress, u32), IndexLimit>,
        exchange_limits: Map<(ContractAddress, ContractAddress), Vec<Limit>>,
        exchange_counters: Map<
            (ContractAddress, ContractAddress, ContractAddress, u32), ExchangeTransferCounter
        >,
        exchange_ids: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ExchangeLimitUpdated: ExchangeLimitUpdated,
        ExchangeIDAdded: ExchangeIDAdded,
        ExchangeIDRemoved: ExchangeIDRemoved,
    }

    #[derive(Drop, starknet::Event)]
    struct ExchangeLimitUpdated {
        #[key]
        compliance: ContractAddress,
        exchange_id: ContractAddress,
        limit_value: u256,
        limit_time: u32
    }

    #[derive(Drop, starknet::Event)]
    struct ExchangeIDAdded {
        new_exchange_id: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct ExchangeIDRemoved {
        exchange_id: ContractAddress,
    }
}
