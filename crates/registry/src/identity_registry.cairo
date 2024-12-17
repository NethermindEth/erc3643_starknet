#[starknet::contract]
pub mod IdentityRegistry {
    use core::num::traits::Zero;
    use core::poseidon::poseidon_hash_span;
    use crate::interface::{
        iclaim_topics_registry::{
            IClaimTopicsRegistryDispatcher, IClaimTopicsRegistryDispatcherTrait,
        },
        iidentity_registry::IIdentityRegistry,
        iidentity_registry_storage::{
            IIdentityRegistryStorageDispatcher, IIdentityRegistryStorageDispatcherTrait,
        },
        itrusted_issuers_registry::{
            ITrustedIssuersRegistryDispatcher, ITrustedIssuersRegistryDispatcherTrait,
        },
    };
    use onchain_id::{
        iclaim_issuer::{ClaimIssuerABIDispatcher, ClaimIssuerABIDispatcherTrait},
        iidentity::{IdentityABIDispatcher, IdentityABIDispatcherTrait},
    };
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use roles::agent_role::AgentRoleComponent;
    use starknet::{
        ClassHash, ContractAddress, storage::{StoragePointerReadAccess, StoragePointerWriteAccess},
    };

    component!(path: UpgradeableComponent, storage: upgrades, event: UpgradeableEvent);

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    component!(path: AgentRoleComponent, storage: agent_role, event: AgentRoleEvent);

