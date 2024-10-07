use starknet::ContractAddress;

#[starknet::interface]
pub trait IIdentityRegistryStorage<TContractState> {
    fn add_identity_to_storage(ref self: TContractState, //identity: IIdentity,
     country: u16);

    fn remove_identity_from_storage(ref self: TContractState, user_address: ContractAddress);
    fn modify_stored_investor_country(
        ref self: TContractState, user_address: ContractAddress, country: u16
    );
    fn modify_stored_identity(
        ref self: TContractState, user_address: ContractAddress, //identity: IIdentity
    );
    fn bind_identity_registry(ref self: TContractState, identity_registry: ContractAddress);
    fn unbind_identity_registry(ref self: TContractState, identity_registry: ContractAddress);
    fn linked_identity_registry(self: @TContractState) -> Array<ContractAddress>;
    fn stored_identity(self: @TContractState, user_address: ContractAddress); //-> IIdentity;
    fn stored_investor_country(self: @TContractState, user_address: ContractAddress) -> u16;
}
