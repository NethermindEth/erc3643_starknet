// Might not be needing this

#[starknet::component]
mod AgentRoles {
    use openzeppelin_access::ownable::ownable::{OwnableComponent};
    use roles::permissioning::agent::agent_roles::IAgentRoles;
    use roles::roles::RolesComponent;
    use starknet::ContractAddress;
    use starknet::storage::{Map, StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    struct Storage {
        supply_modifiers: Map<ContractAddress, bool>,
        freezers: Map<ContractAddress, bool>,
        transfer_managers: Map<ContractAddress, bool>,
        recovery_agents: Map<ContractAddress, bool>,
        compliance_agents: Map<ContractAddress, bool>,
        white_list_managers: Map<ContractAddress, bool>,
        agent_admin: Map<ContractAddress, bool>,
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        RoleAdded: RoleAdded,
        RoleRemoved: RoleRemoved
    }

    #[derive(Drop, starknet::Event)]
    struct RoleAdded {
        #[key]
        agent: ContractAddress,
        role: ByteArray
    }

    #[derive(Drop, starknet::Event)]
    struct RoleRemoved {
        #[key]
        agent: ContractAddress,
        role: ByteArray
    }
}
