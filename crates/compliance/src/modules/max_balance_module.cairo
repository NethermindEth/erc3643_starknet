use starknet::ContractAddress;

#[starknet::interface]
pub trait IMaxBalanceModule<TContractState> {
    fn set_max_balance(ref self: TContractState, max: u256);
    fn preset_module_state(
        ref self: TContractState, compliance: ContractAddress, id: ContractAddress, balance: u256,
    );
    fn batch_preset_module_state(
        ref self: TContractState,
        compliance: ContractAddress,
        id: Span<ContractAddress>,
        balance: Span<u256>,
    );
    fn preset_completed(ref self: TContractState, compliance: ContractAddress);
    fn get_id_balance(
        self: @TContractState, compliance: ContractAddress, identity: ContractAddress,
    ) -> u256;
}

#[starknet::contract]
pub mod MaxBalanceModule {
    use core::num::traits::Zero;
    use crate::{
        imodular_compliance::{IModularComplianceDispatcher, IModularComplianceDispatcherTrait},
        modules::abstract_module::{
            AbstractModuleComponent, AbstractModuleComponent::AbstractFunctionsTrait,
        },
    };
    use openzeppelin_access::ownable::{
        OwnableComponent, interface::{IOwnableDispatcher, IOwnableDispatcherTrait},
    };
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
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
        compliance_preset_status: Map<ContractAddress, bool>,
        max_balance: Map<ContractAddress, u256>,
        id_balance: Map<ContractAddress, Map<ContractAddress, u256>>,
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
        MaxBalanceSet: MaxBalanceSet,
        IDBalancePreSet: IDBalancePreSet,
        PresetCompleted: PresetCompleted,
        #[flat]
        AbstractModuleEvent: AbstractModuleComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MaxBalanceSet {
        #[key]
        pub compliance: ContractAddress,
        #[key]
        pub max_balance: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IDBalancePreSet {
        #[key]
        pub compliance: ContractAddress,
        #[key]
        id: ContractAddress,
        balance: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PresetCompleted {
        #[key]
        pub compliance: ContractAddress,
    }

    /// TODO: write better error messages
    pub mod Errors {
        use starknet::ContractAddress;

        pub fn MaxBalanceExceeded(compliance: ContractAddress, value: u256) {
            panic!("Max balance exceeded! compliance {:?}, value: {:?}", compliance, value);
        }
        // TODO: Finalize this error message
        pub fn InvalidPresetValues(
            compliance: ContractAddress, id: Span<ContractAddress>, balance: Span<u256>,
        ) {
            panic!("Invalid pre set values!");
        }

        pub fn OnlyComplianceOwnerCanCall(compliance: ContractAddress) {
            panic!("Only compliance owner can call! Compliance: {:?}", compliance);
        }

        pub fn TokenAlreadyBound(compliance: ContractAddress) {
            panic!("Token already bound! Compliance {:?}", compliance);
        }
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
            let mut contract_state = AbstractModuleComponent::HasComponent::get_contract_mut(
                ref self,
            );
            let caller = starknet::get_caller_address();

            let compliance_balances = contract_state.id_balance.entry(caller);

            let id_to = contract_state.get_identity(caller, to);
            let id_to_balance_storage_path = compliance_balances.entry(id_to).deref();
            let new_to_balance = id_to_balance_storage_path.read() + value;

            if new_to_balance > contract_state.max_balance.entry(caller).read() {
                Errors::MaxBalanceExceeded(caller, value);
            }

            id_to_balance_storage_path.write(new_to_balance);

            let id_from = contract_state.get_identity(caller, from);
            let id_from_balance_storage_path = compliance_balances.entry(id_from).deref();
            id_from_balance_storage_path.write(id_from_balance_storage_path.read() - value);
        }

        fn module_mint_action(
            ref self: AbstractModuleComponent::ComponentState<ContractState>,
            to: ContractAddress,
            value: u256,
        ) {
            self.only_compliance_call();
            let mut contract_state = AbstractModuleComponent::HasComponent::get_contract_mut(
                ref self,
            );
            let caller = starknet::get_caller_address();
            let id_to = contract_state.get_identity(caller, to);

            let id_to_balance_storage_path = contract_state
                .id_balance
                .entry(caller)
                .entry(id_to)
                .deref();
            let new_to_balance = id_to_balance_storage_path.read() + value;

            if new_to_balance > contract_state.max_balance.entry(caller).read() {
                Errors::MaxBalanceExceeded(caller, value);
            }

            id_to_balance_storage_path.write(new_to_balance);
        }

        fn module_burn_action(
            ref self: AbstractModuleComponent::ComponentState<ContractState>,
            from: ContractAddress,
            value: u256,
        ) {
            self.only_compliance_call();
            let mut contract_state = AbstractModuleComponent::HasComponent::get_contract_mut(
                ref self,
            );
            let caller = starknet::get_caller_address();
            let id_from = contract_state.get_identity(caller, from);
            let id_from_balance_storage_path = contract_state
                .id_balance
                .entry(caller)
                .entry(id_from)
                .deref();
            id_from_balance_storage_path.write(id_from_balance_storage_path.read() - value);
        }

        fn module_check(
            self: @AbstractModuleComponent::ComponentState<ContractState>,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
            compliance: ContractAddress,
        ) -> bool {
            let contract_state = AbstractModuleComponent::HasComponent::get_contract(self);
            let max_balance = contract_state.max_balance.entry(compliance).read();
            if value > max_balance {
                return false;
            }

            let id_to = contract_state.get_identity(compliance, to);
            let to_new_balance = contract_state.id_balance.entry(compliance).entry(id_to).read()
                + value;

            !(to_new_balance > max_balance)
        }

        fn can_compliance_bind(
            self: @AbstractModuleComponent::ComponentState<ContractState>,
            compliance: ContractAddress,
        ) -> bool {
            let contract_state = AbstractModuleComponent::HasComponent::get_contract(self);
            if contract_state.compliance_preset_status.entry(compliance).read() {
                return true;
            }

            let erc20_dispatcher = IERC20Dispatcher {
                contract_address: IModularComplianceDispatcher { contract_address: compliance }
                    .get_token_bound(),
            };

            erc20_dispatcher.total_supply().is_zero()
        }

        fn is_plug_and_play(self: @AbstractModuleComponent::ComponentState<ContractState>) -> bool {
            false
        }

        fn name(self: @AbstractModuleComponent::ComponentState<ContractState>) -> ByteArray {
            "MaxBalanceModule"
        }
    }

    #[abi(embed_v0)]
    impl MaxBalanceModuleImpl of super::IMaxBalanceModule<ContractState> {
        fn set_max_balance(ref self: ContractState, max: u256) {
            self.abstract_module.only_compliance_call();
            let caller = starknet::get_caller_address();
            self.max_balance.entry(caller).write(max);
            self.emit(MaxBalanceSet { compliance: caller, max_balance: max });
        }

        fn preset_module_state(
            ref self: ContractState,
            compliance: ContractAddress,
            id: ContractAddress,
            balance: u256,
        ) {
            let ownable_dispatcher = IOwnableDispatcher { contract_address: compliance };
            if ownable_dispatcher.owner() != starknet::get_caller_address() {
                Errors::OnlyComplianceOwnerCanCall(compliance);
            };

            let modular_compliance_dispatcher = IModularComplianceDispatcher {
                contract_address: compliance,
            };
            if modular_compliance_dispatcher.is_module_bound(starknet::get_contract_address()) {
                Errors::TokenAlreadyBound(compliance);
            };

            self.id_balance.entry(compliance).entry(id).write(balance);
            self.emit(IDBalancePreSet { compliance, id, balance });
        }

        fn batch_preset_module_state(
            ref self: ContractState,
            compliance: ContractAddress,
            id: Span<ContractAddress>,
            balance: Span<u256>,
        ) {
            if id.len().is_zero() || id.len() != balance.len() {
                Errors::InvalidPresetValues(compliance, id, balance);
            }

            let ownable_dispatcher = IOwnableDispatcher { contract_address: compliance };
            if ownable_dispatcher.owner() != starknet::get_caller_address() {
                Errors::OnlyComplianceOwnerCanCall(compliance);
            }

            let modular_compliance_dispatcher = IModularComplianceDispatcher {
                contract_address: compliance,
            };
            if modular_compliance_dispatcher.is_module_bound(starknet::get_contract_address()) {
                Errors::TokenAlreadyBound(compliance);
            }

            let compliance_id_balances = self.id_balance.entry(compliance);
            for i in 0..id.len() {
                let (_id, _balance) = (*id.at(i), *balance.at(i));
                compliance_id_balances.entry(_id).write(_balance);
                self.emit(IDBalancePreSet { compliance, id: _id, balance: _balance });
            };

            self.compliance_preset_status.entry(compliance).write(true);
            self.emit(PresetCompleted { compliance });
        }

        fn preset_completed(ref self: ContractState, compliance: ContractAddress) {
            let ownable_dispatcher = IOwnableDispatcher { contract_address: compliance };
            if ownable_dispatcher.owner() != starknet::get_caller_address() {
                Errors::OnlyComplianceOwnerCanCall(compliance);
            }

            self.compliance_preset_status.entry(compliance).write(true);
            self.emit(PresetCompleted { compliance });
        }

        fn get_id_balance(
            self: @ContractState, compliance: ContractAddress, identity: ContractAddress,
        ) -> u256 {
            self.id_balance.entry(compliance).entry(identity).read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn get_identity(
            self: @ContractState, compliance: ContractAddress, user_address: ContractAddress,
        ) -> ContractAddress {
            let token_dispatcher = ITokenDispatcher {
                contract_address: IModularComplianceDispatcher { contract_address: compliance }
                    .get_token_bound(),
            };
            let identity = token_dispatcher.identity_registry().identity(user_address);
            assert(identity.is_non_zero(), 'Identity not found');
            identity
        }
    }
}
