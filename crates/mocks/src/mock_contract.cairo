use starknet::ContractAddress;

#[starknet::interface]
pub trait IMockContract<TContractState> {
    fn set_investor_country(ref self: TContractState, country: u16);
    fn investor_country(self: @TContractState, investor: ContractAddress) -> u16;
    fn identity_registry(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
mod MockContract {
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        investor_country: u16,
    }

    #[abi(embed_v0)]
    impl MockContractImpl of super::IMockContract<ContractState> {
        fn set_investor_country(ref self: ContractState, country: u16) {
            self.investor_country.write(country);
        }

        fn investor_country(self: @ContractState, investor: ContractAddress) -> u16 {
            self.investor_country.read()
        }

        fn identity_registry(self: @ContractState) -> ContractAddress {
            starknet::get_contract_address()
        }
    }
}
