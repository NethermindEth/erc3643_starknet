use starknet::ContractAddress;

#[derive(Drop, Copy, Serde, starknet::Store)]
pub enum ListingType {
    #[default]
    NOT_CONFIGURED,
    WHITELISTING,
    BLACKLISTING,
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub enum InvestorAddressType {
    #[default]
    WALLET,
    ONCHAINID,
}

#[starknet::interface]
trait ITokenListingRestrictionsModule<TContractState> {
    fn configure_token(ref self: TContractState, listing_type: ListingType);
    fn list_token(
        ref self: TContractState, token_address: ContractAddress, address_type: InvestorAddressType,
    );
    fn unlist_token(
        ref self: TContractState, token_address: ContractAddress, address_type: InvestorAddressType,
    );
    fn batch_list_tokens(
        ref self: TContractState,
        token_addresses: Span<ContractAddress>,
        address_type: InvestorAddressType,
    );
    fn batch_unlist_tokens(
        ref self: TContractState,
        token_addresses: Span<ContractAddress>,
        address_type: InvestorAddressType,
    );
    fn get_token_listing_type(self: @TContractState, token_address: ContractAddress) -> ListingType;
    fn get_investor_listing_status(
        self: @TContractState, token_address: ContractAddress, investor_address: ContractAddress,
    ) -> bool;
}

#[starknet::contract]
mod TokenListingRestrictionsModule {
    use core::{num::traits::Zero, panic_with_felt252};
    use crate::{
        imodular_compliance::{IModularComplianceDispatcher, IModularComplianceDispatcherTrait},
        modules::abstract_module::{
            AbstractModuleComponent, AbstractModuleComponent::AbstractFunctionsTrait,
        },
    };
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use registry::interface::iidentity_registry::IIdentityRegistryDispatcherTrait;
    use starknet::{
        ClassHash, ContractAddress,
        storage::{Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess},
    };
    use super::{InvestorAddressType, ListingType};
    use token::itoken::{ITokenDispatcher, ITokenDispatcherTrait};

    component!(path: AbstractModuleComponent, storage: abstract_module, event: AbstractModuleEvent);

    #[abi(embed_v0)]
    impl ModuleImpl = AbstractModuleComponent::AbstractModuleImpl<ContractState>;
    impl AbstractModuleInternalImpl = AbstractModuleComponent::InternalImpl<ContractState>;

    component!(path: UpgradeableComponent, storage: upgrades, event: UpgradeableEvent);

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        token_listing_type: Map<ContractAddress, ListingType>,
        token_investor_listing_status: Map<ContractAddress, Map<ContractAddress, bool>>,
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
        TokenListingConfigured: TokenListingConfigured,
        TokenListed: TokenListed,
        TokenUnlisted: TokenUnlisted,
        #[flat]
        AbstractModuleEvent: AbstractModuleComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct TokenListingConfigured {
        token_address: ContractAddress,
        listing_type: ListingType,
    }

    #[derive(Drop, starknet::Event)]
    struct TokenListed {
        token_address: ContractAddress,
        investor_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct TokenUnlisted {
        token_address: ContractAddress,
        investor_address: ContractAddress,
    }

    pub mod Errors {
        pub const TOKEN_ALREADY_CONFIGURED: felt252 = 'Token already configured';
        pub const TOKEN_NOT_CONFIGURED: felt252 = 'Token is not configure';
        pub const TOKEN_ALREADY_LISTED: felt252 = 'Token already listed';
        pub const TOKEN_NOT_LISTED: felt252 = 'Token is not listed';
        pub const NO_BOUND_TOKEN: felt252 = 'Compliance not bound to a token';
        pub const IDENTITY_NOT_FOUND: felt252 = 'Identity not found';
        pub const INVALID_LISTING_TYPE_FOR_CONFIGURATION: felt252 = 'Invalid listing config params';
        pub const UNSUPPORTED_ADDRESS_TYPE: felt252 = 'Unsupported address type';
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

    impl AbstractFunctionsImpl of AbstractFunctionsTrait<ContractState> {
        fn module_transfer_action(
            ref self: AbstractModuleComponent::ComponentState<ContractState>,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
        ) {
            self.only_compliance_call();
        }

        fn module_mint_action(
            ref self: AbstractModuleComponent::ComponentState<ContractState>,
            to: ContractAddress,
            value: u256,
        ) {
            self.only_compliance_call();
        }

        fn module_burn_action(
            ref self: AbstractModuleComponent::ComponentState<ContractState>,
            from: ContractAddress,
            value: u256,
        ) {
            self.only_compliance_call();
        }

