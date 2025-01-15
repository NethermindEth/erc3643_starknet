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
        implementation_authority: ContractAddress,
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

    pub mod Errors {
        pub const TOKEN_ADDRESS_ZERO: felt252 = 'Token zero address';
        pub const ONLY_OWNER_OR_TOKEN: felt252 = 'Only owner or token can call';
        pub const MODULE_ADDRESS_ZERO: felt252 = 'Module address zero';
        pub const MODULE_ALREADY_BOUND: felt252 = 'Module already bound';
        pub const MODULE_NOT_BOUND: felt252 = 'Module not bound';
        pub const TOKEN_NOT_BOUND: felt252 = 'This token is not bound';
        pub const MAX_MODULES_EXCEEDED: felt252 = 'Cannot add more than 25 modules';
        pub const COMPLIANCE_CANNOT_BIND: felt252 = 'Compliance cannot bind';
        pub const ONLY_BOUND_MODULE: felt252 = 'Only bound module can call';
        pub const ZERO_ADDRESS: felt252 = 'Zero address';
        pub const NO_VALUE_TRANSFER: felt252 = 'No value transfer';
        pub const ONLY_BOUND_TOKEN: felt252 = 'Only token bound can call';
        pub const CALLER_IS_NOT_IMPLEMENTATION_AUTHORITY: felt252 = 'Caller is not IA';
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
        /// - This function can only be called by the implementation authority.
        /// - The `ClassHash` should already have been declared.
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            assert(
                self.implementation_authority.read() == starknet::get_caller_address(),
                Errors::CALLER_IS_NOT_IMPLEMENTATION_AUTHORITY,
            );
            self.upgrades.upgrade(new_class_hash);
        }
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, implementation_authority: ContractAddress, owner: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self.implementation_authority.write(implementation_authority);
    }

    #[abi(embed_v0)]
    impl ModularComplianceImpl of IModularCompliance<ContractState> {
        fn bind_token(ref self: ContractState, token: ContractAddress) {
            assert(token.is_non_zero(), Errors::TOKEN_ADDRESS_ZERO);
            let caller = starknet::get_caller_address();
            assert(
                self.ownable.owner() == caller
                    || (self.token_bound.read().is_zero() && caller == token),
                Errors::ONLY_OWNER_OR_TOKEN,
            );
            self.token_bound.write(token);
            self.emit(TokenBound { token });
        }

        /// NOTE: We dont need to receive token as parameter we can just read it from storage.
        fn unbind_token(ref self: ContractState, token: ContractAddress) {
            assert(token.is_non_zero(), Errors::TOKEN_ADDRESS_ZERO);
            let caller = starknet::get_caller_address();
            assert(self.ownable.owner() == caller || caller == token, Errors::ONLY_OWNER_OR_TOKEN);
            assert(self.token_bound.read() == token, Errors::TOKEN_NOT_BOUND);
            self.token_bound.write(Zero::zero());
            self.emit(TokenUnbound { token });
        }

        fn add_module(ref self: ContractState, module: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(module.is_non_zero(), Errors::MODULE_ADDRESS_ZERO);
            assert(!self.module_bound.entry(module).read(), Errors::MODULE_ALREADY_BOUND);
            let modules_storage_path = self.modules.deref();
            assert(modules_storage_path.len() < 25, Errors::MAX_MODULES_EXCEEDED);
            let module_dispatcher = IModuleDispatcher { contract_address: module };
            if !module_dispatcher.is_plug_and_play() {
                assert(
                    module_dispatcher.can_compliance_bind(starknet::get_contract_address()),
                    Errors::COMPLIANCE_CANNOT_BIND,
                );
            }

            module_dispatcher.bind_compliance(starknet::get_contract_address());
            modules_storage_path.append().write(module);
            self.module_bound.entry(module).write(true);
            self.emit(ModuleAdded { module });
        }

        fn remove_module(ref self: ContractState, module: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(module.is_non_zero(), Errors::MODULE_ADDRESS_ZERO);
            assert(self.module_bound.entry(module).read(), Errors::MODULE_NOT_BOUND);
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
            assert(self.module_bound.entry(module).read(), Errors::ONLY_BOUND_MODULE);
            starknet::syscalls::call_contract_syscall(module, selector, calldata).unwrap();
            self.emit(ModuleInteraction { target: module, selector });
        }

        fn transferred(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
        ) {
            self.assert_only_token();
            assert(from.is_non_zero() && to.is_non_zero(), Errors::ZERO_ADDRESS);
            assert(amount.is_non_zero(), Errors::NO_VALUE_TRANSFER);

            let modules_storage_path = self.modules.deref();
            for i in 0..modules_storage_path.len() {
                IModuleDispatcher { contract_address: modules_storage_path.at(i).read() }
                    .module_transfer_action(from, to, amount);
            };
        }

        fn created(ref self: ContractState, to: ContractAddress, amount: u256) {
            self.assert_only_token();
            assert(to.is_non_zero(), Errors::ZERO_ADDRESS);
            assert(amount.is_non_zero(), Errors::NO_VALUE_TRANSFER);

            let modules_storage_path = self.modules.deref();
            for i in 0..modules_storage_path.len() {
                IModuleDispatcher { contract_address: modules_storage_path.at(i).read() }
                    .module_mint_action(to, amount);
            };
        }

        fn destroyed(ref self: ContractState, from: ContractAddress, amount: u256) {
            self.assert_only_token();
            assert(from.is_non_zero(), Errors::ZERO_ADDRESS);
            assert(amount.is_non_zero(), Errors::NO_VALUE_TRANSFER);

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
            assert(
                starknet::get_caller_address() == self.token_bound.read(), Errors::ONLY_BOUND_TOKEN,
            );
        }
    }
}
