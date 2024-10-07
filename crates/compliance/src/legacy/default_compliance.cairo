#[starknet::contract]
mod DefaultCompliance {
    #[storage]
    struct Storage {
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
    }

}
