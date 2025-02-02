use starknet::ContractAddress;

#[starknet::interface]
pub trait ICountryRestrictModule<ContractState> {
    fn add_country_restriction(ref self: ContractState, country: u16);
    fn remove_country_restriction(ref self: ContractState, country: u16);
    fn batch_restrict_countries(ref self: ContractState, countries: Span<u16>);
    fn batch_unrestrict_countries(ref self: ContractState, countries: Span<u16>);
    fn is_country_restricted(
        self: @ContractState, compliance: ContractAddress, country: u16,
    ) -> bool;
}

#[starknet::contract]
pub mod CountryRestrictModule {
    use crate::compliance::{
        imodular_compliance::{IModularComplianceDispatcher, IModularComplianceDispatcherTrait},
        modules::abstract_module::{
            AbstractModuleComponent, AbstractModuleComponent::AbstractFunctionsTrait,
        },
    };
    use crate::registry::interface::iidentity_registry::IIdentityRegistryDispatcherTrait;
    use crate::token::itoken::{ITokenDispatcher, ITokenDispatcherTrait};
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use starknet::{
        ClassHash, ContractAddress,
        storage::{Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess},
    };

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
        restricted_countries: Map<ContractAddress, Map<u16, bool>>,
        #[substorage(v0)]
        abstract_module: AbstractModuleComponent::Storage,
        #[substorage(v0)]
        upgrades: UpgradeableComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AddedRestrictedCountry: AddedRestrictedCountry,
        RemovedRestrictedCountry: RemovedRestrictedCountry,
        #[flat]
        AbstractModuleEvent: AbstractModuleComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AddedRestrictedCountry {
        #[key]
        pub compliance: ContractAddress,
        pub country: u16,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RemovedRestrictedCountry {
        #[key]
        pub compliance: ContractAddress,
        pub country: u16,
    }

    pub mod Errors {
        pub const COUNTRY_ALREADY_RESTRICTED: felt252 = 'Country already restricted';
        pub const COUNTRY_NOT_RESTRICTED: felt252 = 'Country is not restricted';
        pub const MAX_COUNTRIES_EXCEEDED: felt252 = 'Max 195 country in one batch';
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
            let contract_state = AbstractModuleComponent::HasComponent::get_contract(self);
            let receiver_country = contract_state.get_country(compliance, to);
            !contract_state.is_country_restricted(compliance, receiver_country)
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
            "CountryRestrictModule"
        }
    }


    #[abi(embed_v0)]
    impl CountryRestrictModuleImpl of super::ICountryRestrictModule<ContractState> {
        fn add_country_restriction(ref self: ContractState, country: u16) {
            self.abstract_module.only_compliance_call();
            let caller = starknet::get_caller_address();
            let country_restriction_storage_path = self
                .restricted_countries
                .entry(caller)
                .entry(country);
            assert(!country_restriction_storage_path.read(), Errors::COUNTRY_ALREADY_RESTRICTED);
            country_restriction_storage_path.write(true);
            self.emit(AddedRestrictedCountry { compliance: caller, country });
        }

        fn remove_country_restriction(ref self: ContractState, country: u16) {
            self.abstract_module.only_compliance_call();
            let caller = starknet::get_caller_address();
            let country_restriction_storage_path = self
                .restricted_countries
                .entry(caller)
                .entry(country);
            assert(country_restriction_storage_path.read(), Errors::COUNTRY_NOT_RESTRICTED);
            country_restriction_storage_path.write(false);
            self.emit(RemovedRestrictedCountry { compliance: caller, country });
        }

        fn batch_restrict_countries(ref self: ContractState, countries: Span<u16>) {
            self.abstract_module.only_compliance_call();
            let caller = starknet::get_caller_address();
            assert(countries.len() < 195, Errors::MAX_COUNTRIES_EXCEEDED);
            let compliance_restrictions_storage_path = self.restricted_countries.entry(caller);
            for country in countries {
                let restricted_storage_path = compliance_restrictions_storage_path.entry(*country);
                assert(!restricted_storage_path.read(), Errors::COUNTRY_ALREADY_RESTRICTED);
                restricted_storage_path.write(true);
                self.emit(AddedRestrictedCountry { compliance: caller, country: *country });
            };
        }

        fn batch_unrestrict_countries(ref self: ContractState, countries: Span<u16>) {
            self.abstract_module.only_compliance_call();
            let caller = starknet::get_caller_address();
            assert(countries.len() < 195, Errors::MAX_COUNTRIES_EXCEEDED);
            let compliance_restrictions_storage_path = self.restricted_countries.entry(caller);
            for country in countries {
                let restricted_storage_path = compliance_restrictions_storage_path.entry(*country);
                assert(restricted_storage_path.read(), Errors::COUNTRY_NOT_RESTRICTED);
                restricted_storage_path.write(false);
                self.emit(RemovedRestrictedCountry { compliance: caller, country: *country });
            };
        }

        fn is_country_restricted(
            self: @ContractState, compliance: ContractAddress, country: u16,
        ) -> bool {
            self.restricted_countries.entry(compliance).entry(country).read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn get_country(
            self: @ContractState, compliance: ContractAddress, user_address: ContractAddress,
        ) -> u16 {
            let token_bound = IModularComplianceDispatcher { contract_address: compliance }
                .get_token_bound();
            let token_dispatcher = ITokenDispatcher { contract_address: token_bound };

            token_dispatcher.identity_registry().investor_country(user_address)
        }
    }
}
