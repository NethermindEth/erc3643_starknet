use registry::interface::{
    iclaim_topics_registry::IClaimTopicsRegistryDispatcher,
    iidentity_registry_storage::IIdentityRegistryStorageDispatcher,
    itrusted_issuers_registry::ITrustedIssuersRegistryDispatcher,
};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IIdentityRegistry<TContractState> {
    fn register_identity(
        ref self: TContractState,
        user_address: ContractAddress,
        identity: ContractAddress,
        country: u16,
    );
    fn delete_identity(ref self: TContractState, user_address: ContractAddress);
    fn set_identity_registry_storage(
        ref self: TContractState, identity_registry_storage: ContractAddress,
    );
    fn set_claim_topics_registry(ref self: TContractState, claim_topics_registry: ContractAddress);
    fn set_trusted_issuers_registry(
        ref self: TContractState, trusted_issuers_registry: ContractAddress,
    );
    fn update_country(ref self: TContractState, user_address: ContractAddress, country: u16);
    fn update_identity(
        ref self: TContractState, user_address: ContractAddress, identity: ContractAddress,
    );
    fn batch_register_identity(
        ref self: TContractState,
        user_addresses: Array<ContractAddress>,
        identities: Array<ContractAddress>,
        contries: Array<u16>,
    );
    fn contains(self: @TContractState, user_address: ContractAddress) -> bool;
    fn is_verified(self: @TContractState, user_address: ContractAddress) -> bool;
    fn identity(self: @TContractState, user_address: ContractAddress) -> ContractAddress;
    fn investor_country(self: @TContractState, user_address: ContractAddress) -> u16;
    fn identity_storage(self: @TContractState) -> IIdentityRegistryStorageDispatcher;
    fn issuers_registry(self: @TContractState) -> ITrustedIssuersRegistryDispatcher;
    fn topics_registry(self: @TContractState) -> IClaimTopicsRegistryDispatcher;
}

#[event]
#[derive(Drop, starknet::Event)]
pub enum IdentityEvent {
    ClaimTopicsRegistrySet: ClaimTopicsRegistrySet,
    IdentityStorageSet: IdentityStorageSet,
    TrustedIssuersRegistrySet: TrustedIssuersRegistrySet,
    IdentityRegistered: IdentityRegistered,
    IdentityRemoved: IdentityRemoved,
    IdentityUpdated: IdentityUpdated,
    CountryUpdated: CountryUpdated,
}

#[derive(Drop, starknet::Event)]
pub struct ClaimTopicsRegistrySet {
    #[key]
    claim_topics_registry: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct IdentityStorageSet {
    #[key]
    identity_storage: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct TrustedIssuersRegistrySet {
    #[key]
    trusted_issuers_registry: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct IdentityRegistered {
    #[key]
    investor_address: ContractAddress,
    #[key]
    identity: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct IdentityRemoved {
    #[key]
    investor_address: ContractAddress,
    #[key]
    identity: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct IdentityUpdated {
    #[key]
    old_identity: ContractAddress,
    #[key]
    new_identity: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct CountryUpdated {
    #[key]
    investor_address: ContractAddress,
    #[key]
    country: u16,
}
