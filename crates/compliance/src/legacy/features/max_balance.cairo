use starknet::ContractAddress;

#[starknet::interface]
trait IMaxBalanceComponent<TContractState> {
    fn set_max_balance(ref self: TContractState, max: u256);
    fn compliance_check_on_max_balance(self: @TContractState, from: ContractAddress, to: ContractAddress, amount: u256);
}

#[starknet::component]
mod MaxBalanceComponent {
    #[storage]
    struct Storage {
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
    }

}
