#[starknet::contract]
pub mod TrustedIssuersRegistry {
    use core::num::traits::Zero;
    use crate::interface::itrusted_issuers_registry::ITrustedIssuersRegistry;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use starknet::{
        ClassHash, ContractAddress,
        storage::{Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess},
    };
    use storage::storage_array::{
        ContractAddressVecToContractAddressArray as ContractAddressVecInto,
        Felt252VecToFelt252Array as FeltVecInto, MutableStorageArrayTrait,
        StorageArrayContractAddress, StorageArrayFelt252, StorageArrayTrait,
    };

    component!(path: UpgradeableComponent, storage: upgrades, event: UpgradeableEvent);

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        trusted_issuers: StorageArrayContractAddress,
        trusted_issuer_claim_topics: Map<ContractAddress, StorageArrayFelt252>,
        claim_topics_to_trusted_issuers: Map<felt252, StorageArrayContractAddress>,
        implementation_authority: ContractAddress,
        #[substorage(v0)]
        upgrades: UpgradeableComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TrustedIssuerAdded: TrustedIssuerAdded,
        TrustedIssuerRemoved: TrustedIssuerRemoved,
        ClaimTopicsUpdated: ClaimTopicsUpdated,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TrustedIssuerAdded {
        #[key]
        pub trusted_issuer: ContractAddress,
        pub claim_topics: Span<felt252>,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TrustedIssuerRemoved {
        #[key]
        pub trusted_issuer: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ClaimTopicsUpdated {
        #[key]
        pub trusted_issuer: ContractAddress,
        pub claim_topics: Span<felt252>,
    }

    pub mod Errors {
        pub const ZERO_ADDRESS: felt252 = 'Zero Address: Trusted Issuer';
        pub const EMPTY_CLAIM_TOPICS: felt252 = 'Claim topics cannot be empty';
        pub const MAX_CLAIM_TOPICS_EXCEEDED: felt252 = 'Max 15 claim topics';
        pub const MAX_TRUSTED_ISSUERS_EXCEEDED: felt252 = 'Max 50 trusted issuers';
        pub const TRUSTED_ISSUER_ALREADY_EXISTS: felt252 = 'Trusted Issuer already exists';
        pub const TRUSTED_ISSUER_DOES_NOT_EXISTS: felt252 = 'Trusted Issuer not exists';
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
    impl TrustedIssuersRegistryImpl of ITrustedIssuersRegistry<ContractState> {
        fn add_trusted_issuer(
            ref self: ContractState, trusted_issuer: ContractAddress, claim_topics: Span<felt252>,
        ) {
            self.ownable.assert_only_owner();
            assert(trusted_issuer.is_non_zero(), Errors::ZERO_ADDRESS);
            let claim_topics_len = claim_topics.len();
            assert(claim_topics_len.is_non_zero(), Errors::EMPTY_CLAIM_TOPICS);
            assert(claim_topics_len <= 15, Errors::MAX_CLAIM_TOPICS_EXCEEDED);

            let trusted_issuer_claim_topics_storage_path = self
                .trusted_issuer_claim_topics
                .entry(trusted_issuer);
            assert(
                trusted_issuer_claim_topics_storage_path.len().is_zero(),
                Errors::TRUSTED_ISSUER_ALREADY_EXISTS,
            );

            let trusted_issuers_storage_path = self.trusted_issuers.deref();
            assert(trusted_issuers_storage_path.len() < 50, Errors::MAX_TRUSTED_ISSUERS_EXCEEDED);
            trusted_issuers_storage_path.append().write(trusted_issuer);

            for claim_topic in claim_topics {
                trusted_issuer_claim_topics_storage_path.append().write(*claim_topic);
                self
                    .claim_topics_to_trusted_issuers
                    .entry(*claim_topic)
                    .append()
                    .write(trusted_issuer);
            };

            self.emit(TrustedIssuerAdded { trusted_issuer, claim_topics })
        }

        fn remove_trusted_issuer(ref self: ContractState, trusted_issuer: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(trusted_issuer.is_non_zero(), Errors::ZERO_ADDRESS);
            let claim_topics_storage_path = self.trusted_issuer_claim_topics.entry(trusted_issuer);
            assert(
                claim_topics_storage_path.len().is_non_zero(),
                Errors::TRUSTED_ISSUER_DOES_NOT_EXISTS,
            );

            /// Remove from trusted issuers vec
            let trusted_issuers_storage_path = self.trusted_issuers.deref();
            for i in 0..trusted_issuers_storage_path.len() {
                if trusted_issuers_storage_path.at(i).read() == trusted_issuer {
                    trusted_issuers_storage_path.delete(i);
                    break;
                }
            };

            /// Clear claim topics to trusted issuers
            for i in 0..claim_topics_storage_path.len() {
                let claim_topic = claim_topics_storage_path.at(i).read();
                let claim_topic_trusted_issuers = self
                    .claim_topics_to_trusted_issuers
                    .entry(claim_topic);
                for j in 0..claim_topic_trusted_issuers.len() {
                    let trusted_issuer_at_j = claim_topic_trusted_issuers.at(j).read();
                    if trusted_issuer_at_j == trusted_issuer {
                        claim_topic_trusted_issuers.delete(j);
                        break;
                    }
                };
            };

            /// Clear trusted issuer claim topics
            /// .clear() method leaves the storage dirty and just set len to 0.
            self.trusted_issuer_claim_topics.entry(trusted_issuer).clear();
            self.emit(TrustedIssuerRemoved { trusted_issuer });
        }

        /// NOTE: This method first clears all the claim topics and related data then populates
        /// again with newer data. inefficient for unchanging data.
        fn update_issuer_claim_topics(
            ref self: ContractState, trusted_issuer: ContractAddress, claim_topics: Span<felt252>,
        ) {
            self.ownable.assert_only_owner();
            assert(trusted_issuer.is_non_zero(), Errors::ZERO_ADDRESS);
            let claim_topics_len = claim_topics.len();
            assert(claim_topics_len.is_non_zero(), Errors::EMPTY_CLAIM_TOPICS);
            assert(claim_topics_len <= 15, Errors::MAX_CLAIM_TOPICS_EXCEEDED);
            let claim_topics_storage_path = self.trusted_issuer_claim_topics.entry(trusted_issuer);
            assert(
                claim_topics_storage_path.len().is_non_zero(),
                Errors::TRUSTED_ISSUER_DOES_NOT_EXISTS,
            );

            let claim_topics_storage_path = self.trusted_issuer_claim_topics.entry(trusted_issuer);
            /// Deletes claim topics to
            for i in 0..claim_topics_storage_path.len() {
                let claim_topic = claim_topics_storage_path.at(i).read();
                let claim_topic_trusted_issuers = self
                    .claim_topics_to_trusted_issuers
                    .entry(claim_topic);
                for j in 0..claim_topic_trusted_issuers.len() {
                    if claim_topic_trusted_issuers.at(j).read() == trusted_issuer {
                        claim_topic_trusted_issuers.delete(i);
                        break;
                    }
                };
            };

            claim_topics_storage_path.clear();
            /// Update trusted_issuer_claim_topics and claim_topics_to_trusted_issuers
            for claim_topic in claim_topics {
                claim_topics_storage_path.append().write(*claim_topic);
                self
                    .claim_topics_to_trusted_issuers
                    .entry(*claim_topic)
                    .append()
                    .write(trusted_issuer);
            };

            self.emit(ClaimTopicsUpdated { trusted_issuer, claim_topics });
        }

        fn has_claim_topic(
            self: @ContractState, issuer: ContractAddress, claim_topic: felt252,
        ) -> bool {
            let mut has_topic = false;
            let claim_topics_storage_path = self.trusted_issuer_claim_topics.entry(issuer);
            for i in 0..claim_topics_storage_path.len() {
                if claim_topics_storage_path.at(i).read() == claim_topic {
                    has_topic = true;
                    break;
                }
            };
            has_topic
        }

        fn is_trusted_issuer(self: @ContractState, issuer: ContractAddress) -> bool {
            self.trusted_issuer_claim_topics.entry(issuer).len().is_non_zero()
        }

        fn get_trusted_issuers(self: @ContractState) -> Span<ContractAddress> {
            ContractAddressVecInto::into(self.trusted_issuers.deref()).span()
        }

        fn get_trusted_issuers_for_claim_topic(
            self: @ContractState, claim_topic: felt252,
        ) -> Span<ContractAddress> {
            ContractAddressVecInto::into(self.claim_topics_to_trusted_issuers.entry(claim_topic))
                .span()
        }

        fn get_trusted_issuer_claim_topics(
            self: @ContractState, trusted_issuer: ContractAddress,
        ) -> Span<felt252> {
            let claim_topics_storage_path = self.trusted_issuer_claim_topics.entry(trusted_issuer);
            assert(
                claim_topics_storage_path.len().is_non_zero(),
                Errors::TRUSTED_ISSUER_DOES_NOT_EXISTS,
            );
            FeltVecInto::into(claim_topics_storage_path).span()
        }
    }
}
