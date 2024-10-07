use starknet::ContractAddress;

#[event]
#[derive(Drop, starknet::Event)]
enum ComplianceEvent {
   TokenAgentAdded: TokenAgentAdded,
   TokenAgentRemoved: TokenAgentRemoved,
   TokenBound: TokenBound,
   TokenUnbound: TokenUnbound
}

#[derive(Drop, starknet::Event)]
pub struct TokenAgentAdded {
    agent_address: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct TokenAgentRemoved {
    agent_address: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct TokenBound {
    token: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct TokenUnbound {
    token: ContractAddress,
}

#[starknet::interface]
pub trait ICompliance<TContractState> {
    fn add_token_agent(ref self: TContractState, agent_address: ContractAddress);
    fn remove_token_agent(ref self: TContractState, agent_address: ContractAddress);
    fn bind_token(ref self: TContractState, token: ContractAddress);
    fn unbind_token(ref self: TContractState, token: ContractAddress);
    fn transferred(ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256);
    fn created(ref self: TContractState, to: ContractAddress, amount: u256);
    fn destroyed(ref self: TContractState, from: ContractAddress, amount: u256);
    fn is_token_agent(self: @TContractState, agent_address: ContractAddress) -> bool;
    fn is_token_bound(self: @TContractState, token: ContractAddress) -> bool;
    fn can_transfer(self: @TContractState, from: ContractAddress, to: ContractAddress, amount: u256) -> bool;
}