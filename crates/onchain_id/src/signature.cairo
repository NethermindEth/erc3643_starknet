use core::num::traits::Zero;

#[derive(Copy, Drop, Serde, Hash, Default, starknet::Store)]
pub struct StarkSignature {
    pub r: felt252,
    pub s: felt252,
    pub public_key: felt252
}

#[derive(Copy, Drop, Serde, Hash, Default, starknet::Store)]
pub struct EthSignature {
    pub r: u256,
    pub s: u256,
    pub public_key: starknet::EthAddress
}

impl DefaultEthAddress of Default<starknet::EthAddress> {
    fn default() -> starknet::EthAddress {
        Zero::zero()
    }
}

#[derive(Copy, Drop, Serde, Hash)]
pub enum Signature {
    StarkSignature: StarkSignature,
    EthSignature: EthSignature,
}
