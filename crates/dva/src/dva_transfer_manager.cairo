#[starknet::contract]
pub mod DVATransferManager {
    use dva::idva_transfer_manager::{IDVATransferManager};
    use roles::agent_role::AgentRoleComponent;

    #[storage]
    struct Storage {}
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}
}
