use starknet::ContractAddress;

#[starknet::interface]
trait IDayMonthLimits<TContractState> {
    fn set_daily_limit(ref self: TContractState, new_daily_limit: u256);
    fn set_monthly_limit(ref self: TContractState, new_monthly_limit: u256);
    fn compliance_check_on_day_month_limits(
        self: @TContractState, from: ContractAddress, to: ContractAddress, amount: u256
    ) -> bool;
}

#[starknet::component]
mod DayMonthLimitsComponent {
    // use path::to::BasicCompliance;
    use starknet::ContractAddress;
    use starknet::storage::{Map, StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess};

    #[starknet::storage_node]
    struct TransferCounter {
        daily_count: u256,
        monthly_count: u256,
        daily_timer: u256,
        monthly_timer: u256
    }

    #[storage]
    struct Storage {
        DayMonthLimits_daily_limit: u256,
        DayMonthLimits_monthly_limit: u256,
        DayMonthLimits_user_counters: Map<ContractAddress, TransferCounter>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}
}
