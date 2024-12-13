use starknet::ContractAddress;

#[starknet::interface]
pub trait ITrustedIssuersRegistry<TContractState> {
    fn add_trusted_issuer(
        ref self: TContractState, trusted_issuer: ContractAddress, claim_topics: Span<felt252>,
    );
    fn remove_trusted_issuer(ref self: TContractState, trusted_issuer: ContractAddress);
    fn update_issuer_claim_topics(
        ref self: TContractState, trusted_issuer: ContractAddress, claim_topics: Span<felt252>,
    );
    fn has_claim_topic(
        self: @TContractState, issuer: ContractAddress, claim_topic: felt252,
    ) -> bool;
    fn is_trusted_issuer(self: @TContractState, issuer: ContractAddress) -> bool;
    fn get_trusted_issuers(self: @TContractState) -> Span<ContractAddress>;
    fn get_trusted_issuers_for_claim_topic(
        self: @TContractState, claim_topic: felt252,
    ) -> Span<ContractAddress>;
    fn get_trusted_issuer_claim_topics(
        self: @TContractState, trusted_issuer: ContractAddress,
    ) -> Span<felt252>;
}
