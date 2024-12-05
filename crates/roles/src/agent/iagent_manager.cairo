use starknet::ContractAddress;

#[starknet::interface]
pub trait IAgentManager<TContractState> {
    fn call_forced_transfer(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        amount: u256,
        onchain_id: ContractAddress,
    );
    fn call_batch_forced_transfer(
        ref self: TContractState,
        from_list: Span<ContractAddress>,
        to_list: Span<ContractAddress>,
        amounts: Span<u256>,
        onchain_id: ContractAddress,
    );
    fn call_pause(ref self: TContractState, onchain_id: ContractAddress);
    fn call_unpause(ref self: TContractState, onchain_id: ContractAddress);
    fn call_mint(
        ref self: TContractState, to: ContractAddress, amount: u256, onchain_id: ContractAddress,
    );
    fn call_batch_mint(
        ref self: TContractState,
        to_list: Span<ContractAddress>,
        amounts: Span<u256>,
        onchain_id: ContractAddress,
    );
    fn call_burn(
        ref self: TContractState,
        user_address: ContractAddress,
        amount: u256,
        onchain_id: ContractAddress,
    );
    fn call_batch_burn(
        ref self: TContractState,
        user_addresses: Span<ContractAddress>,
        amounts: Span<u256>,
        onchain_id: ContractAddress,
    );
    fn call_set_address_frozen(
        ref self: TContractState,
        user_address: ContractAddress,
        freeze: bool,
        onchain_id: ContractAddress,
    );
    fn call_batch_set_address_frozen(
        ref self: TContractState,
        user_addresses: Span<ContractAddress>,
        freeze: Span<bool>,
        onchain_id: ContractAddress,
    );
    fn call_freeze_partial_tokens(
        ref self: TContractState,
        user_address: ContractAddress,
        amount: u256,
        onchain_id: ContractAddress,
    );
    fn call_batch_freeze_partial_tokens(
        ref self: TContractState,
        user_addresses: Span<ContractAddress>,
        amounts: Span<u256>,
        onchain_id: ContractAddress,
    );
    fn call_unfreeze_partial_tokens(
        ref self: TContractState,
        user_address: ContractAddress,
        amount: u256,
        onchain_id: ContractAddress,
    );
    fn call_batch_unfreeze_partial_tokens(
        ref self: TContractState,
        user_addresses: Span<ContractAddress>,
        amounts: Span<u256>,
        onchain_id: ContractAddress,
    );
    fn call_recovery_address(
        ref self: TContractState,
        lost_wallet: ContractAddress,
        new_wallet: ContractAddress,
        onchain_id: ContractAddress,
        manager_onchain_id: ContractAddress,
    );
    fn call_register_identity(
        ref self: TContractState,
        user_address: ContractAddress,
        onchain_id: ContractAddress,
        country: u16,
        manager_onchain_id: ContractAddress,
    );
    fn call_update_identity(
        ref self: TContractState,
        user_address: ContractAddress,
        identity: ContractAddress,
        onchain_id: ContractAddress,
    );
    fn call_update_country(
        ref self: TContractState,
        user_address: ContractAddress,
        country: u16,
        onchain_id: ContractAddress,
    );
    fn call_delete_identity(
        ref self: TContractState, user_address: ContractAddress, onchain_id: ContractAddress,
    );
}
