#[starknet::contract]
pub mod ClaimTopicsRegistry {
    use crate::interface::iclaim_topics_registry::IClaimTopicsRegistry;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use starknet::{
        ClassHash, ContractAddress, storage::{StoragePointerReadAccess, StoragePointerWriteAccess},
    };
    use storage::storage_array::{
        Felt252VecToFelt252Array, MutableStorageArrayTrait, StorageArrayFelt252,
    };

    component!(path: UpgradeableComponent, storage: upgrades, event: UpgradeableEvent);

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        claim_topics: StorageArrayFelt252,
        implementation_authority: ContractAddress,
        #[substorage(v0)]
        upgrades: UpgradeableComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ClaimTopicAdded: ClaimTopicAdded,
        ClaimTopicRemoved: ClaimTopicRemoved,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ClaimTopicAdded {
        #[key]
        pub claim_topic: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ClaimTopicRemoved {
        #[key]
        pub claim_topic: felt252,
    }

    pub mod Errors {
        pub const MAX_CLAIM_TOPICS_EXCEEDED: felt252 = 'Max 15 claim topics exceeded';
        pub const CLAIM_TOPIC_ALREADY_EXIST: felt252 = 'Claim topic already exist';
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
    impl ClaimTopicsRegistryImpl of IClaimTopicsRegistry<ContractState> {
        fn add_claim_topic(ref self: ContractState, claim_topic: felt252) {
            self.ownable.assert_only_owner();
            let claim_topics_storge_path = self.claim_topics.deref();
            let claim_topics_len = claim_topics_storge_path.len();

            assert(claim_topics_len < 15, Errors::MAX_CLAIM_TOPICS_EXCEEDED);
            for i in 0..claim_topics_len {
                assert(
                    claim_topics_storge_path.at(i).read() != claim_topic,
                    Errors::CLAIM_TOPIC_ALREADY_EXIST,
                );
            };
            claim_topics_storge_path.append().write(claim_topic);
            self.emit(ClaimTopicAdded { claim_topic });
        }
        /// NOTE: If topics does not exists does nothing. Might consider panicking
        fn remove_claim_topic(ref self: ContractState, claim_topic: felt252) {
            self.ownable.assert_only_owner();

            let claim_topics_storge_path = self.claim_topics.deref();
            for i in 0..claim_topics_storge_path.len() {
                if claim_topics_storge_path.at(i).read() == claim_topic {
                    claim_topics_storge_path.delete(i);
                    self.emit(ClaimTopicRemoved { claim_topic });
                    break;
                }
            };
        }

        fn get_claim_topics(self: @ContractState) -> Span<felt252> {
            Felt252VecToFelt252Array::into(self.claim_topics.deref()).span()
        }
    }
}
