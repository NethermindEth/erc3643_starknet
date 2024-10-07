use factory::itrex_factory::{TokenDetails, ClaimDetails};
use starknet::ContractAddress;

#[derive(Serde, Drop)]
pub struct Fee {
    fee: u256,
    fee_token: ContractAddress,
    fee_collector: ContractAddress
}

#[event]
#[derive(Drop, starknet::Event)]
pub enum TREXGatewayEvent {
    FactorySet: FactorySet,
    PublicDeploymentStatusSet: PublicDeploymentStatusSet,
    DeploymentFeeSet: DeploymentFeeSet,
    DeploymentFeeEnabled: DeploymentFeeEnabled,
    DeployerAdded: DeployerAdded,
    DeployerRemoved: DeployerRemoved,
    FeeDiscountApplied: FeeDiscountApplied,
    GatewaySuiteDeploymentProcessed: GatewaySuiteDeploymentProcessed
}

#[derive(Drop, starknet::Event)]
pub struct FactorySet {
    #[key]
    factory: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct PublicDeploymentStatusSet {
    #[key]
    public_deployment_status: bool,
}

#[derive(Drop, starknet::Event)]
pub struct DeploymentFeeSet {
    #[key]
    fee: u256,
    #[key]
    fee_token: ContractAddress,
    #[key]
    fee_collector: ContractAddress
}

#[derive(Drop, starknet::Event)]
pub struct DeploymentFeeEnabled {
    #[key]
    is_enabled: bool,
}

#[derive(Drop, starknet::Event)]
pub struct DeployerAdded {
    #[key]
    deployer: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct DeployerRemoved {
    #[key]
    deployer: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct FeeDiscountApplied {
    #[key]
    deployer: ContractAddress,
    discount: u16
}

#[derive(Drop, starknet::Event)]
pub struct GatewaySuiteDeploymentProcessed {
    #[key]
    requester: ContractAddress,
    intended_owner: ContractAddress,
    fee_applied: u256
}

#[starknet::interface]
pub trait ITREXGateway<TContractState> {
    fn set_factory(ref self: TContractState, factory: ContractAddress);
    fn set_public_deployment_status(ref self: TContractState, is_enabled: bool);
    fn transfer_factory_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn enable_deployment_fee(ref self: TContractState, is_enabled: bool);
    fn set_deployment_fee(
        ref self: TContractState,
        fee: u256,
        fee_token: ContractAddress,
        fee_collector: ContractAddress
    );
    fn add_deployer(ref self: TContractState, deployer: ContractAddress);
    fn batch_add_deployer(ref self: TContractState, deployers: Array<ContractAddress>);
    fn remove_deployer(ref self: TContractState, deployer: ContractAddress);
    fn batch_remove_deployer(ref self: TContractState, deployers: Array<ContractAddress>);
    fn apply_fee_discount(ref self: TContractState, deployer: ContractAddress, discount: u16);
    fn batch_apply_fee_discount(
        ref self: TContractState, deployers: Array<ContractAddress>, discounts: Array<u16>
    );
    fn deploy_TREX_suite(
        ref self: TContractState, token_details: TokenDetails, claim_details: ClaimDetails
    );
    fn batch_deploy_TREX_suite(
        ref self: TContractState,
        token_details: Array<TokenDetails>,
        claim_details: Array<ClaimDetails>
    );
    fn get_public_deployment_status(self: @TContractState) -> bool;
    fn get_factory(self: @TContractState) -> ContractAddress;
    fn get_deployment_fee(self: @TContractState) -> Fee;
    fn is_deployment_fee_enabled(self: @TContractState) -> bool;
    fn is_deployer(self: @TContractState, deployer: ContractAddress) -> bool;
    fn calculate_fee(self: @TContractState, deployer: ContractAddress) -> u256;
}
