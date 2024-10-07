#[starknet::contract]
mod IdentityRegistryStorage {
    #[storage]
    struct Storage {}
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}
}
