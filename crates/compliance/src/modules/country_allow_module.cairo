use starknet::ContractAddress;

#[starknet::interface]
trait ICountryAllowModule<TContractState> {
    fn batch_allow_countries(ref self: TContractState, countries: Span<u16>);
    fn batch_disallow_countries(ref self: TContractState, countries: Span<u16>);
    fn add_allowed_country(ref self: TContractState, country: u16);
    fn remove_allowed_country(ref self: TContractState, country: u16);
    fn is_country_allowed(self: @TContractState, compliance: ContractAddress, country: u16) -> bool;
    fn compliance_check_on_country_whitelisting(
        self: @TContractState, from: ContractAddress, to: ContractAddress, amount: u256,
    ) -> bool;
}

#[starknet::contract]
mod CountryAllowModule {
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
    use token::itoken::{ITokenDispatcher, ITokenDispatcherTrait};

    component!(path: AbstractModuleComponent, storage: abstract_module, event: AbstractModuleEvent);

    #[abi(embed_v0)]
    impl ModuleImpl = AbstractModuleComponent::AbstractModule<ContractState>;
    impl AbstractModuleInternalImpl = AbstractModuleComponent::InternalImpl<ContractState>;

    component!(path: UpgradeableComponent, storage: upgrades, event: UpgradeableEvent);

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        allowed_countries: Map<ContractAddress, Map<u16, bool>>,
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
        CountryAllowed: CountryAllowed,
        CountryUnallowed: CountryUnallowed,
        #[flat]
        AbstractModuleEvent: AbstractModuleComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct CountryAllowed {
        #[key]
        compliance: ContractAddress,
        country: u16,
    }

    #[derive(Drop, starknet::Event)]
    struct CountryUnallowed {
        #[key]
        compliance: ContractAddress,
        country: u16,
    }

    pub mod Errors {
        pub const COUNTRY_ALREADY_ALLOWED: felt252 = 'Country already allowed';
        pub const COUNTRY_NOT_ALLOWED: felt252 = 'Country is not allowed';
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
            contract_state.is_country_allowed(compliance, receiver_country)
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
            "CountryAllowModule"
        }
    }


    #[abi(embed_v0)]
    impl CountryAllowModuleImpl of super::ICountryAllowModule<ContractState> {
        fn add_allowed_country(ref self: ContractState, country: u16) {
            self.abstract_module.only_compliance_call();
            let caller = starknet::get_caller_address();
            let country_allowed_storage_path = self.allowed_countries.entry(caller).entry(country);
            assert(!country_allowed_storage_path.read(), Errors::COUNTRY_ALREADY_ALLOWED);
            country_allowed_storage_path.write(true);
            self.emit(CountryAllowed { compliance: caller, country });
        }

        fn remove_allowed_country(ref self: ContractState, country: u16) {
            self.abstract_module.only_compliance_call();
            let caller = starknet::get_caller_address();
            let country_allowed_storage_path = self.allowed_countries.entry(caller).entry(country);
            assert(country_allowed_storage_path.read(), Errors::COUNTRY_NOT_ALLOWED);
            country_allowed_storage_path.write(false);
            self.emit(CountryUnallowed { compliance: caller, country });
        }

        /// NOTE: In solidity, batch allow does not check if country already allowed but allow
        /// method checks.
        /// This implementation checks
        fn batch_allow_countries(ref self: ContractState, countries: Span<u16>) {
            self.abstract_module.only_compliance_call();
            let caller = starknet::get_caller_address();
            assert(countries.len() < 195, Errors::MAX_COUNTRIES_EXCEEDED);
            let compliance_allowance_storage_path = self.allowed_countries.entry(caller);
            for country in countries {
                let allowed_storage_path = compliance_allowance_storage_path.entry(*country);
                assert(!allowed_storage_path.read(), Errors::COUNTRY_ALREADY_ALLOWED);
                allowed_storage_path.write(true);
                self.emit(CountryAllowed { compliance: caller, country: *country });
            };
        }

        /// NOTE: In solidity, batch disallow does not check if country allowed but unallow method
        /// checks.
        /// This implementation checks
        fn batch_disallow_countries(ref self: ContractState, countries: Span<u16>) {
            self.abstract_module.only_compliance_call();
            let caller = starknet::get_caller_address();
            assert(countries.len() < 195, Errors::MAX_COUNTRIES_EXCEEDED);
            let compliance_allowance_storage_path = self.allowed_countries.entry(caller);
            for country in countries {
                let allowed_storage_path = compliance_allowance_storage_path.entry(*country);
                assert(allowed_storage_path.read(), Errors::COUNTRY_NOT_ALLOWED);
                allowed_storage_path.write(false);
                self.emit(CountryUnallowed { compliance: caller, country: *country });
            };
        }

        fn is_country_allowed(
            self: @ContractState, compliance: ContractAddress, country: u16,
        ) -> bool {
            self.allowed_countries.entry(compliance).entry(country).read()
        }

        fn compliance_check_on_country_whitelisting(
            self: @ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
        ) -> bool {
            true
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn get_country(
            self: @ContractState, compliance: ContractAddress, user_address: ContractAddress,
        ) -> u16 {
            ITokenDispatcher {
                contract_address: IModularComplianceDispatcher { contract_address: compliance }
                    .get_token_bound(),
            }
                .identity_registry()
                .investor_country(user_address)
        }
    }
}
