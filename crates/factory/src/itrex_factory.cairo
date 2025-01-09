use starknet::{ClassHash, ContractAddress};

#[derive(Serde, Drop, Clone)]
pub struct TokenDetails {
    pub owner: ContractAddress,
    pub name: ByteArray,
    pub symbol: ByteArray,
    pub decimals: u8,
    pub irs: ContractAddress,
    pub onchain_id: ContractAddress,
    pub ir_agents: Span<ContractAddress>,
    pub token_agents: Span<ContractAddress>,
    pub compliance_modules: Span<ContractAddress>,
    pub compliance_settings: Span<ComplianceSetting>,
}

#[derive(Serde, Drop, Clone)]
pub struct ComplianceSetting {
    pub selector: felt252,
    pub calldata: Span<felt252>,
}

#[derive(Serde, Drop, Clone)]
pub struct ClaimDetails {
    pub claim_topics: Span<felt252>,
    pub issuers: Span<ContractAddress>,
    pub issuer_claims: Span<Span<felt252>>,
}

#[starknet::interface]
pub trait ITREXFactory<TContractState> {
    //fn set_implementation_authority(ref self: TContractState, implementation: ContractAddress);
    fn set_id_factory(ref self: TContractState, id_factory: ContractAddress);
    fn set_irs_implementation(ref self: TContractState, implementation: ClassHash);
    fn set_ir_implementation(ref self: TContractState, implementation: ClassHash);
    fn set_tir_implementation(ref self: TContractState, implementation: ClassHash);
    fn set_ctr_implementation(ref self: TContractState, implementation: ClassHash);
    fn set_mc_implementation(ref self: TContractState, implementation: ClassHash);
    fn set_token_implementation(ref self: TContractState, implementation: ClassHash);
    fn deploy_TREX_suite(
        ref self: TContractState,
        salt: felt252,
        token_details: TokenDetails,
        claim_details: ClaimDetails,
    );
    fn recover_contract_ownership(
        ref self: TContractState, contract: ContractAddress, new_owner: ContractAddress,
    );
    //fn get_implementation_authority(self: @TContractState) -> ContractAddress;
    fn get_id_factory(self: @TContractState) -> ContractAddress;
    fn get_token(self: @TContractState, salt: felt252) -> ContractAddress;
}
