use starknet::ContractAddress;

#[starknet::interface]
trait ICountryWhitelisting<TContractState> {
    fn batch_whitelist_countries(ref self: TContractState, countries: Array<u16>);
    fn batch_unwhitelist_countries(ref self: TContractState, countries: Array<u16>);
    fn whitelist_country(ref self: TContractState, country: u16);
    fn unwhitelist_country(ref self: TContractState, country: u16);
    fn is_country_whitelisted(self: @TContractState, country: u16) -> bool;
    fn compliance_check_on_country_whitelisting(
        self: @TContractState, from: ContractAddress, to: ContractAddress, amount: u256
    ) -> bool;
}

#[starknet::component]
mod CountryWhitelistingComponent {
    // use path::to::BasicCompliance;
    use starknet::storage::{Map, //StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess
    };
    #[storage]
    struct Storage {
        CountryWhitelisting_whitelisted_countries: Map<u16, bool>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}
}
