#[starknet::contract]
mod IdentityRegistry {
    use registry::interface::iidentity_registry::IIdentityRegistry;

    #[storage]
    struct Storage {}
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}
}