        fn module_check(
            self: @AbstractModuleComponent::ComponentState<ContractState>,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
            compliance: ContractAddress,
        ) -> bool {
            if to.is_zero() {
                return true;
            }

            let contract_state = AbstractModuleComponent::HasComponent::get_contract(self);
            let token_address = contract_state.get_bound_token_address(compliance);
            let listing_type = contract_state.token_listing_type.entry(token_address).read();

            if let ListingType::NOT_CONFIGURED = listing_type {
                return true;
            }

            let to_listing_status_storage = contract_state
                .token_investor_listing_status
                .entry(token_address);
            let is_listed = to_listing_status_storage.entry(to).read()
                || to_listing_status_storage
                    .entry(contract_state.get_identity_by_token_address(token_address, to))
                    .read();

            if let ListingType::BLACKLISTING = listing_type {
                !is_listed
            } else {
                is_listed
            }
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
            "TokenListingRestrictionsModule"
        }
    }

    #[abi(embed_v0)]
    impl TokenListingRestrictionsModuleImpl of super::ITokenListingRestrictionsModule<
        ContractState,
    > {
        fn configure_token(ref self: ContractState, listing_type: ListingType) {
            let token_address = self.get_bound_token_address(starknet::get_caller_address());

            if let ListingType::NOT_CONFIGURED = listing_type {
                panic_with_felt252(Errors::INVALID_LISTING_TYPE_FOR_CONFIGURATION);
            }

            let token_listing_type = self.token_listing_type.entry(token_address).read();
            if let ListingType::NOT_CONFIGURED = token_listing_type {
                self.token_listing_type.entry(token_address).write(listing_type);
                self.emit(TokenListingConfigured { token_address, listing_type });
            } else {
                panic_with_felt252(Errors::TOKEN_ALREADY_CONFIGURED);
            }
        }

        fn list_token(
            ref self: ContractState,
            token_address: ContractAddress,
            address_type: InvestorAddressType,
        ) {
            let token_listing_type = self.token_listing_type.entry(token_address).read();
            if let ListingType::NOT_CONFIGURED = token_listing_type {
                panic_with_felt252(Errors::TOKEN_NOT_CONFIGURED);
            }

            let investor_address = self
                .get_investor_address_by_address_type(
                    token_address, starknet::get_caller_address(), address_type,
                );
            let token_investor_listing_status_storage = self
                .token_investor_listing_status
                .entry(token_address)
                .entry(investor_address);

            assert(!token_investor_listing_status_storage.read(), Errors::TOKEN_ALREADY_LISTED);

            token_investor_listing_status_storage.write(true);
            self.emit(TokenListed { token_address, investor_address });
        }

        fn unlist_token(
            ref self: ContractState,
            token_address: ContractAddress,
            address_type: InvestorAddressType,
        ) {
            let investor_address = self
                .get_investor_address_by_address_type(
                    token_address, starknet::get_caller_address(), address_type,
                );
            let token_investor_listing_status_storage = self
                .token_investor_listing_status
                .entry(token_address)
                .entry(investor_address);

            assert(token_investor_listing_status_storage.read(), Errors::TOKEN_NOT_LISTED);

            token_investor_listing_status_storage.write(false);
            self.emit(TokenUnlisted { token_address, investor_address });
        }

        fn batch_list_tokens(
            ref self: ContractState,
            token_addresses: Span<ContractAddress>,
            address_type: InvestorAddressType,
        ) {
            for token_address in token_addresses {
                self.list_token(*token_address, address_type);
            };
        }

        fn batch_unlist_tokens(
            ref self: ContractState,
            token_addresses: Span<ContractAddress>,
            address_type: InvestorAddressType,
        ) {
            for token_address in token_addresses {
                self.unlist_token(*token_address, address_type);
            };
        }

        fn get_token_listing_type(
            self: @ContractState, token_address: ContractAddress,
        ) -> ListingType {
            self.token_listing_type.entry(token_address).read()
        }

        fn get_investor_listing_status(
            self: @ContractState, token_address: ContractAddress, investor_address: ContractAddress,
        ) -> bool {
            self.token_investor_listing_status.entry(token_address).entry(investor_address).read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn get_investor_address_by_address_type(
            self: @ContractState,
            token_address: ContractAddress,
            user_address: ContractAddress,
            address_type: InvestorAddressType,
        ) -> ContractAddress {
            match address_type {
                InvestorAddressType::WALLET => user_address,
                InvestorAddressType::ONCHAINID => self
                    .get_identity_by_token_address(token_address, user_address),
                _ => panic_with_felt252(Errors::UNSUPPORTED_ADDRESS_TYPE),
            }
        }

        fn get_identity_by_token_address(
            self: @ContractState, token_address: ContractAddress, user_address: ContractAddress,
        ) -> ContractAddress {
            let token_dispatcher = ITokenDispatcher { contract_address: token_address };
            let identity = token_dispatcher.identity_registry().identity(user_address);
            assert(identity.is_non_zero(), Errors::IDENTITY_NOT_FOUND);
            identity
        }

        fn get_bound_token_address(
            self: @ContractState, compliance: ContractAddress,
        ) -> ContractAddress {
            let token_bound = IModularComplianceDispatcher { contract_address: compliance }
                .get_token_bound();
            assert(token_bound.is_non_zero(), Errors::NO_BOUND_TOKEN);
            token_bound
        }
    }
}
