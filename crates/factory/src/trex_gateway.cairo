#[starknet::contract]
mod TREXGateway {
    use factory::itrex_gateway::{ //ITREXGateway,
    Fee};
    use starknet::ContractAddress;
    use starknet::storage::{Map, //StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess
    };

    #[storage]
    struct Storage {
        factory: ContractAddress,
        public_deployment_status: bool,
        deploymeny_fee: Fee,
        deployment_fee_enabled: bool,
        deployers: Map<ContractAddress, bool>,
        fee_discount: Map<ContractAddress, u16>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    #[constructor]
    fn constructor(ref self: ContractState) {}
}
