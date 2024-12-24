use starknet::ContractAddress;

#[derive(Drop, Copy, Serde)]
pub struct ExchangeTransferCounter {
    pub value: u256,
    pub timer: u64,
}

#[derive(Drop, Copy, Serde)]
pub struct Limit {
    pub limit_time: u64,
    pub limit_value: u256,
}

#[derive(Drop, Copy, Serde)]
pub struct IndexLimit {
    pub attributed_limit: bool,
    pub limit_index: u8,
}

#[starknet::interface]
pub trait ITimeExchangeLimitsModule<TContractState> {
    fn set_exchange_limit(ref self: TContractState, exchange_id: ContractAddress, limit: Limit);
    fn add_exchange_id(ref self: TContractState, exchange_id: ContractAddress);
    fn remove_exchange_id(ref self: TContractState, exchange_id: ContractAddress);
    fn is_exchange_id(self: @TContractState, exchange_id: ContractAddress) -> bool;
    fn get_exchange_counter(
        self: @TContractState,
        compliance: ContractAddress,
        exchange_id: ContractAddress,
        investor_id: ContractAddress,
        limit_time: u64,
    ) -> ExchangeTransferCounter;
    fn get_exchange_limits(
        self: @TContractState, compliance: ContractAddress, exchange_id: ContractAddress,
    ) -> Span<Limit>;
}

