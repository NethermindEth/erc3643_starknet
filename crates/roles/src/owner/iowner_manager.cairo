use starknet::ContractAddress;

#[starknet::interface]
pub trait IOwnerManager<TContractState> {
    fn call_set_identity_registry(
        ref self: TContractState, identity_registry: ContractAddress, onchain_id: ContractAddress,
    );
    fn call_set_compliance(
        ref self: TContractState, compliance: ContractAddress, onchain_id: ContractAddress
    );
    fn call_compliance_function(
        ref self: TContractState,
        selector: felt252,
        calldata: Span<felt252>,
        onchain_id: ContractAddress
    );
    fn call_set_token_name(ref self: TContractState, name: ByteArray, onchain_id: ContractAddress);
    fn call_set_token_symbol(
        ref self: TContractState, symbol: ByteArray, onchain_id: ContractAddress
    );
    fn call_set_token_onchain_id(
        ref self: TContractState, token_onchain_id: ContractAddress, onchain_id: ContractAddress
    );
    fn call_set_claim_topics_registry(
        ref self: TContractState,
        claim_topics_registry: ContractAddress,
        onchain_id: ContractAddress
    );
    fn call_set_trusted_issuers_registry(
        ref self: TContractState,
        trusted_issuers_registry: ContractAddress,
        onchain_id: ContractAddress
    );
    fn call_add_trusted_issuer(
        ref self: TContractState,
        trusted_issuer: ContractAddress,
        claim_topics: Span<felt252>,
        onchain_id: ContractAddress
    );
    fn call_remove_trusted_issuer(
        ref self: TContractState,
        trusted_issuer: ContractAddress,
        claim_topics: Span<felt252>,
        onchain_id: ContractAddress
    );
    fn call_update_issuer_claim_topics(
        ref self: TContractState,
        trusted_issuer: ContractAddress,
        claim_topics: Span<felt252>,
        onchain_id: ContractAddress
    );
    fn call_add_claim_topic(
        ref self: TContractState, claim_topic: felt252, onchain_id: ContractAddress
    );
    fn call_remove_claim_topic(
        ref self: TContractState, claim_topic: felt252, onchain_id: ContractAddress
    );
    fn call_transfer_ownership_on_token_contract(
        ref self: TContractState, new_owner: ContractAddress
    );
    fn call_transfer_ownership_on_identity_registry_contract(
        ref self: TContractState, new_owner: ContractAddress
    );
    fn call_transfer_ownership_on_compliance_contract(
        ref self: TContractState, new_owner: ContractAddress
    );
    fn call_transfer_ownership_on_claim_topics_registry_contract(
        ref self: TContractState, new_owner: ContractAddress
    );
    fn call_transfer_ownership_on_issuers_registry_contract(
        ref self: TContractState, new_owner: ContractAddress
    );
    fn call_add_agent_on_token_contract(ref self: TContractState, agent: ContractAddress);
    fn call_remove_agent_on_token_contract(ref self: TContractState, agent: ContractAddress);
    fn call_add_agent_on_identity_registry_contract(
        ref self: TContractState, agent: ContractAddress
    );
    fn call_remove_agent_on_identity_registry_contract(
        ref self: TContractState, agent: ContractAddress
    );
}
