#[starknet::contract]
mod ImplementationAuthority {
    use core::num::traits::Zero;
    use crate::iimplementation_authority::{
        IImplementationAuthority, TREXImplementations, Version, VersionStorePacking,
    };
    use openzeppelin_access::ownable::{
        OwnableComponent, interface::{IOwnableDispatcher, IOwnableDispatcherTrait},
    };
    use openzeppelin_upgrades::interface::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};
    use registry::interface::iidentity_registry::{IIdentityRegistryDispatcherTrait};
    use starknet::{
        ClassHash, ContractAddress,
        storage::{Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess},
    };
    use token::itoken::{ITokenDispatcher, ITokenDispatcherTrait};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        current_version: Version,
        implementations: Map<u32, TREXImplementationsStore>,
        available_versions: Vec<u32>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[starknet::storage_node]
    pub struct TREXImplementationsStore {
        token_implementation: ClassHash,
        ctr_implementation: ClassHash,
        ir_implementation: ClassHash,
        irs_implementation: ClassHash,
        tir_implementation: ClassHash,
        mc_implementation: ClassHash,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TREXVersionAdded: TREXVersionAdded,
        VersionUpdated: VersionUpdated,
        TokenSuiteUpgraded: TokenSuiteUpgraded,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct TREXVersionAdded {
        #[key]
        version: Version,
        #[key]
        implementations: TREXImplementations,
    }

    #[derive(Drop, starknet::Event)]
    struct VersionUpdated {
        #[key]
        version: Version,
    }

    #[derive(Drop, starknet::Event)]
    struct TokenSuiteUpgraded {
        #[key]
        version: Version,
        #[key]
        token: ContractAddress,
    }

    pub mod Errors {
        pub const VERSION_ALREADY_EXISTS: felt252 = 'Version already exists';
        pub const VERSION_DOES_NOT_EXISTS: felt252 = 'Version does not exists';
        pub const VERSION_ALREADY_IN_USE: felt252 = 'Version already in use';
        pub const INVALID_IMPLEMENTATION: felt252 = 'Invalid implementation: Zero';
        pub const CALLER_NOT_OWNER_OF_SUITE: felt252 = 'Caller is not owner of suite';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        version: Version,
        implementations: TREXImplementations,
        owner: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self._add_trex_version(version, implementations);
        self._use_trex_version(version);
    }

    #[abi(embed_v0)]
    impl ImplementationAuthorityImpl of IImplementationAuthority<ContractState> {
        fn add_trex_version(
            ref self: ContractState, version: Version, implementations: TREXImplementations,
        ) {
            self.ownable.assert_only_owner();
            self._add_trex_version(version, implementations);
        }

        fn add_and_use_trex_version(
            ref self: ContractState, version: Version, implementations: TREXImplementations,
        ) {
            self.ownable.assert_only_owner();
            self._add_trex_version(version, implementations);
            self._use_trex_version(version);
        }

        fn use_trex_version(ref self: ContractState, version: Version) {
            self.ownable.assert_only_owner();
            self._use_trex_version(version);
        }

        fn upgrade_trex_suite(ref self: ContractState, token: ContractAddress, version: Version) {
            let caller = starknet::get_caller_address();
            let token_dispatcher = ITokenDispatcher { contract_address: token };
            let identity_registry = token_dispatcher.identity_registry();
            let modular_compliance = token_dispatcher.compliance();
            let identity_registry_storage = identity_registry.identity_storage();
            let trusted_issuers_registry = identity_registry.issuers_registry();
            let claim_topics_registry = identity_registry.topics_registry();
            assert(
                IOwnableDispatcher { contract_address: token }.owner() == caller
                    && IOwnableDispatcher { contract_address: identity_registry.contract_address }
                        .owner() == caller
                    && IOwnableDispatcher {
                        contract_address: identity_registry_storage.contract_address,
                    }
                        .owner() == caller
                    && IOwnableDispatcher { contract_address: modular_compliance.contract_address }
                        .owner() == caller
                    && IOwnableDispatcher {
                        contract_address: trusted_issuers_registry.contract_address,
                    }
                        .owner() == caller
                    && IOwnableDispatcher {
                        contract_address: claim_topics_registry.contract_address,
                    }
                        .owner() == caller,
                Errors::CALLER_NOT_OWNER_OF_SUITE,
            );
            let implementations_storage = self
                .implementations
                .entry(VersionStorePacking::pack(version))
                .deref();

            let token_implementation = implementations_storage.token_implementation.read();
            assert(token_implementation.is_non_zero(), Errors::VERSION_DOES_NOT_EXISTS);
            if starknet::syscalls::get_class_hash_at_syscall(token)
                .unwrap() != token_implementation {
                IUpgradeableDispatcher { contract_address: token }.upgrade(token_implementation);
            }

            let ir_implementation = implementations_storage.ir_implementation.read();
            if starknet::syscalls::get_class_hash_at_syscall(identity_registry.contract_address)
                .unwrap() == ir_implementation {
                IUpgradeableDispatcher { contract_address: identity_registry.contract_address }
                    .upgrade(ir_implementation);
            }

            let irs_implementation = implementations_storage.irs_implementation.read();
            if starknet::syscalls::get_class_hash_at_syscall(
                identity_registry_storage.contract_address,
            )
                .unwrap() == irs_implementation {
                IUpgradeableDispatcher {
                    contract_address: identity_registry_storage.contract_address,
                }
                    .upgrade(irs_implementation);
            }

            let ctr_implementation = implementations_storage.ctr_implementation.read();
            if starknet::syscalls::get_class_hash_at_syscall(claim_topics_registry.contract_address)
                .unwrap() == ctr_implementation {
                IUpgradeableDispatcher { contract_address: claim_topics_registry.contract_address }
                    .upgrade(ctr_implementation);
            }

            let tir_implementation = implementations_storage.tir_implementation.read();
            if starknet::syscalls::get_class_hash_at_syscall(
                trusted_issuers_registry.contract_address,
            )
                .unwrap() == tir_implementation {
                IUpgradeableDispatcher {
                    contract_address: trusted_issuers_registry.contract_address,
                }
                    .upgrade(tir_implementation);
            }

            let mc_implementation = implementations_storage.mc_implementation.read();
            if starknet::syscalls::get_class_hash_at_syscall(modular_compliance.contract_address)
                .unwrap() == mc_implementation {
                IUpgradeableDispatcher { contract_address: modular_compliance.contract_address }
                    .upgrade(mc_implementation);
            }

            self.emit(TokenSuiteUpgraded { version, token });
        }

        fn get_all_versions(self: @TContractState) -> Span<Version> {
            let mut versions = array![];
            for i in 0..self.available_versions.len() {
                versions.append(VersionStorePacking::unpack(self.available_versions.at(i).read()));
            }
            versions.span()
        }

        fn get_current_version(self: @ContractState) -> Version {
            self.current_version.read()
        }

        fn get_current_implementations(self: @ContractState) -> TREXImplementations {
            let implementations_storage = self
                .implementations
                .entry(VersionStorePacking::pack(self.current_version.read()))
                .deref();
            TREXImplementations {
                token_implementation: implementations_storage.token_implementation.read(),
                ctr_implementation: implementations_storage.ctr_implementation.read(),
                ir_implementation: implementations_storage.ir_implementation.read(),
                irs_implementation: implementations_storage.irs_implementation.read(),
                tir_implementation: implementations_storage.tir_implementation.read(),
                mc_implementation: implementations_storage.mc_implementation.read(),
            }
        }

        fn get_implementations(self: @ContractState, version: Version) -> TREXImplementations {
            let implementations_storage = self
                .implementations
                .entry(VersionStorePacking::pack(version))
                .deref();
            TREXImplementations {
                token_implementation: implementations_storage.token_implementation.read(),
                ctr_implementation: implementations_storage.ctr_implementation.read(),
                ir_implementation: implementations_storage.ir_implementation.read(),
                irs_implementation: implementations_storage.irs_implementation.read(),
                tir_implementation: implementations_storage.tir_implementation.read(),
                mc_implementation: implementations_storage.mc_implementation.read(),
            }
        }

        fn get_token_implementation(self: @ContractState) -> ClassHash {
            let current_version = self.current_version.read();
            self
                .implementations
                .entry(VersionStorePacking::pack(current_version))
                .token_implementation
                .read()
        }

        fn get_ctr_implementation(self: @ContractState) -> ClassHash {
            let current_version = self.current_version.read();
            self
                .implementations
                .entry(VersionStorePacking::pack(current_version))
                .ctr_implementation
                .read()
        }

        fn get_ir_implementation(self: @ContractState) -> ClassHash {
            let current_version = self.current_version.read();
            self
                .implementations
                .entry(VersionStorePacking::pack(current_version))
                .ir_implementation
                .read()
        }

        fn get_irs_implementation(self: @ContractState) -> ClassHash {
            let current_version = self.current_version.read();
            self
                .implementations
                .entry(VersionStorePacking::pack(current_version))
                .irs_implementation
                .read()
        }

        fn get_tir_implementation(self: @ContractState) -> ClassHash {
            let current_version = self.current_version.read();
            self
                .implementations
                .entry(VersionStorePacking::pack(current_version))
                .tir_implementation
                .read()
        }

        fn get_mc_implementation(self: @ContractState) -> ClassHash {
            let current_version = self.current_version.read();
            self
                .implementations
                .entry(VersionStorePacking::pack(current_version))
                .mc_implementation
                .read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _add_trex_version(
            ref self: ContractState, version: Version, implementations: TREXImplementations,
        ) {
            let version_key = VersionStorePacking::pack(version);
            let implementation_storage = self.implementations.entry(version_key);
            assert(
                implementation_storage.token_implementation.read().is_zero(),
                Errors::VERSION_ALREADY_EXISTS,
            );
            assert(
                implementations.ctr_implementation.is_non_zero()
                    && implementations.ir_implementation.is_non_zero()
                    && implementations.irs_implementation.is_non_zero()
                    && implementations.tir_implementation.is_non_zero()
                    && implementations.mc_implementation.is_non_zero()
                    && implementations.token_implementation.is_non_zero(),
                Errors::INVALID_IMPLEMENTATION,
            );
            implementation_storage.token_implementation.write(implementations.token_implementation);
            implementation_storage.ctr_implementation.write(implementations.ctr_implementation);
            implementation_storage.ir_implementation.write(implementations.ir_implementation);
            implementation_storage.irs_implementation.write(implementations.irs_implementation);
            implementation_storage.tir_implementation.write(implementations.tir_implementation);
            implementation_storage.mc_implementation.write(implementations.mc_implementation);
            self.available_versions.append(version_key);
            self.emit(TREXVersionAdded { version, implementations });
        }

        fn _use_trex_version(ref self: ContractState, version: Version) {
            assert(
                self
                    .implementations
                    .entry(VersionStorePacking::pack(version))
                    .token_implementation
                    .read()
                    .is_non_zero(),
                Errors::VERSION_DOES_NOT_EXISTS,
            );
            assert(self.current_version.read() != version, Errors::VERSION_ALREADY_IN_USE);
            self.current_version.write(version);
            self.emit(VersionUpdated { version });
        }
    }
}
