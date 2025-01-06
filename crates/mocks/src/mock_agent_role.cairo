#[starknet::contract]
mod MockAgentRole {
    use openzeppelin_access::ownable::OwnableComponent;
    use roles::agent_role::AgentRoleComponent;
    use starknet::ContractAddress;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    component!(path: AgentRoleComponent, storage: agent_role, event: AgentRoleEvent);

    #[abi(embed_v0)]
    impl AgentRoleImpl = AgentRoleComponent::AgentRoleImpl<ContractState>;
    impl AgentRoleInternalImpl = AgentRoleComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        agent_role: AgentRoleComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        AgentRoleEvent: AgentRoleComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }
}
