use starknet::ContractAddress;

#[starknet::interface]
trait IExchangeMonthlyLimitsModule<TContractState> {
    fn set_exchange_monthly_limit(
        ref self: TContractState, exchange_id: ContractAddress, new_exchange_monthly_limit: u256
    );
    fn get_exchange_monthly_limit(
        self: @TContractState,
        compliance: ContractAddress,
        exchange_id: ContractAddress,
        investor_id: ContractAddress
    ) -> u256;
    fn add_exchange_id(ref self: TContractState, exchange_id: ContractAddress);
    fn remove_exchange_id(ref self: TContractState, exchange_id: ContractAddress);
    fn is_exchange_id(ref self: TContractState, exchange_id: ContractAddress) -> bool;
    fn get_monthly_counter(
        self: @TContractState,
        compliance: ContractAddress,
        exchange_id: ContractAddress,
        investor_id: ContractAddress
    ) -> u256;
    fn get_monthly_timer(
        self: @TContractState,
        compliance: ContractAddress,
        exchange_id: ContractAddress,
        investor_id: ContractAddress
    ) -> u256;
}


#[starknet::contract]
mod ExchangeMonthlyLimitsModule {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {}
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}
}
