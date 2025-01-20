use core::num::traits::Zero;
use starknet::ContractAddress;

#[starknet::interface]
pub trait ITimeTransferLimitsModule<TContractState> {
    fn batch_set_time_transfer_limit(ref self: TContractState, limits: Span<Limit>);
    fn batch_remove_time_transfer_limit(ref self: TContractState, limit_times: Span<u64>);
    fn set_time_transfer_limit(ref self: TContractState, limit: Limit);
    fn remove_time_transfer_limit(ref self: TContractState, limit_time: u64);
    fn get_time_transfer_limit(self: @TContractState, compliance: ContractAddress) -> Span<Limit>;
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct TransferCounter {
    pub value: u256,
    pub timer: u64,
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct Limit {
    pub limit_value: u256,
    pub limit_time: u64,
}

impl LimitZero of core::num::traits::Zero<Limit> {
    fn zero() -> Limit {
        Limit { limit_time: 0, limit_value: 0 }
    }

    #[inline]
    fn is_zero(self: @Limit) -> bool {
        self.limit_time.is_zero() && self.limit_value.is_zero()
    }

    #[inline]
    fn is_non_zero(self: @Limit) -> bool {
        !self.is_zero()
    }
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct IndexLimit {
    attributed_limit: bool,
    limit_index: u8,
}

impl BoolZero of Zero<bool> {
    fn zero() -> bool {
        false
    }

    #[inline]
    fn is_zero(self: @bool) -> bool {
        !*self
    }

    #[inline]
    fn is_non_zero(self: @bool) -> bool {
        *self
    }
}

impl LimitIndexZero of Zero<IndexLimit> {
    fn zero() -> IndexLimit {
        IndexLimit { attributed_limit: Zero::zero(), limit_index: 0 }
    }

    #[inline]
    fn is_zero(self: @IndexLimit) -> bool {
        self.attributed_limit.is_zero() && self.limit_index.is_zero()
    }

    #[inline]
    fn is_non_zero(self: @IndexLimit) -> bool {
        !self.is_zero()
    }
}

pub mod Errors {
    pub const LIMIT_TIME_NOT_FOUND: felt252 = 'Limit time not found';
    pub const IDENTITY_NOT_FOUND: felt252 = 'Identity not found';
    pub const LIMITS_ARRAY_SIZE_EXCEEDED: felt252 = 'Limits array size exceeded';
}

#[starknet::contract]
pub mod TimeTransferLimitsModule {
    use AbstractModuleComponent::InternalTrait as AbstractModuleInternalTrait;
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
    use storage::storage_array::{
        LimitVecToLimitArray, MutableStorageArrayTrait, StorageArrayLimit, StorageArrayTrait,
    };
    use super::Errors;
    use super::{IndexLimit, Limit, TransferCounter};
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
        limit_values: Map<(ContractAddress, u64), IndexLimit>,
        transfer_limits: Map<ContractAddress, StorageArrayLimit>,
        users_counter: Map<(ContractAddress, ContractAddress, u64), TransferCounter>,
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
        TimeTransferLimitUpdated: TimeTransferLimitUpdated,
        TimeTransferLimitRemoved: TimeTransferLimitRemoved,
        #[flat]
        AbstractModuleEvent: AbstractModuleComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TimeTransferLimitUpdated {
        #[key]
        pub compliance: ContractAddress,
        pub limit_time: u64,
        pub limit_value: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TimeTransferLimitRemoved {
        #[key]
        pub compliance: ContractAddress,
        pub limit_time: u64,
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgrades.upgrade(new_class_hash);
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
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
            contract_state.abstract_module.only_compliance_call();
            let caller = starknet::get_caller_address();
            contract_state.increase_counters(caller, from, value);
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

            if (from.is_zero()) {
                return true;
            }

            if (contract_state.is_token_agent(compliance, from)) {
                return true;
            }

            let sender_identity = contract_state.get_identity(compliance, from);
            let transfer_limits_storage_path = contract_state.transfer_limits.entry(compliance);
            let mut result = true;
            for i in 0..transfer_limits_storage_path.len() {
                let limit = transfer_limits_storage_path.at(i).read();
                if (value > limit.limit_value) {
                    result = false;
                    break;
                }

                let user_counters_storage_path = contract_state
                    .users_counter
                    .entry((compliance, sender_identity, limit.limit_time));
                if (!contract_state
                    .is_user_counter_finished(compliance, sender_identity, limit.limit_time)
                    && user_counters_storage_path.read().value
                    + value > limit.limit_value) {
                    result = false;
                    break;
                }
            };
            result
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
            "TimeTransferLimitsModule"
        }
    }

    #[abi(embed_v0)]
    impl TimeTransferLimitsModuleTrait of super::ITimeTransferLimitsModule<ContractState> {
        fn get_time_transfer_limit(
            self: @ContractState, compliance: ContractAddress,
        ) -> Span<Limit> {
            LimitVecToLimitArray::into(self.transfer_limits.entry(compliance)).span()
        }

        fn batch_set_time_transfer_limit(ref self: ContractState, limits: Span<Limit>) {
            self.abstract_module.only_compliance_call();
            for limit in limits {
                self._set_time_transfer_limit(*limit);
            }
        }

        fn batch_remove_time_transfer_limit(ref self: ContractState, limit_times: Span<u64>) {
            self.abstract_module.only_compliance_call();
            for limit_time in limit_times {
                self._remove_time_transfer_limit(*limit_time);
            }
        }

        fn set_time_transfer_limit(ref self: ContractState, limit: Limit) {
            self.abstract_module.only_compliance_call();
            self._set_time_transfer_limit(limit);
        }

        fn remove_time_transfer_limit(ref self: ContractState, limit_time: u64) {
            self.abstract_module.only_compliance_call();
            self._remove_time_transfer_limit(limit_time);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn increase_counters(
            ref self: ContractState,
            compliance: ContractAddress,
            user_address: ContractAddress,
            value: u256,
        ) {
            let identity = self.get_identity(compliance, user_address);
            let transfer_limits_storage_path = self.transfer_limits.entry(compliance);
            for i in 0..transfer_limits_storage_path.len() {
                let limit = transfer_limits_storage_path.at(i).read();
                self.reset_user_counter(compliance, identity, limit.limit_time);
                let user_counter_storage_path = self
                    .users_counter
                    .entry((compliance, identity, limit.limit_time));
                user_counter_storage_path
                    .value
                    .write(user_counter_storage_path.value.read() + value)
            };
        }

        fn reset_user_counter(
            ref self: ContractState,
            compliance: ContractAddress,
            identity: ContractAddress,
            limit_time: u64,
        ) {
            if self.is_user_counter_finished(compliance, identity, limit_time) {
                let user_counter_storage_path = self
                    .users_counter
                    .entry((compliance, identity, limit_time))
                    .deref();
                user_counter_storage_path
                    .timer
                    .write((starknet::get_block_timestamp() + limit_time.into()).into());
                user_counter_storage_path.value.write(Zero::zero());
            }
        }

        fn is_user_counter_finished(
            self: @ContractState,
            compliance: ContractAddress,
            identity: ContractAddress,
            limit_time: u64,
        ) -> bool {
            self
                .users_counter
                .entry((compliance, identity, limit_time))
                .read()
                .timer <= starknet::get_block_timestamp()
                .into()
        }

        fn get_identity(
            self: @ContractState, compliance: ContractAddress, user_address: ContractAddress,
        ) -> ContractAddress {
            let token_dispatcher = ITokenDispatcher {
                contract_address: IModularComplianceDispatcher { contract_address: compliance }
                    .get_token_bound(),
            };
            let identity = token_dispatcher.identity_registry().identity(user_address);
            assert(identity.is_non_zero(), Errors::IDENTITY_NOT_FOUND);
            identity
        }

        fn is_token_agent(
            self: @ContractState, compliance: ContractAddress, user_address: ContractAddress,
        ) -> bool {
            let token_bound = IModularComplianceDispatcher { contract_address: compliance }
                .get_token_bound();
            IAgentRoleDispatcher { contract_address: token_bound }.is_agent(user_address)
        }

        fn _remove_time_transfer_limit(ref self: ContractState, limit_time: u64) {
            let mut limit_found = false;
            let mut index: u64 = Default::default();
            let caller = starknet::get_caller_address();
            let transfer_limits_storage_path = self.transfer_limits.entry(caller);
            for i in 0..transfer_limits_storage_path.len() {
                let limit = transfer_limits_storage_path.at(i).read();
                if (limit.limit_time == limit_time) {
                    limit_found = true;
                    index = i;
                    break;
                }
            };

            assert(limit_found, Errors::LIMIT_TIME_NOT_FOUND);

            transfer_limits_storage_path.delete(index);
            self.limit_values.entry((caller, limit_time)).write(Zero::zero());
            self.emit(TimeTransferLimitRemoved { compliance: caller, limit_time });
        }

        fn _set_time_transfer_limit(ref self: ContractState, limit: Limit) {
            let caller = starknet::get_caller_address();
            let limit_values_storage_path = self.limit_values.entry((caller, limit.limit_time));
            let transfer_limits_storage_path = self.transfer_limits.entry(caller);
            let limit_is_attributed = limit_values_storage_path.read().attributed_limit;
            let limit_count: u8 = transfer_limits_storage_path
                .len()
                .try_into()
                .expect('Limit count exceeds u8');
            assert(limit_is_attributed || limit_count < 4, Errors::LIMITS_ARRAY_SIZE_EXCEEDED);
            if (!limit_is_attributed // && limit_count < 4
            ) {
                transfer_limits_storage_path.append().write(limit);
                limit_values_storage_path
                    .write(IndexLimit { attributed_limit: true, limit_index: limit_count });
            } else {
                transfer_limits_storage_path
                    .at(limit_values_storage_path.read().limit_index.into())
                    .write(limit);
            }

            self
                .emit(
                    TimeTransferLimitUpdated {
                        compliance: caller,
                        limit_time: limit.limit_time,
                        limit_value: limit.limit_value,
                    },
                );
        }
    }
}
