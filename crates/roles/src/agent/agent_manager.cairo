#[starknet::contract]
mod AgentManager {
    use core::poseidon::poseidon_hash_span;
    use crate::AgentRoles;
    use crate::agent::iagent_manager::IAgentManager;
    use onchain_id_starknet::interface::iidentity::{
        IdentityABIDispatcher, IdentityABIDispatcherTrait,
    };
    use openzeppelin_access::accesscontrol::AccessControlComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use registry::interface::iidentity_registry::IIdentityRegistryDispatcherTrait;
    use starknet::{ContractAddress, storage::{StoragePointerReadAccess, StoragePointerWriteAccess}};
    use token::itoken::{ITokenDispatcher, ITokenDispatcherTrait};

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
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    pub mod Errors {
        pub const CALLER_IS_NOT_ACTION_KEY: felt252 = 'Caller is not action key';
        pub const NOT_TRANSFER_MANAGER: felt252 = 'OID is not transfer manager';
        pub const NOT_FREEZER: felt252 = 'OID is not freezer';
        pub const NOT_SUPPLY_MODIFIER: felt252 = 'OID is not supply modifier';
        pub const NOT_RECOVERY_AGENT: felt252 = 'OID is not recovery agent';
        pub const NOT_WHITELIST_MANAGER: felt252 = 'OID is not whitelist manger';
    }

    #[constructor]
    fn constructor(ref self: ContractState, token: ContractAddress, owner: ContractAddress) {
        self.token.write(ITokenDispatcher { contract_address: token });
        self.access.initializer();
        self.access.set_role_admin(AgentRoles::SUPPLY_MODIFIER, AgentRoles::AGENT_ADMIN);
        self.access.set_role_admin(AgentRoles::FREEZER, AgentRoles::AGENT_ADMIN);
        self.access.set_role_admin(AgentRoles::TRANSFER_MANAGER, AgentRoles::AGENT_ADMIN);
        self.access.set_role_admin(AgentRoles::RECOVERY_AGENT, AgentRoles::AGENT_ADMIN);
        self.access.set_role_admin(AgentRoles::WHITELIST_MANAGER, AgentRoles::AGENT_ADMIN);
        self.access.set_role_admin(AgentRoles::AGENT_ADMIN, AgentRoles::AGENT_ADMIN);
        self.access._grant_role(AgentRoles::AGENT_ADMIN, owner);
    }

    #[abi(embed_v0)]
    impl AgentManagerImpl of IAgentManager<ContractState> {
        fn call_forced_transfer(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256,
            onchain_id: ContractAddress,
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(
                self.access.has_role(AgentRoles::TRANSFER_MANAGER, onchain_id),
                Errors::NOT_TRANSFER_MANAGER,
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2,
                    ),
                Errors::CALLER_IS_NOT_ACTION_KEY,
            );
            self.token.read().forced_transfer(from, to, amount);
        }

