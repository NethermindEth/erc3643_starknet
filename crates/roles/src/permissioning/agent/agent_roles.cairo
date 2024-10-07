// Can we use RoleBased auth instead?
// like this
// https://github.com/OpenZeppelin/cairo-contracts/blob/main/packages/access/src/accesscontrol/accesscontrol.cairo
use starknet::ContractAddress;

pub trait IAgentRoles<TContractState> {
    fn add_agent_admin(ref self: TContractState, agent: ContractAddress);
    fn remove_agent_admin(ref self: TContractState, agent: ContractAddress);
    fn add_suply_modifier(ref self: TContractState, agent: ContractAddress);
    fn remove_suply_modifier(ref self: TContractState, agent: ContractAddress);
    fn add_freezer(ref self: TContractState, agent: ContractAddress);
    fn remove_freezer(ref self: TContractState, agent: ContractAddress);
    fn add_transfer_manager(ref self: TContractState, agent: ContractAddress);
    fn remove_transfer_manager(ref self: TContractState, agent: ContractAddress);
    fn add_recovery_agent(ref self: TContractState, agent: ContractAddress);
    fn remove_recovery_agent(ref self: TContractState, agent: ContractAddress);
    fn add_compliance_agent(ref self: TContractState, agent: ContractAddress);
    fn remove_compliance_agent(ref self: TContractState, agent: ContractAddress);
    fn add_whitelist_manager(ref self: TContractState, agent: ContractAddress);
    fn remove_whitelist_manager(ref self: TContractState, agent: ContractAddress);
    fn is_agent_admin(self: @TContractState, agent: ContractAddress) -> bool;
    fn is_whitelist_manager(self: @TContractState, agent: ContractAddress) -> bool;
    fn is_compliance_agent(self: @TContractState, agent: ContractAddress) -> bool;
    fn is_recovery_agent(self: @TContractState, agent: ContractAddress) -> bool;
    fn is_transfer_manager(self: @TContractState, agent: ContractAddress) -> bool;
    fn is_freezer(self: @TContractState, agent: ContractAddress) -> bool;
    fn is_supply_modifier(self: @TContractState, agent: ContractAddress) -> bool;
}

#[starknet::component]
mod AgentRoles {
    use openzeppelin_access::ownable::ownable::{OwnableComponent};
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
