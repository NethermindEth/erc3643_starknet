use starknet::ContractAddress;

#[starknet::interface]
pub trait IAgentRole<TContractState> {
    fn add_agent(ref self: TContractState, agent: ContractAddress);
    fn remove_agent(ref self: TContractState, agent: ContractAddress);
    fn is_agent(self: @TContractState, agent: ContractAddress) -> bool;
}

#[starknet::component]
pub mod AgentRoleComponent {
    use starknet::ContractAddress;
    use starknet::storage::{Map, //StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess
    };

    #[storage]
    struct Storage {
        agents: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        AgentAdded: AgentAdded,
        AgentRemoved: AgentRemoved
    }

    #[derive(Drop, starknet::Event)]
    struct AgentAdded {
        #[key]
        agent: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct AgentRemoved {
        #[key]
        agent: ContractAddress,
    }
}
