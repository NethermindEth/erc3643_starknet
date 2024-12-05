use starknet::ContractAddress;

#[starknet::interface]
trait ITransferRestrictModule<TContractState> {
    fn allow_user(ref self: TContractState, user_address: ContractAddress);
    fn batch_allow_users(ref self: TContractState, user_addresses: Span<ContractAddress>);
    fn disallow_user(ref self: TContractState, user_address: ContractAddress);
    fn batch_disallow_users(ref self: TContractState, user_addresses: Span<ContractAddress>);
    fn is_user_allowed(
        self: @TContractState, compliance: ContractAddress, user_address: ContractAddress,
    ) -> bool;
}

#[starknet::contract]
mod TransferRestrictModule {
    use crate::modules::abstract_module::{
        AbstractModuleComponent, AbstractModuleComponent::AbstractFunctionsTrait,
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
        allowed_users: Map<ContractAddress, Map<ContractAddress, bool>>,
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
        UserAllowed: UserAllowed,
        UserDisallowed: UserDisallowed,
        #[flat]
        AbstractModuleEvent: AbstractModuleComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct UserAllowed {
        compliance: ContractAddress,
        user_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct UserDisallowed {
        compliance: ContractAddress,
        user_address: ContractAddress,
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
        /// - This function can only be called by the xerc20 owner.
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
            let mut contract_state = AbstractModuleComponent::HasComponent::get_contract_mut(
                ref self,
            );
            contract_state.abstract_module.only_compliance_call();
        }

        fn module_mint_action(
            ref self: AbstractModuleComponent::ComponentState<ContractState>,
            to: ContractAddress,
            value: u256,
        ) {
            let mut contract_state = AbstractModuleComponent::HasComponent::get_contract_mut(
                ref self,
            );
            contract_state.abstract_module.only_compliance_call();
        }

        fn module_burn_action(
            ref self: AbstractModuleComponent::ComponentState<ContractState>,
            from: ContractAddress,
            value: u256,
        ) {
            let mut contract_state = AbstractModuleComponent::HasComponent::get_contract_mut(
                ref self,
            );
            contract_state.abstract_module.only_compliance_call();
        }

        fn module_check(
            self: @AbstractModuleComponent::ComponentState<ContractState>,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
            compliance: ContractAddress,
        ) -> bool {
            let contract_state = AbstractModuleComponent::HasComponent::get_contract(self);
            if contract_state.allowed_users.entry(compliance).entry(from).read() {
                return true;
            }
            contract_state.allowed_users.entry(compliance).entry(to).read()
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
            "TransferRestrictModule"
        }
    }

    #[abi(embed_v0)]
    impl TransferRestrictModuleImpl of super::ITransferRestrictModule<ContractState> {
        fn allow_user(ref self: ContractState, user_address: ContractAddress) {
            self.abstract_module.only_compliance_call();
            let caller = starknet::get_caller_address();
            self.allowed_users.entry(caller).entry(user_address).write(true);
            self.emit(UserDisallowed { compliance: caller, user_address });
        }

        fn batch_allow_users(ref self: ContractState, user_addresses: Span<ContractAddress>) {
            self.abstract_module.only_compliance_call();
            let caller = starknet::get_caller_address();
            let allowed_users_storage_path = self.allowed_users.entry(caller);
            for user_address in user_addresses {
                allowed_users_storage_path.entry(*user_address).write(true);
                self.emit(UserDisallowed { compliance: caller, user_address: *user_address });
            };
        }

        fn disallow_user(ref self: ContractState, user_address: ContractAddress) {
            self.abstract_module.only_compliance_call();
            let caller = starknet::get_caller_address();
            self.allowed_users.entry(caller).entry(user_address).write(false);
            self.emit(UserDisallowed { compliance: caller, user_address });
        }

        fn batch_disallow_users(ref self: ContractState, user_addresses: Span<ContractAddress>) {
            self.abstract_module.only_compliance_call();
            let caller = starknet::get_caller_address();
            let allowed_users_storage_path = self.allowed_users.entry(caller);
            for user_address in user_addresses {
                allowed_users_storage_path.entry(*user_address).write(false);
                self.emit(UserDisallowed { compliance: caller, user_address: *user_address });
            };
        }

        fn is_user_allowed(
            self: @ContractState, compliance: ContractAddress, user_address: ContractAddress,
        ) -> bool {
            self.allowed_users.entry(starknet::get_caller_address()).entry(user_address).read()
        }
    }
}

