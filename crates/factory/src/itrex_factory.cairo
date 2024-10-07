use starknet::ContractAddress;

#[derive(Serde, Drop)]
pub struct TokenDetails {
    owner: ContractAddress,
    name: ByteArray,
    symbol: ByteArray,
    decimals: u8,
    irs: ContractAddress,
    onchain_id: ContractAddress,
    ir_agents: Array<ContractAddress>,
    token_agents: Array<ContractAddress>,
    compliance_modules: Array<ContractAddress>,
    compliance_settings: Array<ContractAddress>,
}

#[event]
#[derive(Drop, starknet::Event)]
pub enum TREXFactoryEvent {
    Deployed: Deployed,
    IdFactorySet: IdFactorySet,
    ImplementationAuthoritySet: ImplementationAuthoritySet,
    TREXSuiteDeployed: TREXSuiteDeployed
}

#[derive(Serde, Drop)]
pub struct ClaimDetails {
    claim_topics: Array<u256>,
    issuers: Array<ContractAddress>,
    issuer_claims: Array<Array<u256>>
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
    salt: ByteArray
}


#[starknet::interface]
pub trait ITREXFactory<TContractState> {
    fn set_implementation_authority(ref self: TContractState, implementation: ContractAddress);
    fn set_id_factory(ref self: TContractState, id_factory: ContractAddress);
    fn deploy_TREX_suite(
        ref self: TContractState,
        salt: ByteArray,
        token_details: TokenDetails,
        claim_details: ClaimDetails
    );
    fn recover_contract_ownership(
        ref self: TContractState, contract: ContractAddress, new_owner: ContractAddress
    );
    fn get_implementation_authority(self: @TContractState) -> ContractAddress;
    fn get_id_factory(self: @TContractState) -> ContractAddress;
    fn get_token(self: @TContractState, salt: ByteArray) -> ContractAddress;
}
