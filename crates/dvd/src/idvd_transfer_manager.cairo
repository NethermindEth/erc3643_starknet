use starknet::ContractAddress;

impl ContractAddressDefault of Default<ContractAddress> {
    fn default() -> ContractAddress {
        starknet::contract_address_const::<0>()
    }
}

#[derive(Drop, Copy, starknet::Store, Serde, Default)]
pub struct Delivery {
    pub counterpart: ContractAddress,
    pub token: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, Copy, starknet::Store, Serde)]
pub struct Fee {
    pub token_1_fee: u256,
    pub token_2_fee: u256,
    pub fee_base: u32,
    pub fee_1_wallet: ContractAddress,
    pub fee_2_wallet: ContractAddress,
}

#[derive(Drop, Copy, starknet::Store, Serde)]
pub struct TxFees {
    pub tx_fee_1: u256,
    pub tx_fee_2: u256,
    pub fee_1_wallet: ContractAddress,
    pub fee_2_wallet: ContractAddress,
}

#[starknet::interface]
pub trait IDVDTransferManager<TContractState> {
    fn modify_fee(
        ref self: TContractState,
        token1: ContractAddress,
        token2: ContractAddress,
        fee1: u256,
        fee2: u256,
        fee_base: u32,
        fee1_wallet: ContractAddress,
        fee2_wallet: ContractAddress,
    );
    fn initiate_dvd_transfer(
        ref self: TContractState,
        token1: ContractAddress,
        token1_amount: u256,
        counterpart: ContractAddress,
        token2: ContractAddress,
        token2_amount: u256,
    );
    fn take_dvd_transfer(ref self: TContractState, transfer_id: felt252);
    fn cancel_dvd_transfer(ref self: TContractState, transfer_id: felt252);
    fn is_trex(self: @TContractState, token: ContractAddress) -> bool;
    fn is_trex_owner(self: @TContractState, token: ContractAddress, user: ContractAddress) -> bool;
    fn is_trex_agent(self: @TContractState, token: ContractAddress, user: ContractAddress) -> bool;
    fn calculate_fee(self: @TContractState, transfer_id: felt252) -> TxFees;
    fn calcualate_parity(
        self: @TContractState, token1: ContractAddress, token2: ContractAddress,
    ) -> felt252;
    fn calculate_transfer_id(
        self: @TContractState,
        nonce: felt252,
        maker: ContractAddress,
        token1: ContractAddress,
        token1_amount: u256,
        taker: ContractAddress,
        token2: ContractAddress,
        token2_amount: u256,
    ) -> felt252;
}
