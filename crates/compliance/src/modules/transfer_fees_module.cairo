use starknet::ContractAddress;

#[starknet::interface]
pub trait ITransferFeesModule<TContractState> {
    fn set_fee(ref self: TContractState, rate: u16, collector: ContractAddress);
    fn get_fee(self: @TContractState, compliance: ContractAddress) -> Fee;
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Fee {
    pub rate: u16, // [0, 10_000]
    pub collector: ContractAddress,
}

#[starknet::contract]
pub mod TransferFeesModule {
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
    use super::{Fee, ITransferFeesModule};
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
        fees: Map<ContractAddress, Fee>,
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
        FeeUpdated: FeeUpdated,
        #[flat]
        AbstractModuleEvent: AbstractModuleComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FeeUpdated {
        #[key]
        pub compliance: ContractAddress,
        pub rate: u16,
        pub collector: ContractAddress,
    }

    pub mod Errors {
        use starknet::ContractAddress;

        pub fn FeeIsOutOfRange(compliance: ContractAddress, rate: u16) {
            panic!("Fee is out of range! Compliance: {:?}, rate: {}", compliance, rate);
        }
        pub fn CollectorAddressIsNotVerified(
            compliance: ContractAddress, collector: ContractAddress,
        ) {
            panic!(
                "Collector address is not verified! Compliance {:?}, collector: {:?}",
                compliance,
                collector,
            );
        }

        pub fn IdentityNotFound(compliance: ContractAddress, address: ContractAddress) {
            panic!("Identity not found for compliance: {:?}, address: {:?}", compliance, address);
        }
        /// NOTE: Might convert this to fn to be more consistent
        pub const FEE_TRANSFER_FAILED: felt252 = 'Transfer fee collection failed';
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

            if sender_identity == receiver_identity {
                return;
            }

            let fee = contract_state.fees.entry(caller).read();
            if fee.rate.is_zero() || from == fee.collector || to == fee.collector {
                return;
            }

            let fee_amount = (value * fee.rate.into()) / 10_000;
            if fee_amount.is_zero() {
                return;
            }

            let token_address = IModularComplianceDispatcher { contract_address: caller }
                .get_token_bound();
            let mut token_dispatcher = ITokenDispatcher { contract_address: token_address };
            let sent = token_dispatcher.forced_transfer(to, fee.collector, fee_amount);
            assert(sent, Errors::FEE_TRANSFER_FAILED);
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
            true
        }

        fn can_compliance_bind(
            self: @AbstractModuleComponent::ComponentState<ContractState>,
            compliance: ContractAddress,
        ) -> bool {
            let token_address = IModularComplianceDispatcher { contract_address: compliance }
                .get_token_bound();
            IAgentRoleDispatcher { contract_address: token_address }
                .is_agent(starknet::get_contract_address())
        }

        fn is_plug_and_play(self: @AbstractModuleComponent::ComponentState<ContractState>) -> bool {
            false
        }

        fn name(self: @AbstractModuleComponent::ComponentState<ContractState>) -> ByteArray {
            "TransferFeesModule"
        }
    }

    #[abi(embed_v0)]
    impl TransferFeesModuleImpl of ITransferFeesModule<ContractState> {
        fn set_fee(ref self: ContractState, rate: u16, collector: ContractAddress) {
            self.abstract_module.only_compliance_call();
            let caller = starknet::get_caller_address();

            if rate > 10_000 {
                Errors::FeeIsOutOfRange(caller, rate);
            }

            let token_address = IModularComplianceDispatcher { contract_address: caller }
                .get_token_bound();
            let identity_registry = ITokenDispatcher { contract_address: token_address }
                .identity_registry();
            if !identity_registry.is_verified(collector) {
                Errors::CollectorAddressIsNotVerified(caller, collector);
            }

            self.fees.entry(caller).write(Fee { rate, collector });
            self.emit(FeeUpdated { compliance: caller, rate, collector });
        }

        fn get_fee(self: @ContractState, compliance: ContractAddress) -> Fee {
            self.fees.entry(compliance).read()
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
            if identity.is_zero() {
                Errors::IdentityNotFound(compliance, user_address);
            }
            identity
        }
    }
}
