#[starknet::contract]
mod OwnerManager {
    use core::poseidon::poseidon_hash_span;
    use crate::{
        OwnerRoles, agent_role::{IAgentRoleDispatcher, IAgentRoleDispatcherTrait},
        owner::iowner_manager::IOwnerManager
    };
    use onchain_id::iidentity::{IdentityABIDispatcher, IdentityABIDispatcherTrait};
    use openzeppelin_access::{
        accesscontrol::AccessControlComponent,
        ownable::{OwnableComponent, interface::{IOwnableDispatcher, IOwnableDispatcherTrait}}
    };
    use openzeppelin_introspection::src5::SRC5Component;
    use registry::interface::{
        iidentity_registry::IIdentityRegistryDispatcherTrait,
        iclaim_topics_registry::IClaimTopicsRegistryDispatcherTrait,
        itrusted_issuers_registry::ITrustedIssuersRegistryDispatcherTrait
    };
    use starknet::{storage::{StoragePointerReadAccess, StoragePointerWriteAccess}, ContractAddress};
    use token::itoken::{ITokenDispatcher, ITokenDispatcherTrait};

    // Ownable Component
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // SRC5 Component
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    // Access Control Component
    component!(path: AccessControlComponent, storage: access, event: AccessControlEvent);

    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        token: ITokenDispatcher,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        access: AccessControlComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ComplianceInteraction: ComplianceInteraction,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }

    #[derive(Drop, starknet::Event)]
    struct ComplianceInteraction {
        #[key]
        target: ContractAddress,
        selector: felt252
    }

    pub mod Errors {
        pub const CALLER_NOT_MANAGEMENT_KEY: felt252 = 'Caller is not management key';
        pub const NOT_REGISTRY_ADDRESS_SETTER: felt252 = 'oid not registry address setter';
        pub const NOT_COMPLIANCE_SETTER: felt252 = 'oid is not compliance setter';
        pub const NOT_COMPLIANCE_MANAGER: felt252 = 'oid is not compliance manager';
        pub const NOT_CLAIM_REGISTRY_MANAGER: felt252 = 'oid not claim registry manager';
        pub const NOT_ISSUERS_REGISTRY_MANAGER: felt252 = 'oid not issuer registry manager';
        pub const NOT_TOKEN_INFO_MANAGER: felt252 = 'oid not token info manager';
    }

    #[constructor]
    fn constructor(ref self: ContractState, token: ContractAddress, owner: ContractAddress) {
        self.token.write(ITokenDispatcher { contract_address: token });
        // NOTE: might remove ownable.
        self.ownable.initializer(owner);
        self.access.initializer();
        self.access.set_role_admin(OwnerRoles::REGISTRY_ADDRESS_SETTER, OwnerRoles::OWNER_ADMIN);
        self.access.set_role_admin(OwnerRoles::COMPLIANCE_SETTER, OwnerRoles::OWNER_ADMIN);
        self.access.set_role_admin(OwnerRoles::COMPLIANCE_MANAGER, OwnerRoles::OWNER_ADMIN);
        self.access.set_role_admin(OwnerRoles::CLAIM_REGISTRY_MANAGER, OwnerRoles::OWNER_ADMIN);
        self.access.set_role_admin(OwnerRoles::ISSUERS_REGISTRY_MANAGER, OwnerRoles::OWNER_ADMIN);
        self.access.set_role_admin(OwnerRoles::TOKEN_INFO_MANAGER, OwnerRoles::OWNER_ADMIN);
        self.access.set_role_admin(OwnerRoles::OWNER_ADMIN, OwnerRoles::OWNER_ADMIN);
        self.access._grant_role(OwnerRoles::OWNER_ADMIN, owner);
    }

    #[abi(embed_v0)]
    impl OwnerRolesImpl of IOwnerManager<ContractState> {
        fn call_set_identity_registry(
            ref self: ContractState,
            identity_registry: ContractAddress,
            onchain_id: ContractAddress,
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(
                self.access.has_role(OwnerRoles::REGISTRY_ADDRESS_SETTER, onchain_id),
                Errors::NOT_REGISTRY_ADDRESS_SETTER
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2
                    ),
                Errors::CALLER_NOT_MANAGEMENT_KEY
            );
            self.token.read().set_identity_registry(identity_registry);
        }

        fn call_set_compliance(
            ref self: ContractState, compliance: ContractAddress, onchain_id: ContractAddress
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(
                self.access.has_role(OwnerRoles::COMPLIANCE_SETTER, onchain_id),
                Errors::NOT_COMPLIANCE_SETTER
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2
                    ),
                Errors::CALLER_NOT_MANAGEMENT_KEY
            );
            self.token.read().set_compliance(compliance);
        }

        fn call_compliance_function(
            ref self: ContractState,
            selector: felt252,
            calldata: Span<felt252>,
            onchain_id: ContractAddress
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(
                self.access.has_role(OwnerRoles::COMPLIANCE_MANAGER, onchain_id),
                Errors::NOT_COMPLIANCE_MANAGER
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2
                    ),
                Errors::CALLER_NOT_MANAGEMENT_KEY
            );
            let target_address = self.token.read().compliance().contract_address;
            starknet::syscalls::call_contract_syscall(target_address, selector, calldata).unwrap();
            self.emit(ComplianceInteraction { target: target_address, selector });
        }

        fn call_set_token_name(
            ref self: ContractState, name: ByteArray, onchain_id: ContractAddress
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(
                self.access.has_role(OwnerRoles::TOKEN_INFO_MANAGER, onchain_id),
                Errors::NOT_TOKEN_INFO_MANAGER
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2
                    ),
                Errors::CALLER_NOT_MANAGEMENT_KEY
            );
            self.token.read().set_name(name);
        }

        fn call_set_token_symbol(
            ref self: ContractState, symbol: ByteArray, onchain_id: ContractAddress
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(
                self.access.has_role(OwnerRoles::TOKEN_INFO_MANAGER, onchain_id),
                Errors::NOT_TOKEN_INFO_MANAGER
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2
                    ),
                Errors::CALLER_NOT_MANAGEMENT_KEY
            );
            self.token.read().set_symbol(symbol);
        }

        fn call_set_token_onchain_id(
            ref self: ContractState, token_onchain_id: ContractAddress, onchain_id: ContractAddress
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(
                self.access.has_role(OwnerRoles::TOKEN_INFO_MANAGER, onchain_id),
                Errors::NOT_TOKEN_INFO_MANAGER
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2
                    ),
                Errors::CALLER_NOT_MANAGEMENT_KEY
            );
            self.token.read().set_onchain_id(token_onchain_id);
        }

        fn call_set_claim_topics_registry(
            ref self: ContractState,
            claim_topics_registry: ContractAddress,
            onchain_id: ContractAddress
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(
                self.access.has_role(OwnerRoles::REGISTRY_ADDRESS_SETTER, onchain_id),
                Errors::NOT_REGISTRY_ADDRESS_SETTER
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2
                    ),
                Errors::CALLER_NOT_MANAGEMENT_KEY
            );
            self.token.read().identity_registry().set_claim_topics_registry(claim_topics_registry);
        }

        fn call_set_trusted_issuers_registry(
            ref self: ContractState,
            trusted_issuers_registry: ContractAddress,
            onchain_id: ContractAddress
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(
                self.access.has_role(OwnerRoles::REGISTRY_ADDRESS_SETTER, onchain_id),
                Errors::NOT_REGISTRY_ADDRESS_SETTER
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2
                    ),
                Errors::CALLER_NOT_MANAGEMENT_KEY
            );
            self
                .token
                .read()
                .identity_registry()
                .set_trusted_issuers_registry(trusted_issuers_registry);
        }

        fn call_add_trusted_issuer(
            ref self: ContractState,
            trusted_issuer: ContractAddress,
            claim_topics: Span<felt252>,
            onchain_id: ContractAddress
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(
                self.access.has_role(OwnerRoles::ISSUERS_REGISTRY_MANAGER, onchain_id),
                Errors::NOT_ISSUERS_REGISTRY_MANAGER
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2
                    ),
                Errors::CALLER_NOT_MANAGEMENT_KEY
            );
            self
                .token
                .read()
                .identity_registry()
                .issuers_registry()
                .add_trusted_issuer(trusted_issuer, claim_topics);
        }

        fn call_remove_trusted_issuer(
            ref self: ContractState,
            trusted_issuer: ContractAddress,
            claim_topics: Span<felt252>,
            onchain_id: ContractAddress
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(
                self.access.has_role(OwnerRoles::ISSUERS_REGISTRY_MANAGER, onchain_id),
                Errors::NOT_ISSUERS_REGISTRY_MANAGER
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2
                    ),
                Errors::CALLER_NOT_MANAGEMENT_KEY
            );
            self
                .token
                .read()
                .identity_registry()
                .issuers_registry()
                .remove_trusted_issuer(trusted_issuer);
        }

        fn call_update_issuer_claim_topics(
            ref self: ContractState,
            trusted_issuer: ContractAddress,
            claim_topics: Span<felt252>,
            onchain_id: ContractAddress
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(
                self.access.has_role(OwnerRoles::ISSUERS_REGISTRY_MANAGER, onchain_id),
                Errors::NOT_ISSUERS_REGISTRY_MANAGER
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2
                    ),
                Errors::CALLER_NOT_MANAGEMENT_KEY
            );
            self
                .token
                .read()
                .identity_registry()
                .issuers_registry()
                .update_issuer_claim_topics(trusted_issuer, claim_topics);
        }

        fn call_add_claim_topic(
            ref self: ContractState, claim_topic: felt252, onchain_id: ContractAddress
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(
                self.access.has_role(OwnerRoles::CLAIM_REGISTRY_MANAGER, onchain_id),
                Errors::NOT_CLAIM_REGISTRY_MANAGER
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2
                    ),
                Errors::CALLER_NOT_MANAGEMENT_KEY
            );
            self.token.read().identity_registry().topics_registry().add_claim_topic(claim_topic);
        }

        fn call_remove_claim_topic(
            ref self: ContractState, claim_topic: felt252, onchain_id: ContractAddress
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(
                self.access.has_role(OwnerRoles::CLAIM_REGISTRY_MANAGER, onchain_id),
                Errors::NOT_CLAIM_REGISTRY_MANAGER
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2
                    ),
                Errors::CALLER_NOT_MANAGEMENT_KEY
            );
            self.token.read().identity_registry().topics_registry().remove_claim_topic(claim_topic);
        }

        fn call_transfer_ownership_on_token_contract(
            ref self: ContractState, new_owner: ContractAddress
        ) {
            self.assert_only_admin();
            IOwnableDispatcher { contract_address: self.token.read().contract_address }
                .transfer_ownership(new_owner);
        }

        fn call_transfer_ownership_on_identity_registry_contract(
            ref self: ContractState, new_owner: ContractAddress
        ) {
            self.assert_only_admin();
            IOwnableDispatcher {
                contract_address: self.token.read().identity_registry().contract_address
            }
                .transfer_ownership(new_owner);
        }

        fn call_transfer_ownership_on_compliance_contract(
            ref self: ContractState, new_owner: ContractAddress
        ) {
            self.assert_only_admin();
            IOwnableDispatcher { contract_address: self.token.read().compliance().contract_address }
                .transfer_ownership(new_owner);
        }

        fn call_transfer_ownership_on_claim_topics_registry_contract(
            ref self: ContractState, new_owner: ContractAddress
        ) {
            self.assert_only_admin();
            IOwnableDispatcher {
                contract_address: self
                    .token
                    .read()
                    .identity_registry()
                    .topics_registry()
                    .contract_address
            }
                .transfer_ownership(new_owner);
        }

        fn call_transfer_ownership_on_issuers_registry_contract(
            ref self: ContractState, new_owner: ContractAddress
        ) {
            self.assert_only_admin();
            IOwnableDispatcher {
                contract_address: self
                    .token
                    .read()
                    .identity_registry()
                    .issuers_registry()
                    .contract_address
            }
                .transfer_ownership(new_owner);
        }

        fn call_add_agent_on_token_contract(ref self: ContractState, agent: ContractAddress) {
            self.assert_only_admin();
            IAgentRoleDispatcher { contract_address: self.token.read().contract_address }
                .add_agent(agent);
        }

        fn call_remove_agent_on_token_contract(ref self: ContractState, agent: ContractAddress) {
            self.assert_only_admin();
            IAgentRoleDispatcher { contract_address: self.token.read().contract_address }
                .remove_agent(agent);
        }

        fn call_add_agent_on_identity_registry_contract(
            ref self: ContractState, agent: ContractAddress
        ) {
            self.assert_only_admin();
            IAgentRoleDispatcher {
                contract_address: self.token.read().identity_registry().contract_address
            }
                .add_agent(agent);
        }

        fn call_remove_agent_on_identity_registry_contract(
            ref self: ContractState, agent: ContractAddress
        ) {
            self.assert_only_admin();
            IAgentRoleDispatcher {
                contract_address: self.token.read().identity_registry().contract_address
            }
                .remove_agent(agent);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_only_admin(self: @ContractState) {
            let caller = starknet::get_caller_address();
            assert(
                caller == self.ownable.owner()
                    || self.access.has_role(OwnerRoles::OWNER_ADMIN, caller),
                'Caller is not owner nor admin'
            );
        }
    }
}
