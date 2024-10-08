#[starknet::interface]
trait ICountryRestrictModule<TContractState> {
    fn add_country_restriction(ref self: TContractState, country: u16);
    fn remove_country_restriction(ref self: TContractState, country: u16);
    fn batch_restrict_countries(ref self: TContractState, countries: Array<u16>);
    fn batch_unrestrict_countries(ref self: TContractState, countries: Array<u16>);
    fn is_country_restricted(self: @TContractState, country: u16) -> bool;
}

#[starknet::contract]
mod CountryRestrictModule {
    use starknet::ContractAddress;
    use starknet::storage::{Map, //StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess
    };

    #[storage]
    struct Storage {
        restricted_countries: Map<(ContractAddress, u16), bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}
}
