use starknet::ContractAddress;

#[starknet::interface]
pub trait IConditionalTransferModule<ContractState> {
    fn batch_approve_transfers(
        ref self: ContractState,
        from: Span<ContractAddress>,
        to: Span<ContractAddress>,
        amount: Span<u256>,
    );
    fn batch_unapprove_transfers(
        ref self: ContractState,
        from: Span<ContractAddress>,
        to: Span<ContractAddress>,
        amount: Span<u256>,
    );
    fn approve_transfer(
        ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
    );
    fn unapprove_transfer(
        ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
    );
    fn is_transfer_approved(
        self: @ContractState, compliance: ContractAddress, transfer_hash: felt252,
    ) -> bool;
    fn get_transfer_approvals(
        self: @ContractState, compliance: ContractAddress, transfer_hash: felt252,
    ) -> u256;
    fn calculate_transfer_hash(
        self: @ContractState,
        from: ContractAddress,
        to: ContractAddress,
        amount: u256,
        token: ContractAddress,
    ) -> felt252;
}

#[starknet::contract]
pub mod ConditionalTransferModule {
    use core::poseidon::poseidon_hash_span;
    use crate::{
        imodular_compliance::{IModularComplianceDispatcher, IModularComplianceDispatcherTrait},
        modules::abstract_module::{
            AbstractModuleComponent, AbstractModuleComponent::AbstractFunctionsTrait,
        },
    };
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use starknet::{
        ClassHash, ContractAddress,
        storage::{Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess},
    };

    component!(path: AbstractModuleComponent, storage: abstract_module, event: AbstractModuleEvent);

    #[abi(embed_v0)]
    impl ModuleImpl = AbstractModuleComponent::AbstractModule<ContractState>;
    impl AbstractModuleInternalImpl = AbstractModuleComponent::InternalImpl<ContractState>;

    component!(path: UpgradeableComponent, storage: upgrades, event: UpgradeableEvent);

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        transfers_approved: Map<(ContractAddress, felt252), u256>,
        #[substorage(v0)]
        abstract_module: AbstractModuleComponent::Storage,
        #[substorage(v0)]
        upgrades: UpgradeableComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TransferApproved: TransferApproved,
        ApprovalRemoved: ApprovalRemoved,
        #[flat]
        AbstractModuleEvent: AbstractModuleComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct TransferApproved {
        from: ContractAddress,
        to: ContractAddress,
        amount: u256,
        token: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct ApprovalRemoved {
        from: ContractAddress,
        to: ContractAddress,
        amount: u256,
        token: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        /// Upgrades the implementation used by this contract.
        ///
        /// # Arguments
        ///
        /// - `new_class_hash` A `ClassHash` representing the implementation to update to.
        ///
        /// # Requirements
        ///
        /// - This function can only be called by the owner.
        /// - The `ClassHash` should already have been declared.
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgrades.upgrade(new_class_hash);
        }
    }

    impl AbstractFunctionsImpl of AbstractFunctionsTrait<ContractState> {
        fn module_transfer_action(
            ref self: AbstractModuleComponent::ComponentState<ContractState>,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
        ) {
            self.only_compliance_call();
            let mut contract_state = AbstractModuleComponent::HasComponent::get_contract_mut(
                ref self,
            );
            let caller = starknet::get_caller_address();
            let token_bound = IModularComplianceDispatcher { contract_address: caller }
                .get_token_bound();

            let transfer_hash = contract_state
                .calculate_transfer_hash(from, to, value, token_bound);
            let transfers_approved_storage_path = contract_state
                .transfers_approved
                .entry((caller, transfer_hash));
            let approval_count = transfers_approved_storage_path.read();

            if approval_count > 0 {
                transfers_approved_storage_path.write(approval_count - 1);
                contract_state
                    .emit(TransferApproved { from, to, amount: value, token: token_bound });
            }
        }

        fn module_mint_action(
            ref self: AbstractModuleComponent::ComponentState<ContractState>,
            to: ContractAddress,
            value: u256,
        ) {
            self.only_compliance_call();
        }

