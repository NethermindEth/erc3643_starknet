pub mod compliance {
    pub mod imodular_compliance;
    pub mod modular_compliance;
    pub mod modules {
        pub mod abstract_module;
        pub mod conditional_transfer_module;
        pub mod country_allow_module;
        pub mod country_restrict_module;
        pub mod exchange_monthly_limits_module;
        pub mod imodule;
        pub mod max_balance_module;
        pub mod supply_limit_module;
        pub mod time_exchange_limits_module;
        pub mod time_transfer_limits_module;
        pub mod token_listing_restrictions_module;
        pub mod transfer_fees_module;
        pub mod transfer_restrict_module;
    }
    #[cfg(test)]
    mod tests;
}

pub mod dva {
    pub mod dva_transfer_manager;
    pub mod idva_transfer_manager;
    #[cfg(test)]
    mod tests;
}

pub mod dvd {
    pub mod dvd_transfer_manager;
    pub mod idvd_transfer_manager;
}

pub mod factory {
    pub mod iimplementation_authority;
    //pub mod implementation_authority;
    pub mod itrex_factory;
    pub mod itrex_gateway;
    #[cfg(test)]
    mod tests;
    pub mod trex_factory;
    pub mod trex_gateway;
}

pub mod registry {
    pub mod claim_topics_registry;
    pub mod identity_registry;
    pub mod identity_registry_storage;
    pub mod trusted_issuers_registry;
    pub mod interface {
        pub mod iclaim_topics_registry;
        pub mod iidentity_registry;
        pub mod iidentity_registry_storage;
        pub mod itrusted_issuers_registry;
    }
    #[cfg(test)]
    mod tests;
}

pub mod roles {
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
    #[cfg(test)]
    mod tests;
}

pub mod token {
    mod token;
    pub use token::Token;
    pub mod itoken;
    #[cfg(test)]
    mod tests;
}
