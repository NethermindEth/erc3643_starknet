#[starknet::component]
pub mod AbstractModuleComponent {
    use core::num::traits::Zero;
    use crate::compliance::modules::imodule::IModule;
    use starknet::ContractAddress;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    pub struct Storage {
        AbstractModule_compliance_bound: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ComplianceBound: ComplianceBound,
        ComplianceUnbound: ComplianceUnbound,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ComplianceBound {
        #[key]
        pub compliance: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ComplianceUnbound {
        #[key]
        pub compliance: ContractAddress,
    }

    pub mod Errors {
        pub const COMPLIANCE_ADDRESS_ZERO: felt252 = 'Compliance address zero';
        pub const COMPLIANCE_ALREADY_BOUND: felt252 = 'Compliance already bound';
        pub const ONLY_COMPLIANCE_CAN_CALL: felt252 = 'Only compliance can call';
        pub const ONLY_BOUND_COMPLIANCE_CAN_CALL: felt252 = 'Only bound compliance can call';
    }

    pub trait AbstractFunctionsTrait<TContractState> {
        fn module_transfer_action(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
        );
        fn module_mint_action(
            ref self: ComponentState<TContractState>, to: ContractAddress, value: u256,
        );
        fn module_burn_action(
            ref self: ComponentState<TContractState>, from: ContractAddress, value: u256,
        );
        fn module_check(
            self: @ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
            compliance: ContractAddress,
        ) -> bool;
        fn can_compliance_bind(
            self: @ComponentState<TContractState>, compliance: ContractAddress,
        ) -> bool;
        fn is_plug_and_play(self: @ComponentState<TContractState>) -> bool;
        fn name(self: @ComponentState<TContractState>) -> ByteArray;
    }

    #[embeddable_as(AbstractModuleImpl)]
    pub impl AbstractModule<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        +AbstractFunctionsTrait<TContractState>,
    > of IModule<ComponentState<TContractState>> {
        fn bind_compliance(ref self: ComponentState<TContractState>, compliance: ContractAddress) {
            /// NOTE: can use caller address directly instead and eliminate those checks?
            assert(compliance.is_non_zero(), Errors::COMPLIANCE_ADDRESS_ZERO);
            assert(
                !self.AbstractModule_compliance_bound.read(compliance),
                Errors::COMPLIANCE_ALREADY_BOUND,
            );
            assert(starknet::get_caller_address() == compliance, Errors::ONLY_COMPLIANCE_CAN_CALL);
            self.AbstractModule_compliance_bound.write(compliance, true);
            self.emit(ComplianceBound { compliance });
        }

        fn unbind_compliance(
            ref self: ComponentState<TContractState>, compliance: ContractAddress,
        ) {
            self.only_compliance_call();
            /// NOTE: can use caller address directly instead and eliminate those checks?
            assert(compliance.is_non_zero(), Errors::COMPLIANCE_ADDRESS_ZERO);
            assert(starknet::get_caller_address() == compliance, Errors::ONLY_COMPLIANCE_CAN_CALL);
            self.AbstractModule_compliance_bound.write(compliance, false);
            self.emit(ComplianceUnbound { compliance });
        }

        fn is_compliance_bound(
            self: @ComponentState<TContractState>, compliance: ContractAddress,
        ) -> bool {
            self.AbstractModule_compliance_bound.read(compliance)
        }

        fn module_transfer_action(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
        ) {
            AbstractFunctionsTrait::module_transfer_action(ref self, from, to, value);
        }

        fn module_mint_action(
            ref self: ComponentState<TContractState>, to: ContractAddress, value: u256,
        ) {
            AbstractFunctionsTrait::module_mint_action(ref self, to, value);
        }

        fn module_burn_action(
            ref self: ComponentState<TContractState>, from: ContractAddress, value: u256,
        ) {
            AbstractFunctionsTrait::module_burn_action(ref self, from, value);
        }

        fn module_check(
            self: @ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
            compliance: ContractAddress,
        ) -> bool {
            AbstractFunctionsTrait::module_check(self, from, to, value, compliance)
        }

        fn can_compliance_bind(
            self: @ComponentState<TContractState>, compliance: ContractAddress,
        ) -> bool {
            AbstractFunctionsTrait::can_compliance_bind(self, compliance)
        }

        fn is_plug_and_play(self: @ComponentState<TContractState>) -> bool {
            AbstractFunctionsTrait::is_plug_and_play(self)
        }

        fn name(self: @ComponentState<TContractState>) -> ByteArray {
            AbstractFunctionsTrait::name(self)
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +Drop<TContractState>, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        #[inline]
        fn only_compliance_call(self: @ComponentState<TContractState>) {
            assert(
                self.AbstractModule_compliance_bound.read(starknet::get_caller_address()),
                Errors::ONLY_BOUND_COMPLIANCE_CAN_CALL,
            );
        }
    }
}
