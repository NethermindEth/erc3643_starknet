use crate::factory::itrex_factory::{ClaimDetails, TokenDetails};
use starknet::ContractAddress;

#[derive(Serde, Drop, starknet::Store)]
pub struct Fee {
    pub fee: u256,
    pub fee_token: ContractAddress,
    pub fee_collector: ContractAddress,
}

#[starknet::interface]
pub trait ITREXGateway<TContractState> {
    fn set_factory(ref self: TContractState, factory: ContractAddress);
    fn set_public_deployment_status(ref self: TContractState, is_enabled: bool);
    fn set_deployment_fee(
        ref self: TContractState,
        fee: u256,
        fee_token: ContractAddress,
        fee_collector: ContractAddress,
    );
    fn enable_deployment_fee(ref self: TContractState, is_enabled: bool);
    fn transfer_factory_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn add_deployer(ref self: TContractState, deployer: ContractAddress);
    fn batch_add_deployer(ref self: TContractState, deployers: Span<ContractAddress>);
    fn remove_deployer(ref self: TContractState, deployer: ContractAddress);
    fn batch_remove_deployer(ref self: TContractState, deployers: Span<ContractAddress>);
    fn apply_fee_discount(ref self: TContractState, deployer: ContractAddress, discount: u16);
    fn batch_apply_fee_discount(
        ref self: TContractState, deployers: Span<ContractAddress>, discounts: Span<u16>,
    );
    fn deploy_TREX_suite(
        ref self: TContractState, token_details: TokenDetails, claim_details: ClaimDetails,
    );
    fn batch_deploy_TREX_suite(
        ref self: TContractState,
        token_details: Span<TokenDetails>,
        claim_details: Span<ClaimDetails>,
    );
    fn calculate_fee(self: @TContractState, deployer: ContractAddress) -> u256;
    fn is_deployment_fee_enabled(self: @TContractState) -> bool;
    fn is_deployer(self: @TContractState, deployer: ContractAddress) -> bool;
    fn get_public_deployment_status(self: @TContractState) -> bool;
    fn get_factory(self: @TContractState) -> ContractAddress;
    fn get_deployment_fee(self: @TContractState) -> Fee;
}
