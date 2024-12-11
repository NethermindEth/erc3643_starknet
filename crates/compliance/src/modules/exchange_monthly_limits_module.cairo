use starknet::ContractAddress;

#[starknet::interface]
trait IExchangeMonthlyLimitsModule<TContractState> {
    fn set_exchange_monthly_limit(
        ref self: TContractState, exchange_id: ContractAddress, new_exchange_monthly_limit: u256,
    );
    fn get_exchange_monthly_limit(
        self: @TContractState, compliance: ContractAddress, exchange_id: ContractAddress,
    ) -> u256;
    fn add_exchange_id(ref self: TContractState, exchange_id: ContractAddress);
    fn remove_exchange_id(ref self: TContractState, exchange_id: ContractAddress);
    fn is_exchange_id(self: @TContractState, exchange_id: ContractAddress) -> bool;
    fn get_monthly_counter(
        self: @TContractState,
        compliance: ContractAddress,
        exchange_id: ContractAddress,
        investor_id: ContractAddress,
    ) -> u256;
    fn get_monthly_timer(
        self: @TContractState,
        compliance: ContractAddress,
        exchange_id: ContractAddress,
        investor_id: ContractAddress,
    ) -> u64;
}

#[starknet::contract]
mod ExchangeMonthlyLimitsModule {
    use core::num::traits::Zero;
    use crate::{
        imodular_compliance::{IModularComplianceDispatcher, IModularComplianceDispatcherTrait},
        modules::abstract_module::{
            AbstractModuleComponent, AbstractModuleComponent::AbstractFunctionsTrait,
        },
    };
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use registry::interface::iidentity_registry::IIdentityRegistryDispatcherTrait;
    use roles::agent_role::{IAgentRoleDispatcher, IAgentRoleDispatcherTrait};
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

    pub const DAY: u64 = 60 * 60 * 24;

