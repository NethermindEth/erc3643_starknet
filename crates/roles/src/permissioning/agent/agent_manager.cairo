use starknet::ContractAddress;

#[starknet::interface]
trait IAgentManager<TContractState> {
    fn call_forced_transfer(ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256);//onchain-id: IIdentity);
    fn call_batch_forced_transfer(ref self: TContractState, from_list: Array<ContractAddress>, to_list: Array<ContractAddress>, amount: Array<u256>);//onchain-id: IIdentity);
}