    #[abi(embed_v0)]
    impl AgentRoleImpl = AgentRoleComponent::AgentRoleImpl<ContractState>;
    impl AgentRoleInternalImpl = AgentRoleComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        token_topics_registry: IClaimTopicsRegistryDispatcher,
        token_issuers_registry: ITrustedIssuersRegistryDispatcher,
        token_identity_storage: IIdentityRegistryStorageDispatcher,
        #[substorage(v0)]
        upgrades: UpgradeableComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        agent_role: AgentRoleComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ClaimTopicsRegistrySet: ClaimTopicsRegistrySet,
        IdentityStorageSet: IdentityStorageSet,
        TrustedIssuersRegistrySet: TrustedIssuersRegistrySet,
        IdentityRegistered: IdentityRegistered,
        IdentityRemoved: IdentityRemoved,
        IdentityUpdated: IdentityUpdated,
        CountryUpdated: CountryUpdated,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        AgentRoleEvent: AgentRoleComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ClaimTopicsRegistrySet {
        #[key]
        pub claim_topics_registry: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IdentityStorageSet {
        #[key]
        pub identity_storage: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TrustedIssuersRegistrySet {
        #[key]
        pub trusted_issuers_registry: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IdentityRegistered {
        #[key]
        pub investor_address: ContractAddress,
        #[key]
        pub identity: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IdentityRemoved {
        #[key]
        pub investor_address: ContractAddress,
        #[key]
        pub identity: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IdentityUpdated {
        #[key]
        pub old_identity: ContractAddress,
        #[key]
        pub new_identity: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CountryUpdated {
        #[key]
        pub investor_address: ContractAddress,
        #[key]
        pub country: u16,
    }

    pub mod Errors {
        pub const TRUSTED_ISSUERS_REGISTRY_ADDRESS_ZERO: felt252 = 'Zero Address: TIR';
        pub const CLAIM_TOPICS_REGISTRY_ADDRESS_ZERO: felt252 = 'Zero Address: CTR';
        pub const IDENTITY_STORAGE_ADDRESS_ZERO: felt252 = 'Zero Address: IRS';
        pub const OWNER_ADDRESS_ZERO: felt252 = 'Zero Address: Owner';
        pub const ARRAY_LEN_MISMATCH: felt252 = 'Arrays lenghts not equal';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        trusted_issuers_registry: ContractAddress,
        claim_topics_registry: ContractAddress,
        identity_storage: ContractAddress,
        owner: ContractAddress,
    ) {
        assert(
            trusted_issuers_registry.is_non_zero(), Errors::TRUSTED_ISSUERS_REGISTRY_ADDRESS_ZERO,
        );
        assert(claim_topics_registry.is_non_zero(), Errors::CLAIM_TOPICS_REGISTRY_ADDRESS_ZERO);
        assert(identity_storage.is_non_zero(), Errors::IDENTITY_STORAGE_ADDRESS_ZERO);
        assert(owner.is_non_zero(), Errors::OWNER_ADDRESS_ZERO);
        self
            .token_topics_registry
            .write(IClaimTopicsRegistryDispatcher { contract_address: claim_topics_registry });
        self
            .token_issuers_registry
            .write(
                ITrustedIssuersRegistryDispatcher { contract_address: trusted_issuers_registry },
            );
        self
            .token_identity_storage
            .write(IIdentityRegistryStorageDispatcher { contract_address: identity_storage });
        self.ownable.initializer(owner);
        self.emit(ClaimTopicsRegistrySet { claim_topics_registry });
        self.emit(TrustedIssuersRegistrySet { trusted_issuers_registry });
        self.emit(IdentityStorageSet { identity_storage });
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
    #[abi(embed_v0)]
    impl IdentityRegistryImpl of IIdentityRegistry<ContractState> {
        fn register_identity(
            ref self: ContractState,
            user_address: ContractAddress,
            identity: ContractAddress,
            country: u16,
        ) {
            self.agent_role.assert_only_agent();
            self
                .token_identity_storage
                .read()
                .add_identity_to_storage(user_address, identity, country);
            self.emit(IdentityRegistered { investor_address: user_address, identity });
        }

        fn delete_identity(ref self: ContractState, user_address: ContractAddress) {
            self.agent_role.assert_only_agent();
            let old_identity = self.identity(user_address);
            self.token_identity_storage.read().remove_identity_from_storage(user_address);
            self.emit(IdentityRemoved { investor_address: user_address, identity: old_identity });
        }

        fn set_identity_registry_storage(
            ref self: ContractState, identity_registry_storage: ContractAddress,
        ) {
            self.ownable.assert_only_owner();
            self
                .token_identity_storage
                .write(
                    IIdentityRegistryStorageDispatcher {
                        contract_address: identity_registry_storage,
                    },
                );
            self.emit(IdentityStorageSet { identity_storage: identity_registry_storage });
        }

        fn set_claim_topics_registry(
            ref self: ContractState, claim_topics_registry: ContractAddress,
        ) {
            self.ownable.assert_only_owner();
            self
                .token_topics_registry
                .write(IClaimTopicsRegistryDispatcher { contract_address: claim_topics_registry });
            self.emit(ClaimTopicsRegistrySet { claim_topics_registry });
        }

        fn set_trusted_issuers_registry(
            ref self: ContractState, trusted_issuers_registry: ContractAddress,
        ) {
            self.ownable.assert_only_owner();
            self
                .token_issuers_registry
                .write(
                    ITrustedIssuersRegistryDispatcher {
                        contract_address: trusted_issuers_registry,
                    },
                );
            self.emit(TrustedIssuersRegistrySet { trusted_issuers_registry });
        }

        fn update_country(ref self: ContractState, user_address: ContractAddress, country: u16) {
            self.agent_role.assert_only_agent();
            self
                .token_identity_storage
                .read()
                .modify_stored_investor_country(user_address, country);
            self.emit(CountryUpdated { investor_address: user_address, country });
        }

        fn update_identity(
            ref self: ContractState, user_address: ContractAddress, identity: ContractAddress,
        ) {
            self.agent_role.assert_only_agent();
            let old_identity = self.identity(user_address);
            self.token_identity_storage.read().modify_stored_identity(user_address, identity);
            self.emit(IdentityUpdated { old_identity, new_identity: identity });
        }

        fn batch_register_identity(
            ref self: ContractState,
            user_addresses: Span<ContractAddress>,
            identities: Span<ContractAddress>,
            countries: Span<u16>,
        ) {
            self.agent_role.assert_only_agent();
            let identity_registry_storage_dispatcher = self.token_identity_storage.read();
            assert(
                user_addresses.len() == identities.len() && identities.len() == countries.len(),
                Errors::ARRAY_LEN_MISMATCH,
            );

            for i in 0..user_addresses.len() {
                let investor_address = *user_addresses.at(i);
                let identity = *identities.at(i);
                let country = *countries.at(i);
                identity_registry_storage_dispatcher
                    .add_identity_to_storage(investor_address, identity, country);
                self.emit(IdentityRegistered { investor_address, identity });
            };
        }

        fn contains(self: @ContractState, user_address: ContractAddress) -> bool {
            self.identity(user_address).is_non_zero()
        }

        fn is_verified(self: @ContractState, user_address: ContractAddress) -> bool {
            let identity = self.identity(user_address);
            if identity.is_zero() {
                return false;
            }

            let required_claim_topics = self.token_topics_registry.read().get_claim_topics();

            if required_claim_topics.len().is_zero() {
                return true;
            }

            let mut verified = true;

            for claim_topic in required_claim_topics {
                let trusted_issuers = self
                    .token_issuers_registry
                    .read()
                    .get_trusted_issuers_for_claim_topic(claim_topic);

                if trusted_issuers.len().is_zero() {
                    verified = false;
                    break;
                }

                let mut claim_ids = array![];
                for trusted_issuer in trusted_issuers {
                    claim_ids
                        .append(
                            poseidon_hash_span(
                                array![(*trusted_issuer).into(), claim_topic].span(),
                            ),
                        );
                };

                let claim_ids_len = claim_ids.len();
                let mut i = 0;
                verified =
                    loop {
                        /// trusted_issuers.is_non_zero() assertion guarantees that claim_ids_len >
                        /// 0, thus this loop does not need to check i < claim_len and i ==
                        /// claim_ids_len - 1 check is enough to ensure boundaries.
                        let (found_claim_topic, _, issuer, sig, data, _) = IdentityABIDispatcher {
                            contract_address: identity,
                        }
                            .get_claim(*claim_ids.at(i));

                        if found_claim_topic == claim_topic {
                            let is_valid_claim = ClaimIssuerABIDispatcher {
                                contract_address: issuer,
                            }
                                .is_claim_valid(identity, claim_topic, sig, data);
                            if is_valid_claim {
                                break true;
                            }
                        }

                        if i == claim_ids_len - 1 {
                            break false;
                        }

                        i += 1;
                    };

                if !verified {
                    break;
                }
            };
            verified
        }

        fn identity(self: @ContractState, user_address: ContractAddress) -> ContractAddress {
            self.token_identity_storage.read().stored_identity(user_address)
        }

        fn investor_country(self: @ContractState, user_address: ContractAddress) -> u16 {
            self.token_identity_storage.read().stored_investor_country(user_address)
        }

        fn identity_storage(self: @ContractState) -> IIdentityRegistryStorageDispatcher {
            self.token_identity_storage.read()
        }

        fn issuers_registry(self: @ContractState) -> ITrustedIssuersRegistryDispatcher {
            self.token_issuers_registry.read()
        }

        fn topics_registry(self: @ContractState) -> IClaimTopicsRegistryDispatcher {
            self.token_topics_registry.read()
        }
    }
}

