use starknet::ContractAddress;


#[starknet::interface]
trait ITimeTransferLimitsModule<TContractState> {
    fn set_time_transfer_limit(ref self: TContractState, limit: Limit);
    fn get_time_transfer_limits(self: @TContractState, compliance: ContractAddress) -> Array<Limit>;
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct TransferCounter {
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

#[starknet::contract]
mod TimeTransferLimitsModule {
    use starknet::ContractAddress;
    use starknet::storage::{
        Vec, VecTrait, MutableVecTrait, Map, StoragePathEntry, StorageMapReadAccess,
        StorageMapWriteAccess
    };
    use super::{TransferCounter, Limit, IndexLimit};

    #[storage]
    struct Storage {
        limit_values: Map<(ContractAddress, u32), IndexLimit>,
        transfer_limits: Map<ContractAddress, Vec<Limit>>,
        users_counter: Map<(ContractAddress, ContractAddress, u32), TransferCounter>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}
}
