pub mod agent_role;
pub mod agent {
    pub mod agent_manager;
    pub mod iagent_manager;
}
pub mod owner {
    pub mod iowner_manager;
    pub mod owner_manager;
}

pub mod AgentRoles {
    pub const AGENT_ADMIN: felt252 = 'AGENT_ADMIN_ROLE';
    pub const SUPPLY_MODIFIER: felt252 = 'SUPPLY_MODIFIER_ROLE';
    pub const FREEZER: felt252 = 'FREEZER_ROLE';
    pub const TRANSFER_MANAGER: felt252 = 'TRANSFER_MANAGER_ROLE';
    pub const RECOVERY_AGENT: felt252 = 'RECOVERY_AGENT_ROLE';
    pub const COMPLIANCE_AGENT: felt252 = 'COMPLIANCE_AGENT_ROLE';
    pub const WHITELIST_MANAGER: felt252 = 'WHITE_LIST_MANAGER_ROLE';
}

pub mod OwnerRoles {
    pub const OWNER_ADMIN: felt252 = 'OWNER_ADMIN_ROLE';
    pub const REGISTRY_ADDRESS_SETTER: felt252 = 'REGISTRY_ADDRESS_SETTER_ROLE';
    pub const COMPLIANCE_SETTER: felt252 = 'COMPLIANCE_SETTER_ROLE';
    pub const COMPLIANCE_MANAGER: felt252 = 'COMPLIANCE_MANAGER_ROLE';
    pub const CLAIM_REGISTRY_MANAGER: felt252 = 'CLAIM_REGISTRY_MANAGER_ROLE';
    pub const ISSUERS_REGISTRY_MANAGER: felt252 = 'ISSUERS_REGISTRY_MANAGER_ROLE';
    pub const TOKEN_INFO_MANAGER: felt252 = 'TOKEN_INFO_MANAGER_ROLE';
}
