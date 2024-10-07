use starknet::ContractAddress;

#[starknet::interface]
trait ISupplyLimit<TContractState> {
    fn set_supply_limit(ref self: TContractState, limit: u256);
    fn compliance_check_on_supply_limit(self: @TContractState, from: ContractAddress, to: ContractAddress, amount: u256) -> bool;
}


#[starknet::component]
mod SupplyLimitComponent {
    #[storage]
    struct Storage {
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
    }

}
