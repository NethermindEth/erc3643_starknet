#[starknet::component]
mod BasicComplianceComponent {
    use compliance::legacy::icompliance::ICompliance;
    // use token::itoken::ITokenDipatcher;
    
    #[storage]
    struct Storage {
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
    }

}
