use starknet::ContractAddress;

#[starknet::interface]
trait IExchangeMonthlyLimits<TContractState> {
    fn set_exchange_monthly_limit(
        ref self: TContractState, exchange_id: ContractAddress, new_exchange_monthly_limit: u256
    );
    fn add_exchange_id(ref self: TContractState, exchange_id: ContractAddress);
    fn remove_exchange_id(ref self: TContractState, exchange_id: ContractAddress);
    fn is_exchange_id(self: @TContractState, exchange_id: ContractAddress) -> bool;
    fn get_monthly_counter(
        self: @TContractState, exchange_id: ContractAddress, investor_id: ContractAddress
    ) -> u256;
    fn get_monthly_timer(
        self: @TContractState, exchange_id: ContractAddress, investor_id: ContractAddress
    ) -> u256;
    fn get_exhange_monthly_limit(self: @TContractState, exchange_id: ContractAddress) -> u256;
    fn compliance_check_on_exchange_monthly_limits(
        self: @TContractState, from: ContractAddress, to: ContractAddress, amount: u256
    ) -> bool;
}

#[starknet::component]
mod ExchangeMonthlyLimitsComponent {
    #[storage]
    struct Storage {}
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}
}
