#[starknet::contract]
pub mod ModularCompliance {
    use core::num::traits::Zero;
    use crate::{
        imodular_compliance::IModularCompliance,
        modules::imodule::{IModuleDispatcher, IModuleDispatcherTrait},
    };
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use starknet::{
        ClassHash, ContractAddress,
        storage::{Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess},
    };
    use storage::storage_array::{
        ContractAddressVecToContractAddressArray, MutableStorageArrayTrait,
        StorageArrayContractAddress, StorageArrayTrait,
    };

    component!(path: UpgradeableComponent, storage: upgrades, event: UpgradeableEvent);

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        /// token linked to the compliance contract
        token_bound: ContractAddress,
        /// Array of modules bound to the compliance
        modules: StorageArrayContractAddress,
        /// Mapping of module binding status
        module_bound: Map<ContractAddress, bool>,
        #[substorage(v0)]
        upgrades: UpgradeableComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ModuleInteraction: ModuleInteraction,
        TokenBound: TokenBound,
        TokenUnbound: TokenUnbound,
        ModuleAdded: ModuleAdded,
        ModuleRemoved: ModuleRemoved,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ModuleInteraction {
        #[key]
        pub target: ContractAddress,
        pub selector: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenBound {
        pub token: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenUnbound {
        pub token: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ModuleAdded {
        #[key]
        pub module: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ModuleRemoved {
        #[key]
        pub module: ContractAddress,
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

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl ModularComplianceImpl of IModularCompliance<ContractState> {
        fn bind_token(ref self: ContractState, token: ContractAddress) {
            assert(token.is_non_zero(), 'Token zero address');
            let caller = starknet::get_caller_address();
            assert(
                self.ownable.owner() == caller
                    || (self.token_bound.read().is_zero() && caller == token),
                'Only owner or token can call',
            );
            self.token_bound.write(token);
            self.emit(TokenBound { token });
        }

        fn unbind_token(ref self: ContractState, token: ContractAddress) {
            assert(token.is_non_zero(), 'Token zero address');
            let caller = starknet::get_caller_address();
            assert(
                self.ownable.owner() == caller || caller == token, 'Only owner or token can call',
            );
            assert(self.token_bound.read() == token, 'This token is not bound');
            self.token_bound.write(Zero::zero());
            self.emit(TokenUnbound { token });
        }

        fn add_module(ref self: ContractState, module: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(module.is_non_zero(), 'Module address zero');
            assert(!self.module_bound.entry(module).read(), 'Module already bound');
            let modules_storage_path = self.modules.deref();
            assert(modules_storage_path.len() < 25, 'Cannot add more than 25 modules');
            let module_dispatcher = IModuleDispatcher { contract_address: module };
            if !module_dispatcher.is_plug_and_play() {
                assert!(
                    module_dispatcher.can_compliance_bind(starknet::get_contract_address()),
                    "Compliance is not suitable for binding to the module",
                );
            }

            module_dispatcher.bind_compliance(starknet::get_contract_address());
            modules_storage_path.append().write(module);
            self.module_bound.entry(module).write(true);
            self.emit(ModuleAdded { module });
        }

        fn remove_module(ref self: ContractState, module: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(module.is_non_zero(), 'Module address zero');
            assert(self.module_bound.entry(module).read(), 'Module not bound');
            self.module_bound.entry(module).write(false);
            IModuleDispatcher { contract_address: module }
                .unbind_compliance(starknet::get_contract_address());

            let modules_storage_path = self.modules.deref();
            for i in 0..modules_storage_path.len() {
                if modules_storage_path.at(i).read() == module {
                    modules_storage_path.delete(i);
                    self.emit(ModuleRemoved { module });
                    break;
                }
            };
        }

        fn call_module_function(
            ref self: ContractState,
            selector: felt252,
            calldata: Span<felt252>,
            module: ContractAddress,
        ) {
            self.ownable.assert_only_owner();
            assert(self.module_bound.entry(module).read(), 'Can only call bound module');
            starknet::syscalls::call_contract_syscall(module, selector, calldata).unwrap();
            self.emit(ModuleInteraction { target: module, selector });
        }

        fn transferred(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
        ) {
            self.assert_only_token();
            assert(from.is_non_zero() && to.is_non_zero(), 'Zero address');
            assert(amount.is_non_zero(), 'No value transfer');

            let modules_storage_path = self.modules.deref();
            for i in 0..modules_storage_path.len() {
                IModuleDispatcher { contract_address: modules_storage_path.at(i).read() }
                    .module_transfer_action(from, to, amount);
            };
        }

        fn created(ref self: ContractState, to: ContractAddress, amount: u256) {
            self.assert_only_token();
            assert(to.is_non_zero(), 'Zero address');
            assert(amount.is_non_zero(), 'No value transfer');

            let modules_storage_path = self.modules.deref();
            for i in 0..modules_storage_path.len() {
                IModuleDispatcher { contract_address: modules_storage_path.at(i).read() }
                    .module_mint_action(to, amount);
            };
        }

        fn destroyed(ref self: ContractState, from: ContractAddress, amount: u256) {
            self.assert_only_token();
            assert(from.is_non_zero(), 'Zero address');
            assert(amount.is_non_zero(), 'No value transfer');

            let modules_storage_path = self.modules.deref();
            for i in 0..modules_storage_path.len() {
                IModuleDispatcher { contract_address: modules_storage_path.at(i).read() }
                    .module_burn_action(from, amount);
            };
        }

        fn can_transfer(
            self: @ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
        ) -> bool {
            let mut can_transfer = true;
            let modules_storage_path = self.modules.deref();
            for i in 0..modules_storage_path.len() {
                let check_result = IModuleDispatcher {
                    contract_address: modules_storage_path.at(i).read(),
                }
                    .module_check(from, to, amount, starknet::get_contract_address());
                if !check_result {
                    can_transfer = false;
                    break;
                }
            };
            can_transfer
        }

        fn get_modules(self: @ContractState) -> Array<ContractAddress> {
            self.modules.deref().into()
        }

        fn get_token_bound(self: @ContractState) -> ContractAddress {
            self.token_bound.read()
        }

        fn is_module_bound(self: @ContractState, module: ContractAddress) -> bool {
            self.module_bound.entry(module).read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_only_token(self: @ContractState) {
            assert!(
                starknet::get_caller_address() == self.token_bound.read(),
                "This address is not a token bound to the compliance contract",
            );
        }
    }
}
