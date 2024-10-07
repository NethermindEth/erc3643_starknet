use starknet::ContractAddress;

#[starknet::interface]
trait IDVDTransferManager<TContractState> {
    fn modify_fee(ref self: TContractState, token1: ContractAddress, token2: ContractAddress, fee1: u256, fee2: u256, fee1_wallet: ContractAddress, fee2_wallet: ContractAddress);
    fn initiate_dvd_transfer(ref self: TContractState, token1: ContractAddress, token1_amount: u256, counter_part: ContractAddress, token2: ContractAddress, token2_amount: u256);
    fn take_dvd_transfer(ref self: TContractState, transfer_id: felt252);
    fn cancel_dvd_transfer(ref self: TContractState, transfer_id: felt252);
    fn is_TREX(self: @TContractState, token: ContractAddress, user: ContractAddress) -> bool;
    fn is_TREX_owner(self: @TContractState, token: ContractAddress, user: ContractAddress) -> bool;
    fn calculate_fee(self: @TContractState, transfer_id: felt252); // -> TxFees;
    fn calcualate_parity(self: @TContractState, token1: ContractAddress, token2: ContractAddress) -> felt252;
    fn calculate_transfer_id(self: @TContractState, nonce: u256, maker: ContractAddress, token1: ContractAddress, token1_amount: u256, taker: ContractAddress, token2: ContractAddress, token2_amount: u256) -> felt252;
}