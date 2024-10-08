pub mod modular {
    pub mod imodular_compliance;
    pub mod modular_compliance;
    pub mod modules {
        pub mod abstract_module;
        pub mod abstract_module_upgradeable;
        pub mod conditional_transfer_module;
        pub mod country_allow_module;
        pub mod country_restrict_module;
        pub mod exchange_monthly_limits_module;
        pub mod imodule;
        pub mod max_balance_module;
        pub mod module_proxy;
        pub mod supply_limit_module;
        pub mod time_exchange_limits_module;
        pub mod time_transfer_limits_module;
        pub mod transfer_fees_module;
        pub mod transfer_restrict_module;
    }
}

pub mod legacy {
    pub mod basic_compliance;
    pub mod default_compliance;
    pub mod icompliance;
    pub mod features {
        pub mod approve_transfer;
        pub mod country_restrictions;
        pub mod country_whitelisting;
        pub mod day_month_limits;
        pub mod exchange_monthly_limits;
        pub mod max_balance;
        pub mod supply_limit;
    }
}
