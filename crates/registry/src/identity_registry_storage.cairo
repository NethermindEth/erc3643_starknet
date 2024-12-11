#[starknet::contract]
mod IdentityRegistryStorage {
    use core::num::traits::Zero;
    use crate::interface::iidentity_registry_storage::IIdentityRegistryStorage;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use roles::agent_role::AgentRoleComponent;
    use starknet::{
        ClassHash, ContractAddress,
        storage::{Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess},
    };
    use storage::storage_array::{
        ContractAddressVecToContractAddressArray, MutableStorageArrayTrait,
        StorageArrayContractAddress,
    };

    component!(path: UpgradeableComponent, storage: upgrades, event: UpgradeableEvent);

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    component!(path: AgentRoleComponent, storage: agent_role, event: AgentRoleEvent);

    #[abi(embed_v0)]
    impl AgentRoleImpl = AgentRoleComponent::AgentRole<ContractState>;
    impl AgentRoleInternalImpl = AgentRoleComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        identities: Map<ContractAddress, Identity>,
        identity_registries: StorageArrayContractAddress,
        #[substorage(v0)]
        upgrades: UpgradeableComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        agent_role: AgentRoleComponent::Storage,
    }

    #[starknet::storage_node]
    pub struct Identity {
        identity_contract: ContractAddress,
        investor_country: u16,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        IdentityStored: IdentityStored,
        IdentityUnstored: IdentityUnstored,
        IdentityModified: IdentityModified,
        CountryModified: CountryModified,
        IdentityRegistryBound: IdentityRegistryBound,
        IdentityRegistryUnbound: IdentityRegistryUnbound,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        AgentRoleEvent: AgentRoleComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct IdentityStored {
        #[key]
        investor_address: ContractAddress,
        #[key]
        identity: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct IdentityUnstored {
        #[key]
        investor_address: ContractAddress,
        #[key]
        identity: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct IdentityModified {
        #[key]
        old_identity: ContractAddress,
        #[key]
        new_identity: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct CountryModified {
        #[key]
        investor_address: ContractAddress,
        #[key]
        country: u16,
    }

    #[derive(Drop, starknet::Event)]
    struct IdentityRegistryBound {
        #[key]
        identity_registry: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct IdentityRegistryUnbound {
        #[key]
        identity_registry: ContractAddress,
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

    #[abi(embed_v0)]
    impl IdentityRegistryStorageImpl of IIdentityRegistryStorage<ContractState> {
        fn add_identity_to_storage(
            ref self: ContractState,
            user_address: ContractAddress,
            identity: ContractAddress,
            country: u16,
        ) {
            self.agent_role.assert_only_agent();
            assert(user_address.is_non_zero() && identity.is_non_zero(), 'Zero Address');
            let identity_storage_path = self.identities.entry(user_address).deref();
            assert(
                identity_storage_path.identity_contract.read().is_zero(), 'Identity already stored',
            );
            identity_storage_path.identity_contract.write(identity);
            identity_storage_path.investor_country.write(country);
            self.emit(IdentityStored { investor_address: user_address, identity });
        }

        fn remove_identity_from_storage(ref self: ContractState, user_address: ContractAddress) {
            self.agent_role.assert_only_agent();
            assert(user_address.is_non_zero(), 'Zero Address');
            let identity_storage_path = self.identities.entry(user_address).deref();
            let old_identity = identity_storage_path.identity_contract.read();
            assert(old_identity.is_non_zero(), 'Identity not stored yet');
            identity_storage_path.identity_contract.write(Zero::zero());
            identity_storage_path.investor_country.write(Zero::zero());
            self.emit(IdentityUnstored { investor_address: user_address, identity: old_identity });
        }

        fn modify_stored_investor_country(
            ref self: ContractState, user_address: ContractAddress, country: u16,
        ) {
            self.agent_role.assert_only_agent();
            assert(user_address.is_non_zero(), 'Zero Address');
            let identity_storage_path = self.identities.entry(user_address).deref();
            assert(
                identity_storage_path.identity_contract.read().is_non_zero(),
                'Identity not stored yet',
            );
            identity_storage_path.investor_country.write(country);
            self.emit(CountryModified { investor_address: user_address, country });
        }

        fn modify_stored_identity(
            ref self: ContractState, user_address: ContractAddress, identity: ContractAddress,
        ) {
            self.agent_role.assert_only_agent();
            assert(user_address.is_non_zero() && identity.is_non_zero(), 'Zero Address');
            let identity_contract_storage_path = self
                .identities
                .entry(user_address)
                .identity_contract
                .deref();
            let old_identity = identity_contract_storage_path.read();
            assert(old_identity.is_non_zero(), 'Identity not stored yet');
            identity_contract_storage_path.write(identity);
            self.emit(IdentityModified { old_identity, new_identity: identity });
        }

        /// Only callable by the owner, add agent method asserts only owner.
        fn bind_identity_registry(ref self: ContractState, identity_registry: ContractAddress) {
            assert(identity_registry.is_non_zero(), 'Zero Address');
            let identity_registries = self.identity_registries.deref();
            assert(identity_registries.len() < 300, 'Cannot bind more than 300 IR');
            assert(!self.agent_role.is_agent(identity_registry), 'IR already binded');
            identity_registries.append().write(identity_registry);
            self.agent_role.add_agent(identity_registry);
            self.emit(IdentityRegistryBound { identity_registry });
        }

        /// Only callable by the owner, add agent method asserts only owner.
        fn unbind_identity_registry(ref self: ContractState, identity_registry: ContractAddress) {
            assert(identity_registry.is_non_zero(), 'Zero Address');
            let identity_registries = self.identity_registries.deref();
            assert(self.agent_role.is_agent(identity_registry), 'Identity registry not binded');
            for i in 0..identity_registries.len() {
                if identity_registries.at(i).read() == identity_registry {
                    identity_registries.delete(i);
                    self.agent_role.remove_agent(identity_registry);
                    self.emit(IdentityRegistryUnbound { identity_registry });
                    break;
                }
            };
        }

        fn linked_identity_registries(self: @ContractState) -> Span<ContractAddress> {
            let irs: Array<ContractAddress> = self.identity_registries.deref().into();
            irs.span()
        }

        fn stored_identity(self: @ContractState, user_address: ContractAddress) -> ContractAddress {
            self.identities.entry(user_address).identity_contract.read()
        }

        fn stored_investor_country(self: @ContractState, user_address: ContractAddress) -> u16 {
            self.identities.entry(user_address).investor_country.read()
        }
    }
}