    #[storage]
    struct Storage {
        exchange_monthly_limits: Map<(ContractAddress, ContractAddress), u256>,
        exchange_counters: Map<
            (ContractAddress, ContractAddress, ContractAddress), ExchangeTransferCounter,
        >,
        exchange_ids: Map<ContractAddress, bool>,
        #[substorage(v0)]
        abstract_module: AbstractModuleComponent::Storage,
        #[substorage(v0)]
        upgrades: UpgradeableComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[starknet::storage_node]
    pub struct ExchangeTransferCounter {
        monthly_count: u256,
        monthly_timer: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ExchangeMonthlyLimitUpdated: ExchangeMonthlyLimitUpdated,
        ExchangeIDAdded: ExchangeIDAdded,
        ExchangeIDRemoved: ExchangeIDRemoved,
        #[flat]
        AbstractModuleEvent: AbstractModuleComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct ExchangeMonthlyLimitUpdated {
        #[key]
        compliance: ContractAddress,
        exchange_id: ContractAddress,
        new_exchange_monthly_limit: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct ExchangeIDAdded {
        new_exchange_id: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct ExchangeIDRemoved {
        exchange_id: ContractAddress,
    }

    pub mod Errors {
        use starknet::ContractAddress;

        pub fn OnchainIDAlreadyTaggedAsExchange(exchange_id: ContractAddress) {
            panic!("Onchain ID already tagges as exchange! OID {:?}", exchange_id);
        }
        pub fn OnchainIDNotTaggedAsExchange(exchange_id: ContractAddress) {
            panic!("Onchain ID not tagges as exchange! OID {:?}", exchange_id);
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
            let mut contract_state = AbstractModuleComponent::HasComponent::get_contract_mut(
                ref self,
            );
            self.only_compliance_call();
            let caller = starknet::get_caller_address();
            let sender_identity = contract_state.get_identity(caller, from);
            let receiver_identity = contract_state.get_identity(caller, to);

            if contract_state.is_exchange_id(receiver_identity)
                && !contract_state.is_token_agent(caller, from) {
                contract_state
                    .increase_exchange_counters(caller, receiver_identity, sender_identity, value);
            }
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
            if from.is_zero() || contract_state.is_token_agent(compliance, from) {
                return true;
            }

            let sender_identity = contract_state.get_identity(compliance, from);
            if contract_state.is_exchange_id(sender_identity) {
                return true;
            }

            let receiver_identity = contract_state.get_identity(compliance, to);
            if !contract_state.is_exchange_id(receiver_identity) {
                return true;
            }

            let receiver_monthly_limit = contract_state
                .exchange_monthly_limits
                .entry((compliance, receiver_identity))
                .read();
            if value > receiver_monthly_limit {
                return false;
            }

            if contract_state
                .is_exchange_month_finished(compliance, receiver_identity, sender_identity) {
                return true;
            }

            if contract_state.get_monthly_counter(compliance, receiver_identity, sender_identity)
                + value > receiver_monthly_limit {
                return false;
            }

            true
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
            "ExchangeMonthlyLimitsModule"
        }
    }

    #[abi(embed_v0)]
    impl ExchangeMonthlyLimitsModuleImpl of super::IExchangeMonthlyLimitsModule<ContractState> {
        fn set_exchange_monthly_limit(
            ref self: ContractState, exchange_id: ContractAddress, new_exchange_monthly_limit: u256,
        ) {
            self.abstract_module.only_compliance_call();
            let caller = starknet::get_caller_address();
            self
                .exchange_monthly_limits
                .entry((caller, exchange_id))
                .write(new_exchange_monthly_limit);
            self
                .emit(
                    ExchangeMonthlyLimitUpdated {
                        compliance: caller, exchange_id, new_exchange_monthly_limit,
                    },
                );
        }

        fn get_exchange_monthly_limit(
            self: @ContractState, compliance: ContractAddress, exchange_id: ContractAddress,
        ) -> u256 {
            self.exchange_monthly_limits.entry((compliance, exchange_id)).read()
        }

        fn add_exchange_id(ref self: ContractState, exchange_id: ContractAddress) {
            self.ownable.assert_only_owner();
            if self.is_exchange_id(exchange_id) {
                Errors::OnchainIDAlreadyTaggedAsExchange(exchange_id);
            }
            self.exchange_ids.entry(exchange_id).write(true);
            self.emit(ExchangeIDAdded { new_exchange_id: exchange_id });
        }

        fn remove_exchange_id(ref self: ContractState, exchange_id: ContractAddress) {
            self.ownable.assert_only_owner();
            if !self.is_exchange_id(exchange_id) {
                Errors::OnchainIDNotTaggedAsExchange(exchange_id);
            }
            self.exchange_ids.entry(exchange_id).write(false);
            self.emit(ExchangeIDRemoved { exchange_id });
        }

        fn is_exchange_id(self: @ContractState, exchange_id: ContractAddress) -> bool {
            self.exchange_ids.entry(exchange_id).read()
        }

        fn get_monthly_counter(
            self: @ContractState,
            compliance: ContractAddress,
            exchange_id: ContractAddress,
            investor_id: ContractAddress,
        ) -> u256 {
            self
                .exchange_counters
                .entry((compliance, exchange_id, investor_id))
                .monthly_count
                .read()
        }

        fn get_monthly_timer(
            self: @ContractState,
            compliance: ContractAddress,
            exchange_id: ContractAddress,
            investor_id: ContractAddress,
        ) -> u64 {
            self
                .exchange_counters
                .entry((compliance, exchange_id, investor_id))
                .monthly_timer
                .read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn increase_exchange_counters(
            ref self: ContractState,
            compliance: ContractAddress,
            exchange_id: ContractAddress,
            investor_id: ContractAddress,
            value: u256,
        ) {
            self.reset_exchange_monthly_cooldown(compliance, exchange_id, investor_id);
            let monthly_count_storage_path = self
                .exchange_counters
                .entry((compliance, exchange_id, investor_id))
                .monthly_count
                .deref();

            let current_count = monthly_count_storage_path.read();
            monthly_count_storage_path.write(current_count + value);
        }

        fn reset_exchange_monthly_cooldown(
            ref self: ContractState,
            compliance: ContractAddress,
            exchange_id: ContractAddress,
            investor_id: ContractAddress,
        ) {
            if self.is_exchange_month_finished(compliance, exchange_id, investor_id) {
                let exchange_counter_storage_path = self
                    .exchange_counters
                    .entry((compliance, exchange_id, investor_id))
                    .deref();
                exchange_counter_storage_path
                    .monthly_timer
                    .write(starknet::get_block_timestamp() + 30 * DAY);
                exchange_counter_storage_path.monthly_count.write(Zero::zero());
            }
        }

        fn is_exchange_month_finished(
            self: @ContractState,
            compliance: ContractAddress,
            exchange_id: ContractAddress,
            investor_id: ContractAddress,
        ) -> bool {
            self
                .get_monthly_timer(
                    compliance, exchange_id, investor_id,
                ) <= starknet::get_block_timestamp()
                .into()
        }

        fn is_token_agent(
            self: @ContractState, compliance: ContractAddress, user_address: ContractAddress,
        ) -> bool {
            let token_bound = IModularComplianceDispatcher { contract_address: compliance }
                .get_token_bound();
            IAgentRoleDispatcher { contract_address: token_bound }.is_agent(user_address)
        }

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