        fn module_burn_action(
            ref self: AbstractModuleComponent::ComponentState<ContractState>,
            from: ContractAddress,
            value: u256,
        ) {
            self.only_compliance_call();
        }

        fn module_check(
            self: @AbstractModuleComponent::ComponentState<ContractState>,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
            compliance: ContractAddress,
        ) -> bool {
            let contract_state = AbstractModuleComponent::HasComponent::get_contract(self);
            let transfer_hash = contract_state
                .calculate_transfer_hash(
                    from,
                    to,
                    value,
                    IModularComplianceDispatcher { contract_address: compliance }.get_token_bound(),
                );
            contract_state.is_transfer_approved(compliance, transfer_hash)
        }

        fn can_compliance_bind(
            self: @AbstractModuleComponent::ComponentState<ContractState>,
            compliance: ContractAddress,
        ) -> bool {
            true
        }

        fn is_plug_and_play(self: @AbstractModuleComponent::ComponentState<ContractState>) -> bool {
            true
        }

        fn name(self: @AbstractModuleComponent::ComponentState<ContractState>) -> ByteArray {
            "ConditionalTransferModule"
        }
    }

    #[abi(embed_v0)]
    impl ConditionalTransferModuleImpl of super::IConditionalTransferModule<ContractState> {
        fn batch_approve_transfers(
            ref self: ContractState,
            from: Span<ContractAddress>,
            to: Span<ContractAddress>,
            amount: Span<u256>,
        ) {
            self.abstract_module.only_compliance_call();
            for i in 0..from.len() {
                self._approve_transfer(*from.at(i), *to.at(i), *amount.at(i));
            };
        }

        fn batch_unapprove_transfers(
            ref self: ContractState,
            from: Span<ContractAddress>,
            to: Span<ContractAddress>,
            amount: Span<u256>,
        ) {
            self.abstract_module.only_compliance_call();
            for i in 0..from.len() {
                self._unapprove_transfer(*from.at(i), *to.at(i), *amount.at(i));
            };
        }

        fn approve_transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
        ) {
            self.abstract_module.only_compliance_call();
            self._approve_transfer(from, to, amount);
        }

        fn unapprove_transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
        ) {
            self.abstract_module.only_compliance_call();
            self._unapprove_transfer(from, to, amount);
        }

        fn is_transfer_approved(
            self: @ContractState, compliance: ContractAddress, transfer_hash: felt252,
        ) -> bool {
            self.transfers_approved.entry((compliance, transfer_hash)).read() > 0
        }

        fn get_transfer_approvals(
            self: @ContractState, compliance: ContractAddress, transfer_hash: felt252,
        ) -> u256 {
            self.transfers_approved.entry((compliance, transfer_hash)).read()
        }

        fn calculate_transfer_hash(
            self: @ContractState,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256,
            token: ContractAddress,
        ) -> felt252 {
            let mut serialized_data: Array<felt252> = array![];
            from.serialize(ref serialized_data);
            to.serialize(ref serialized_data);
            amount.serialize(ref serialized_data);
            token.serialize(ref serialized_data);
            poseidon_hash_span(serialized_data.span())
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _approve_transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
        ) {
            let caller = starknet::get_caller_address();
            let token_bound = IModularComplianceDispatcher { contract_address: caller }
                .get_token_bound();

            let transfer_hash = self.calculate_transfer_hash(from, to, amount, token_bound);

            let storage_path = self.transfers_approved.entry((caller, transfer_hash));
            let approval_count = storage_path.read();
            storage_path.write(approval_count + 1);

            self.emit(TransferApproved { from, to, amount, token: token_bound });
        }


        fn _unapprove_transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
        ) {
            let caller = starknet::get_caller_address();
            let token_bound = IModularComplianceDispatcher { contract_address: caller }
                .get_token_bound();

            let transfer_hash = self.calculate_transfer_hash(from, to, amount, token_bound);

            let storage_path = self.transfers_approved.entry((caller, transfer_hash));
            let approval_count = storage_path.read();
            assert(approval_count > 0, 'Not Approved');
            storage_path.write(approval_count - 1);

            self.emit(ApprovalRemoved { from, to, amount, token: token_bound });
        }
    }
}