        fn call_batch_forced_transfer(
            ref self: ContractState,
            from_list: Span<ContractAddress>,
            to_list: Span<ContractAddress>,
            amounts: Span<u256>,
            onchain_id: ContractAddress,
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(
                self.access.has_role(AgentRoles::TRANSFER_MANAGER, onchain_id),
                Errors::NOT_TRANSFER_MANAGER,
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2,
                    ),
                Errors::CALLER_IS_NOT_ACTION_KEY,
            );
            self.token.read().batch_forced_transfer(from_list, to_list, amounts);
        }

        fn call_pause(ref self: ContractState, onchain_id: ContractAddress) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(self.access.has_role(AgentRoles::FREEZER, onchain_id), Errors::NOT_FREEZER);
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2,
                    ),
                Errors::CALLER_IS_NOT_ACTION_KEY,
            );
            self.token.read().pause();
        }

        fn call_unpause(ref self: ContractState, onchain_id: ContractAddress) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(self.access.has_role(AgentRoles::FREEZER, onchain_id), Errors::NOT_FREEZER);
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2,
                    ),
                Errors::CALLER_IS_NOT_ACTION_KEY,
            );
            self.token.read().unpause();
        }

        fn call_mint(
            ref self: ContractState, to: ContractAddress, amount: u256, onchain_id: ContractAddress,
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(
                self.access.has_role(AgentRoles::SUPPLY_MODIFIER, onchain_id),
                Errors::NOT_SUPPLY_MODIFIER,
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2,
                    ),
                Errors::CALLER_IS_NOT_ACTION_KEY,
            );
            self.token.read().mint(to, amount);
        }

        fn call_batch_mint(
            ref self: ContractState,
            to_list: Span<ContractAddress>,
            amounts: Span<u256>,
            onchain_id: ContractAddress,
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(
                self.access.has_role(AgentRoles::SUPPLY_MODIFIER, onchain_id),
                Errors::NOT_SUPPLY_MODIFIER,
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2,
                    ),
                Errors::CALLER_IS_NOT_ACTION_KEY,
            );
            self.token.read().batch_mint(to_list, amounts);
        }

        fn call_burn(
            ref self: ContractState,
            user_address: ContractAddress,
            amount: u256,
            onchain_id: ContractAddress,
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(
                self.access.has_role(AgentRoles::SUPPLY_MODIFIER, onchain_id),
                Errors::NOT_SUPPLY_MODIFIER,
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2,
                    ),
                Errors::CALLER_IS_NOT_ACTION_KEY,
            );
            self.token.read().burn(user_address, amount);
        }

        fn call_batch_burn(
            ref self: ContractState,
            user_addresses: Span<ContractAddress>,
            amounts: Span<u256>,
            onchain_id: ContractAddress,
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(
                self.access.has_role(AgentRoles::SUPPLY_MODIFIER, onchain_id),
                Errors::NOT_SUPPLY_MODIFIER,
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2,
                    ),
                Errors::CALLER_IS_NOT_ACTION_KEY,
            );
            self.token.read().batch_burn(user_addresses, amounts);
        }

        fn call_set_address_frozen(
            ref self: ContractState,
            user_address: ContractAddress,
            freeze: bool,
            onchain_id: ContractAddress,
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(self.access.has_role(AgentRoles::FREEZER, onchain_id), Errors::NOT_FREEZER);
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2,
                    ),
                Errors::CALLER_IS_NOT_ACTION_KEY,
            );
            self.token.read().set_address_frozen(user_address, freeze);
        }

        fn call_batch_set_address_frozen(
            ref self: ContractState,
            user_addresses: Span<ContractAddress>,
            freeze: Span<bool>,
            onchain_id: ContractAddress,
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(self.access.has_role(AgentRoles::FREEZER, onchain_id), Errors::NOT_FREEZER);
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2,
                    ),
                Errors::CALLER_IS_NOT_ACTION_KEY,
            );
            self.token.read().batch_set_address_frozen(user_addresses, freeze);
        }

        fn call_freeze_partial_tokens(
            ref self: ContractState,
            user_address: ContractAddress,
            amount: u256,
            onchain_id: ContractAddress,
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(self.access.has_role(AgentRoles::FREEZER, onchain_id), Errors::NOT_FREEZER);
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2,
                    ),
                Errors::CALLER_IS_NOT_ACTION_KEY,
            );
            self.token.read().freeze_partial_tokens(user_address, amount);
        }

        fn call_batch_freeze_partial_tokens(
            ref self: ContractState,
            user_addresses: Span<ContractAddress>,
            amounts: Span<u256>,
            onchain_id: ContractAddress,
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(self.access.has_role(AgentRoles::FREEZER, onchain_id), Errors::NOT_FREEZER);
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2,
                    ),
                Errors::CALLER_IS_NOT_ACTION_KEY,
            );
            self.token.read().batch_freeze_partial_tokens(user_addresses, amounts);
        }

        fn call_unfreeze_partial_tokens(
            ref self: ContractState,
            user_address: ContractAddress,
            amount: u256,
            onchain_id: ContractAddress,
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(self.access.has_role(AgentRoles::FREEZER, onchain_id), Errors::NOT_FREEZER);
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2,
                    ),
                Errors::CALLER_IS_NOT_ACTION_KEY,
            );
            self.token.read().unfreeze_partial_tokens(user_address, amount);
        }

        fn call_batch_unfreeze_partial_tokens(
            ref self: ContractState,
            user_addresses: Span<ContractAddress>,
            amounts: Span<u256>,
            onchain_id: ContractAddress,
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(self.access.has_role(AgentRoles::FREEZER, onchain_id), Errors::NOT_FREEZER);
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2,
                    ),
                Errors::CALLER_IS_NOT_ACTION_KEY,
            );
            self.token.read().batch_unfreeze_partial_tokens(user_addresses, amounts);
        }

        fn call_recovery_address(
            ref self: ContractState,
            lost_wallet: ContractAddress,
            new_wallet: ContractAddress,
            onchain_id: ContractAddress,
            manager_onchain_id: ContractAddress,
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: manager_onchain_id };
            assert(
                self.access.has_role(AgentRoles::RECOVERY_AGENT, manager_onchain_id),
                Errors::NOT_RECOVERY_AGENT,
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2,
                    ),
                Errors::CALLER_IS_NOT_ACTION_KEY,
            );
            self.token.read().recovery_address(lost_wallet, new_wallet, onchain_id);
        }

        fn call_register_identity(
            ref self: ContractState,
            user_address: ContractAddress,
            onchain_id: ContractAddress,
            country: u16,
            manager_onchain_id: ContractAddress,
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: manager_onchain_id };
            assert(
                self.access.has_role(AgentRoles::WHITELIST_MANAGER, manager_onchain_id),
                Errors::NOT_WHITELIST_MANAGER,
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2,
                    ),
                Errors::CALLER_IS_NOT_ACTION_KEY,
            );

            self
                .token
                .read()
                .identity_registry()
                .register_identity(user_address, onchain_id, country);
        }

        fn call_update_identity(
            ref self: ContractState,
            user_address: ContractAddress,
            identity: ContractAddress,
            onchain_id: ContractAddress,
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(
                self.access.has_role(AgentRoles::WHITELIST_MANAGER, onchain_id),
                Errors::NOT_WHITELIST_MANAGER,
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2,
                    ),
                Errors::CALLER_IS_NOT_ACTION_KEY,
            );

            self.token.read().identity_registry().update_identity(user_address, identity);
        }

        fn call_update_country(
            ref self: ContractState,
            user_address: ContractAddress,
            country: u16,
            onchain_id: ContractAddress,
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(
                self.access.has_role(AgentRoles::WHITELIST_MANAGER, onchain_id),
                Errors::NOT_WHITELIST_MANAGER,
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2,
                    ),
                Errors::CALLER_IS_NOT_ACTION_KEY,
            );

            self.token.read().identity_registry().update_country(user_address, country);
        }

        fn call_delete_identity(
            ref self: ContractState, user_address: ContractAddress, onchain_id: ContractAddress,
        ) {
            let oid_disatcher = IdentityABIDispatcher { contract_address: onchain_id };
            assert(
                self.access.has_role(AgentRoles::WHITELIST_MANAGER, onchain_id),
                Errors::NOT_WHITELIST_MANAGER,
            );
            assert(
                oid_disatcher
                    .key_has_purpose(
                        poseidon_hash_span(array![starknet::get_caller_address().into()].span()), 2,
                    ),
                Errors::CALLER_IS_NOT_ACTION_KEY,
            );

            self.token.read().identity_registry().delete_identity(user_address);
        }
    }
}
