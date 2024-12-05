#[starknet::contract]
mod TREXFactory {
    //use factory::itrex_factory::{ITREXFactory, TokenDetails, ClaimDetails, TREXFactoryEvent};
    use starknet::ContractAddress;
    use starknet::storage::{Map //StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess
    };

    #[storage]
    struct Storage {
        implementation_authority: ContractAddress,
        id_factory: ContractAddress,
        token_deployed: Map<ByteArray, ContractAddress>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    #[constructor]
    fn constructor(
        ref self: ContractState,
        implementation_authority: ContractAddress,
        id_factory: ContractAddress,
    ) {}
}
