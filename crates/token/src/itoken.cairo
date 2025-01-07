use compliance::imodular_compliance::IModularComplianceDispatcher;
use registry::interface::iidentity_registry::IIdentityRegistryDispatcher;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IToken<TContractState> {
    /// Setters for metadata
    fn set_name(ref self: TContractState, name: ByteArray);
    fn set_symbol(ref self: TContractState, symbol: ByteArray);
    fn set_onchain_id(ref self: TContractState, onchain_id: ContractAddress);
    /// Pausable expose
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn set_address_frozen(ref self: TContractState, user_address: ContractAddress, freeze: bool);
    fn freeze_partial_tokens(ref self: TContractState, user_address: ContractAddress, amount: u256);
    fn unfreeze_partial_tokens(
        ref self: TContractState, user_address: ContractAddress, amount: u256,
    );
    fn set_identity_registry(ref self: TContractState, identity_registry: ContractAddress);
    fn set_compliance(ref self: TContractState, compliance: ContractAddress);
    fn forced_transfer(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256,
    ) -> bool;
    /// ERC20 mintable burnable
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256);
    fn burn(ref self: TContractState, user_address: ContractAddress, amount: u256);
    fn recovery_address(
        ref self: TContractState,
        lost_wallet: ContractAddress,
        new_wallet: ContractAddress,
        investor_onchain_id: ContractAddress,
    ) -> bool;
    fn batch_transfer(
        ref self: TContractState,
        from_list: Span<ContractAddress>,
        to_list: Span<ContractAddress>,
        amounts: Span<u256>,
    );
    fn batch_forced_transfer(
        ref self: TContractState,
        from_list: Span<ContractAddress>,
        to_list: Span<ContractAddress>,
        amounts: Span<u256>,
    );
    fn batch_mint(ref self: TContractState, to_list: Span<ContractAddress>, amounts: Span<u256>);
    fn batch_burn(
        ref self: TContractState, user_addresses: Span<ContractAddress>, amounts: Span<u256>,
    );
    fn batch_set_address_frozen(
        ref self: TContractState, user_addresses: Span<ContractAddress>, freeze: Span<bool>,
    );
    fn batch_freeze_partial_tokens(
        ref self: TContractState, user_addresses: Span<ContractAddress>, amounts: Span<u256>,
    );
    fn batch_unfreeze_partial_tokens(
        ref self: TContractState, user_addresses: Span<ContractAddress>, amounts: Span<u256>,
    );
    fn onchain_id(self: @TContractState) -> ContractAddress;
    fn version(self: @TContractState) -> ByteArray;
    fn identity_registry(self: @TContractState) -> IIdentityRegistryDispatcher;
    fn compliance(self: @TContractState) -> IModularComplianceDispatcher;
    fn is_frozen(self: @TContractState, user_address: ContractAddress) -> bool;
    fn get_frozen_tokens(self: @TContractState, user_address: ContractAddress) -> u256;
}
