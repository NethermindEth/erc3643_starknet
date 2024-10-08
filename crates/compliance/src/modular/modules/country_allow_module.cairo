use starknet::ContractAddress;

#[starknet::interface]
trait ICountryAllowModule<TContractState> {
    fn batch_allow_countries(ref self: TContractState, countries: Array<u16>);
    fn batch_disallow_countries(ref self: TContractState, countries: Array<u16>);
    fn add_allowed_country(ref self: TContractState, country: u16);
    fn remove_allowed_country(ref self: TContractState, country: u16);
    fn is_country_allowed(self: @TContractState, compliance: ContractAddress, country: u16) -> bool;
    fn compliance_check_on_country_whitelisting(
        self: @TContractState, from: ContractAddress, to: ContractAddress, amount: u256
    ) -> bool;
}

#[starknet::contract]
mod CountryAllowedModule {
    use starknet::ContractAddress;
    use starknet::storage::{Map, //StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess
    };

    #[storage]
    struct Storage {
        allowed_countries: Map<(ContractAddress, u16), bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}
}
