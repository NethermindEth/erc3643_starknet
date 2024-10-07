use starknet::ContractAddress;

#[starknet::interface]
trait ITransferFeesModule<TContractState> {
    fn set_fee(ref self: TContractState, rate: u256, collector: ContractAddress);
    fn get_fee(self: @TContractState, compliance: ContractAddress) -> Fee;
}

#[derive(Drop, Serde, starknet::Store)]
struct Fee {
    rate: u256,
    collector: ContractAddress
}

#[starknet::contract]
mod TransferFeesModule {
    use starknet::ContractAddress;
    use starknet::storage::{Map, StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess};
    use super::{Fee};

    #[storage]
    struct Storage {
        fees: Map<ContractAddress, Fee>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        FeeUpdated: FeeUpdated
    }

    #[derive(Drop, starknet::Event)]
    struct FeeUpdated {
        #[key]
        compliance: ContractAddress,
        rate: u256,
        collector: ContractAddress
    }
}
