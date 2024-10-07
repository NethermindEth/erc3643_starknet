use starknet::ContractAddress;

#[starknet::interface]
trait ICountryRestriction<TContractState> {
    fn batch_restrict_countries(ref self: TContractState, countries: Array<u16>);
    fn batch_unrestrict_countries(ref self: TContractState, countries: Array<u16>);
    fn add_country_restriction(ref self: TContractState, countries: u16);
    fn remove_country_restriction(ref self: TContractState, country: u16);
    fn is_country_restricted(self: @TContractState, country: u16) -> bool;
    fn compliance_check_on_country_restrictions(
        self: @TContractState, from: ContractAddress, to: ContractAddress, value: u256
    ) -> bool;
}

#[starknet::component]
mod CountryRestrictionComponent {
    // use path::to::BasicCompliance;
    use starknet::storage::{Map, StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    struct Storage {
        restricted_countries: Map<u16, bool>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}
}
