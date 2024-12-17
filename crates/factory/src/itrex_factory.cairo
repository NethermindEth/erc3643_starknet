use starknet::ContractAddress;

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
    pub compliance_settings: Span<ContractAddress>,
}

#[derive(Serde, Drop, Clone)]
pub struct ClaimDetails {
    pub claim_topics: Span<u256>,
    pub issuers: Span<ContractAddress>,
    pub issuer_claims: Span<Span<u256>>,
}

#[event]
#[derive(Drop, starknet::Event)]
pub enum TREXFactoryEvent {
    Deployed: Deployed,
    IdFactorySet: IdFactorySet,
    ImplementationAuthoritySet: ImplementationAuthoritySet,
    TREXSuiteDeployed: TREXSuiteDeployed,
}

#[derive(Drop, starknet::Event)]
pub struct Deployed {
    #[key]
    address: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct IdFactorySet {
    #[key]
    id_factory: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct ImplementationAuthoritySet {
    implementation_authority: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct TREXSuiteDeployed {
    token: ContractAddress,
    ir: ContractAddress,
    irs: ContractAddress,
    tir: ContractAddress,
    ctr: ContractAddress,
    mc: ContractAddress,
    salt: ByteArray,
}


#[starknet::interface]
pub trait ITREXFactory<TContractState> {
    fn set_implementation_authority(ref self: TContractState, implementation: ContractAddress);
    fn set_id_factory(ref self: TContractState, id_factory: ContractAddress);
    fn deploy_TREX_suite(
        ref self: TContractState,
        salt: Span<felt252>,
        token_details: TokenDetails,
        claim_details: ClaimDetails,
    );
    fn recover_contract_ownership(
        ref self: TContractState, contract: ContractAddress, new_owner: ContractAddress,
    );
    fn get_implementation_authority(self: @TContractState) -> ContractAddress;
    fn get_id_factory(self: @TContractState) -> ContractAddress;
    fn get_token(self: @TContractState, salt: ByteArray) -> ContractAddress;
}