#[starknet::contract]
pub mod TimeExchangeLimitsModule {
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
        storage::{
            Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess,
            StoragePointerWriteAccess, Vec, VecTrait,
        },
    };
    use super::{ExchangeTransferCounter, Limit};
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
        limit_values: Map<(ContractAddress, ContractAddress, u64), IndexLimitStorageNode>,
        exchange_limits: Map<(ContractAddress, ContractAddress), Vec<LimitStorageNode>>,
        exchange_counters: Map<
            (ContractAddress, ContractAddress, ContractAddress),
            Map<u64, ExchangeTransferCounterStorageNode>,
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
    pub struct ExchangeTransferCounterStorageNode {
        value: u256,
        timer: u64,
    }

    #[starknet::storage_node]
    pub struct LimitStorageNode {
        limit_time: u64,
        limit_value: u256,
    }

    #[starknet::storage_node]
    pub struct IndexLimitStorageNode {
        attributed_limit: bool,
        limit_index: u8,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ExchangeLimitUpdated: ExchangeLimitUpdated,
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
    pub struct ExchangeLimitUpdated {
        #[key]
        pub compliance: ContractAddress,
        pub exchange_id: ContractAddress,
        pub limit_value: u256,
        pub limit_time: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ExchangeIDAdded {
        pub new_exchange_id: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ExchangeIDRemoved {
        pub exchange_id: ContractAddress,
    }

    pub mod Errors {
        use starknet::ContractAddress;

        pub fn OnchainIDAlreadyTaggedAsExchange(exchange_id: ContractAddress) {
            panic!("Onchain ID already tagges as exchange! OID {:?}", exchange_id);
        }
        pub fn OnchainIDNotTaggedAsExchange(exchange_id: ContractAddress) {
            panic!("Onchain ID not tagges as exchange! OID {:?}", exchange_id);
        }
        pub fn LimitsArraySizeExceeded(compliance: ContractAddress, exchange_id: ContractAddress) {
            panic!(
                "Limits array size exceeded. Compliance: {:?}, Exchange ID: {:?}",
                compliance,
                exchange_id,
            );
        }
        pub fn IdentityNotFound(compliance: ContractAddress, address: ContractAddress) {
            panic!("Identity not found for compliance: {:?}, address: {:?}", compliance, address);
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

            let receiver_limits_storage_path = contract_state
                .exchange_limits
                .entry((compliance, receiver_identity));

            let mut check = true;
            let exchange_counter_storage_path = contract_state
                .exchange_counters
                .entry((compliance, receiver_identity, sender_identity));
            for i in 0..receiver_limits_storage_path.len() {
                let receiver_limits_at_i = receiver_limits_storage_path.at(i).deref();
                let limit_value = receiver_limits_at_i.limit_value.read();
                if value > limit_value {
                    check = false;
                    break;
                }

                let limit_time = receiver_limits_at_i.limit_time.read();
                if !contract_state
                    .is_exchange_counter_finished(
                        compliance, receiver_identity, sender_identity, limit_time,
                    )
                    && exchange_counter_storage_path.entry(limit_time).value.read()
                    + value > limit_value {
                    check = false;
                    break;
                }
            };
            check
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
            "TimeExchangeLimitsModule"
        }
    }

    #[abi(embed_v0)]
    impl TimeExchangeLimitsModuleImpl of super::ITimeExchangeLimitsModule<ContractState> {
        fn set_exchange_limit(ref self: ContractState, exchange_id: ContractAddress, limit: Limit) {
            self.abstract_module.only_compliance_call();
            let caller = starknet::get_caller_address();
            let index_limit_storage_path = self
                .limit_values
                .entry((caller, exchange_id, limit.limit_time))
                .deref();
            let is_attributed_limit = index_limit_storage_path.attributed_limit.read();

            let exchange_limits_storage_path = self.exchange_limits.entry((caller, exchange_id));
            let limit_count = exchange_limits_storage_path.len();
            if !is_attributed_limit && limit_count >= 4 {
                Errors::LimitsArraySizeExceeded(caller, exchange_id);
            }

            if !is_attributed_limit {
                let new_limit_storage_path = exchange_limits_storage_path.append();
                new_limit_storage_path.limit_time.write(limit.limit_time);
                new_limit_storage_path.limit_value.write(limit.limit_value);

                index_limit_storage_path.attributed_limit.write(true);
                index_limit_storage_path.limit_index.write(limit_count.try_into().unwrap());
            } else {
                let limit_storage_path = exchange_limits_storage_path
                    .at(index_limit_storage_path.limit_index.read().into())
                    .deref();
                /// NOTE: might not need to write limit_time again since to override limit_time
                /// should be same
                limit_storage_path.limit_time.write(limit.limit_time);
                limit_storage_path.limit_value.write(limit.limit_value);
            }

            self
                .emit(
                    ExchangeLimitUpdated {
                        compliance: caller,
                        exchange_id,
                        limit_value: limit.limit_value,
                        limit_time: limit.limit_time,
                    },
                );
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

        fn get_exchange_counter(
            self: @ContractState,
            compliance: ContractAddress,
            exchange_id: ContractAddress,
            investor_id: ContractAddress,
            limit_time: u64,
        ) -> ExchangeTransferCounter {
            let exchange_counter = self
                .exchange_counters
                .entry((compliance, exchange_id, investor_id))
                .entry(limit_time)
                .deref();
            ExchangeTransferCounter {
                value: exchange_counter.value.read(), timer: exchange_counter.timer.read(),
            }
        }

        fn get_exchange_limits(
            self: @ContractState, compliance: ContractAddress, exchange_id: ContractAddress,
        ) -> Span<Limit> {
            let limits_storage_path = self.exchange_limits.entry((compliance, exchange_id));

            let mut limits = array![];
            for i in 0..limits_storage_path.len() {
                let limit_storage_path = limits_storage_path.at(i);
                limits
                    .append(
                        Limit {
                            limit_time: limit_storage_path.limit_time.read(),
                            limit_value: limit_storage_path.limit_value.read(),
                        },
                    );
            };
            limits.span()
        }

        fn is_exchange_id(self: @ContractState, exchange_id: ContractAddress) -> bool {
            self.exchange_ids.entry(exchange_id).read()
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
            let exchange_limits_storage_path = self
                .exchange_limits
                .entry((compliance, exchange_id));

            let exchange_counter_storage_path = self
                .exchange_counters
                .entry((compliance, exchange_id, investor_id));

            for i in 0..exchange_limits_storage_path.len() {
                let limit_time = exchange_limits_storage_path.at(i).limit_time.read();
                self
                    .reset_exchange_limit_cooldown(
                        compliance, exchange_id, investor_id, limit_time,
                    );
                let counter_storage_path = exchange_counter_storage_path
                    .entry(limit_time)
                    .value
                    .deref();

                let current_counter = counter_storage_path.read();
                counter_storage_path.write(current_counter + value);
            }
        }

        fn reset_exchange_limit_cooldown(
            ref self: ContractState,
            compliance: ContractAddress,
            exchange_id: ContractAddress,
            investor_id: ContractAddress,
            limit_time: u64,
        ) {
            if self.is_exchange_counter_finished(compliance, exchange_id, investor_id, limit_time) {
                let exchange_counter_storage_path = self
                    .exchange_counters
                    .entry((compliance, exchange_id, investor_id))
                    .entry(limit_time)
                    .deref();
                exchange_counter_storage_path
                    .timer
                    .write(starknet::get_block_timestamp() + limit_time);
                exchange_counter_storage_path.value.write(Zero::zero());
            }
        }

        fn is_exchange_counter_finished(
            self: @ContractState,
            compliance: ContractAddress,
            exchange_id: ContractAddress,
            identity: ContractAddress,
            limit_time: u64,
        ) -> bool {
            self
                .exchange_counters
                .entry((compliance, exchange_id, identity))
                .entry(limit_time)
                .timer
                .read() <= starknet::get_block_timestamp()
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
            if identity.is_zero() {
                Errors::IdentityNotFound(compliance, user_address);
            }
            identity
        }
    }
}
