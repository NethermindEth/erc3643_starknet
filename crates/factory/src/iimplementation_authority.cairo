use core::starknet::storage_access::StorePacking;
use starknet::{ClassHash, ContractAddress};

#[derive(Drop, Copy, Serde, PartialEq)]
pub struct Version {
    pub major: u8,
    pub minor: u8,
    pub patch: u8,
}

const SHIFT_8: u32 = 0x100;
const SHIFT_16: u32 = 0x10000;
const MASK_8: u32 = 0xff;

pub impl VersionStorePacking of StorePacking<Version, u32> {
    fn pack(value: Version) -> u32 {
        value.major.into() + (value.minor.into() * SHIFT_8) + (value.patch.into() * SHIFT_16)
    }

    fn unpack(value: u32) -> Version {
        let major = value & MASK_8;
        let minor = (value / SHIFT_8) & MASK_8;
        let patch = value / SHIFT_16;

        Version {
            major: major.try_into().unwrap(),
            minor: minor.try_into().unwrap(),
            patch: patch.try_into().unwrap(),
        }
    }
}

#[derive(Drop, Copy, Serde)]
pub struct TREXImplementations {
    pub token_implementation: ClassHash,
    pub ctr_implementation: ClassHash,
    pub ir_implementation: ClassHash,
    pub irs_implementation: ClassHash,
    pub tir_implementation: ClassHash,
    pub mc_implementation: ClassHash,
}

#[starknet::interface]
pub trait IImplementationAuthority<TContractState> {
    fn add_trex_version(
        ref self: TContractState, version: Version, implementations: TREXImplementations,
    );
    fn add_and_use_trex_version(
        ref self: TContractState, version: Version, implementations: TREXImplementations,
    );
    fn use_trex_version(ref self: TContractState, version: Version);
    fn upgrade_trex_suite(ref self: TContractState, token: ContractAddress, version: Version);
    fn get_all_versions(self: @TContractState) -> Span<Version>;
    fn get_current_version(self: @TContractState) -> Version;
    fn get_implementations(self: @TContractState, version: Version) -> TREXImplementations;
    fn get_current_implementations(self: @TContractState) -> TREXImplementations;
    fn get_token_implementation(self: @TContractState) -> ClassHash;
    fn get_ctr_implementation(self: @TContractState) -> ClassHash;
    fn get_ir_implementation(self: @TContractState) -> ClassHash;
    fn get_irs_implementation(self: @TContractState) -> ClassHash;
    fn get_tir_implementation(self: @TContractState) -> ClassHash;
    fn get_mc_implementation(self: @TContractState) -> ClassHash;
}
