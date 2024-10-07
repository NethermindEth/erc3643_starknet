//use registry::interface::iidentity_registry::{IIdentityRegistryDispatcher,
//IIdentityRegistryDispatcherTrait};
use compliance::modular::imodular_compliance::{
    IModularComplianceDispatcher, IModularComplianceDispatcherTrait
};
use starknet::ContractAddress;

#[event]
#[derive(Drop, starknet::Event)]
pub enum Event {
    UpdatedTokenInformation: UpdatedTokenInformation,
    IdentityRegistryAdded: IdentityRegistryAdded,
    ComplianceAdded: ComplianceAdded,
    RecoverySuccess: RecoverySuccess,
    AddressFrozen: AddressFrozen,
    TokensFrozen: TokensFrozen,
    TokensUnfrozen: TokensUnfrozen,
    Paused: Paused,
    Unpaused: Unpaused
}

#[derive(Drop, starknet::Event)]
pub struct UpdatedTokenInformation {
    #[key]
    new_name: ByteArray,
    #[key]
    new_symbol: ByteArray,
    new_decimals: u8,
    new_version: ByteArray,
    #[key]
    new_onchain_id: ContractAddress
}

#[derive(Drop, starknet::Event)]
pub struct IdentityRegistryAdded {
    #[key]
    identity_registry: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct ComplianceAdded {
    #[key]
    compliance: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct RecoverySuccess {
    #[key]
    lost_wallet: ContractAddress,
    #[key]
    new_wallet: ContractAddress,
    #[key]
    investor_onchain_id: ContractAddress
}

#[derive(Drop, starknet::Event)]
pub struct AddressFrozen {
    #[key]
    user_address: ContractAddress,
    #[key]
    is_frozen: bool,
    #[key]
    owner: ContractAddress
}

#[derive(Drop, starknet::Event)]
pub struct TokensFrozen {
    #[key]
    user_address: ContractAddress,
    amount: u256
}

#[derive(Drop, starknet::Event)]
pub struct TokensUnfrozen {
    #[key]
    user_address: ContractAddress,
    amount: u256
}

#[derive(Drop, starknet::Event)]
pub struct Paused {
    user_address: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct Unpaused {
    user_address: ContractAddress,
}


#[starknet::interface]
pub trait IToken<TContractState> {
    fn set_name(ref self: TContractState, name: ByteArray);
    fn set_symbol(ref self: TContractState, symbol: ByteArray);
    fn set_onchain_id(ref self: TContractState, onchain_id: ContractAddress);
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn set_addreess_frozen(ref self: TContractState, user_address: ContractAddress, freeze: bool);
    fn freeze_partial_tokens(ref self: TContractState, user_address: ContractAddress, amount: u256);
    fn unfreeze_partial_tokens(
        ref self: TContractState, user_address: ContractAddress, amount: u256
    );
    fn set_identity_registry(ref self: TContractState, identity_registry: ContractAddress);
    fn set_compliance(ref self: TContractState, compliance: ContractAddress);
    fn forced_transfer(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256
    ) -> bool;
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256);
    fn burn(ref self: TContractState, user_address: ContractAddress, amount: u256);
    fn recovery_address(
        ref self: TContractState,
        lost_wallet: ContractAddress,
        new_wallet: ContractAddress,
        investor_onchain_id: ContractAddress
    ) -> bool;
    fn batch_transfer(
        ref self: TContractState,
        from_list: Array<ContractAddress>,
        to_list: Array<ContractAddress>,
        amounts: Array<u256>
    );
    fn batch_mint(ref self: TContractState, to_list: Array<ContractAddress>, amounts: Array<u256>);
    fn batch_burn(
        ref self: TContractState, user_addresses: Array<ContractAddress>, amounts: Array<u256>
    );
    fn batch_set_address_frozen(
        ref self: TContractState, user_addresses: Array<ContractAddress>, freeze: Array<bool>
    );
    fn batch_freeze_partial_tokens(
        ref self: TContractState, user_addresses: Array<ContractAddress>, amounts: Array<u256>
    );
    fn batch_unfreeze_partial_tokens(
        ref self: TContractState, user_addresses: Array<ContractAddress>, amounts: Array<u256>
    );
    fn decimals(self: @TContractState) -> u8;
    fn name(self: @TContractState) -> ByteArray;
    fn symbol(self: @TContractState) -> ByteArray;
    fn onchain_id(self: @TContractState) -> ContractAddress;
    fn version(self: @TContractState) -> ByteArray;
    fn identity_registry(
        self: @TContractState
    ) -> ContractAddress; //TODO: IIdentityRegistryDispatcher;
    fn compliance(
        self: @TContractState
    ) -> IModularComplianceDispatcher; // TODO: IModularCompliance
    fn paused(self: @TContractState) -> bool;
    fn is_frozen(self: @TContractState, user_address: ContractAddress) -> bool;
    fn get_frozen_tokens(self: @TContractState, user_address: ContractAddress) -> u256;
}

