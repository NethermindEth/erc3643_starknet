#[starknet::component]
mod BasicComplianceComponent {
    use compliance::legacy::icompliance::ICompliance;
    // use token::itoken::ITokenDipatcher;
    use starknet::ContractAddress;
    use starknet::storage::{Map, StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    struct Storage {
        BasicCompliance_token_agents_list: Map<ContractAddress, bool>,
        BasicCompliance_token_bound: ContractAddress, // IToken
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}
}
