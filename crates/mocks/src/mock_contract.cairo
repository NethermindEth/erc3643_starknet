#[starknet::contract]
mod MockContract {
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        investor_country: u16,
    }

    #[external(v0)]
    fn set_investor_country(ref self: ContractState, country: u16) {
        self.investor_country.write(country);
    }

    #[external(v0)]
    fn investor_country(self: @ContractState, investor: ContractAddress) -> u16 {
        self.investor_country.read()
    }

    #[external(v0)]
    fn identity_registry(self: @ContractState) -> ContractAddress {
        starknet::get_contract_address()
    }
}
