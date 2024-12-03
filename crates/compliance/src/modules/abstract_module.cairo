#[starknet::component]
mod AbstractModuleComponent {
    use core::num::traits::Zero;
    use crate::modules::imodule::IModule;
    use starknet::ContractAddress;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    struct Storage {
        AbstractModule_compliance_bound: Map<ContractAddress, bool>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ComplianceBound: ComplianceBound,
        ComplianceUnbound: ComplianceUnbound
    }

    #[derive(Drop, starknet::Event)]
    pub struct ComplianceBound {
        #[key]
        compliance: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ComplianceUnbound {
        #[key]
        compliance: ContractAddress,
    }

    pub trait AbstractFunctionsTrait<TContractState> {
        fn module_transfer_action(
            ref self: ComponentState<TContractState>,
            form: ContractAddress,
            to: ContractAddress,
            value: u256
        );
        fn module_mint_action(
            ref self: ComponentState<TContractState>, to: ContractAddress, value: u256
        );
        fn module_burn_action(
            ref self: ComponentState<TContractState>, from: ContractAddress, value: u256
        );
        fn module_check(
            self: @ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            value: u256
        ) -> bool;
        fn can_compliance_bind(
            self: @ComponentState<TContractState>, compliance: ContractAddress
        ) -> bool;
        fn is_plug_and_play(self: @ComponentState<TContractState>) -> bool;
        fn name(self: @ComponentState<TContractState>) -> ByteArray;
    }

    #[abi(AbstractModule)]
    impl AbstractModuleImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        +AbstractFunctionsTrait<TContractState>
    > of IModule<ComponentState<TContractState>> {
        fn bind_compliance(ref self: ComponentState<TContractState>, compliance: ContractAddress) {
            assert!(compliance.is_non_zero(), "compliance address zero");
            assert!(
                !self.AbstractModule_compliance_bound.read(compliance), "compliance already bound"
            );
            assert!(
                starknet::get_caller_address() == compliance, "only compliance contract can call"
            );
            self.AbstractModule_compliance_bound.write(compliance, true);
            self.emit(ComplianceBound { compliance });
        }

        fn unbind_compliance(
            ref self: ComponentState<TContractState>, compliance: ContractAddress
        ) {
            self.only_compliance_call();
            assert!(compliance.is_non_zero(), "compliance address zero");
            assert!(
                starknet::get_caller_address() == compliance, "only compliance contract can call"
            );
            self.AbstractModule_compliance_bound.write(compliance, false);
            self.emit(ComplianceUnbound { compliance });
        }

        fn is_compliance_bound(
            self: @ComponentState<TContractState>, compliance: ContractAddress
        ) -> bool {
            self.AbstractModule_compliance_bound.read(compliance)
        }

        fn module_transfer_action(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            value: u256
        ) {
            AbstractFunctionsTrait::module_transfer_action(ref self, from, to, value);
        }

        fn module_mint_action(
            ref self: ComponentState<TContractState>, to: ContractAddress, value: u256
        ) {
            AbstractFunctionsTrait::module_mint_action(ref self, to, value);
        }

        fn module_burn_action(
            ref self: ComponentState<TContractState>, from: ContractAddress, value: u256
        ) {
            AbstractFunctionsTrait::module_burn_action(ref self, from, value);
        }

        fn module_check(
            self: @ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            value: u256
        ) -> bool {
            AbstractFunctionsTrait::module_check(self, from, to, value)
        }

        fn can_compliance_bind(
            self: @ComponentState<TContractState>, compliance: ContractAddress
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
    impl InternalImpl<
        TContractState, +Drop<TContractState>, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        #[inline]
        fn only_bound_compliance(
            self: @ComponentState<TContractState>, compliance: ContractAddress
        ) {
            assert!(self.AbstractModule_compliance_bound.read(compliance), "compliance not bound");
        }

        #[inline]
        fn only_compliance_call(self: @ComponentState<TContractState>) {
            assert!(
                self.AbstractModule_compliance_bound.read(starknet::get_caller_address()),
                "only bound compliance can call"
            );
        }
    }
}
