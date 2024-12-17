use starknet::ContractAddress;

#[starknet::interface]
pub trait IAgentRole<TState> {
    fn add_agent(ref self: TState, agent: ContractAddress);
    fn remove_agent(ref self: TState, agent: ContractAddress);
    fn is_agent(self: @TState, agent: ContractAddress) -> bool;
}

#[starknet::component]
pub mod AgentRoleComponent {
    use core::num::traits::Zero;
    use openzeppelin_access::ownable::{
        OwnableComponent, OwnableComponent::InternalTrait as OwnableInternalTrait,
    };
    use starknet::{
        ContractAddress,
        storage::{Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess},
    };

    #[storage]
    pub struct Storage {
        AgentRole_agents: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AgentAdded: AgentAdded,
        AgentRemoved: AgentRemoved,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AgentAdded {
        pub agent: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AgentRemoved {
        pub agent: ContractAddress,
    }

    #[embeddable_as(AgentRoleImpl)]
    pub impl AgentRole<
        TContractState,
        +HasComponent<TContractState>,
        impl Ownable: OwnableComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of super::IAgentRole<ComponentState<TContractState>> {
        fn add_agent(ref self: ComponentState<TContractState>, agent: ContractAddress) {
            let ownable_comp = get_dep_component!(@self, Ownable);
            ownable_comp.assert_only_owner();
            self._add_agent(agent);
        }

        fn remove_agent(ref self: ComponentState<TContractState>, agent: ContractAddress) {
            let ownable_comp = get_dep_component!(@self, Ownable);
            ownable_comp.assert_only_owner();
            self._remove_agent(agent);
        }

        fn is_agent(self: @ComponentState<TContractState>, agent: ContractAddress) -> bool {
            self.AgentRole_agents.entry(agent).read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn assert_only_agent(self: @ComponentState<TContractState>) {
            assert(
                self.AgentRole_agents.entry(starknet::get_caller_address()).read(),
                'Caller does not have agent role',
            );
        }

        fn _add_agent(ref self: ComponentState<TContractState>, agent: ContractAddress) {
            assert(agent.is_non_zero(), 'Agent address zero!');
            self.AgentRole_agents.entry(agent).write(true);
        }

        fn _remove_agent(ref self: ComponentState<TContractState>, agent: ContractAddress) {
            assert(agent.is_non_zero(), 'Agent address zero!');
            self.AgentRole_agents.entry(agent).write(false);
        }
    }
}
