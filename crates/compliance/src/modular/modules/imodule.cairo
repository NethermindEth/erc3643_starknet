use starknet::ContractAddress;

#[starknet::interface]
pub trait IModule<TContractState> {
    fn bind_compliance(ref self: TContractState, compliance: ContractAddress);
    fn unbind_compliance(ref self: TContractState, compliance: ContractAddress);
    fn module_transfer_action(
        ref self: TContractState, form: ContractAddress, to: ContractAddress, value: u256
    );
    fn module_mint_action(ref self: TContractState, to: ContractAddress, value: u256);
    fn module_burn_action(ref self: TContractState, from: ContractAddress, value: u256);
    fn module_check(
        self: @TContractState, from: ContractAddress, to: ContractAddress, value: u256
    ) -> bool;
    fn is_compliance_bound(self: @TContractState, compliance: ContractAddress) -> bool;
    fn can_compliance_bind(
        self: @TContractState, compliance: ContractAddress
    ) -> bool; // pure function in solidity
    fn is_plug_and_play(self: @TContractState) -> bool;
    fn name(self: @TContractState) -> ByteArray;
}
