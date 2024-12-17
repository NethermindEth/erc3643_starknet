#[starknet::contract]
mod TREXGateway {
    use core::{num::traits::Zero, panic_with_felt252};
    use crate::{
        itrex_factory::{
            ClaimDetails, ITREXFactoryDispatcher, ITREXFactoryDispatcherTrait, TokenDetails,
        },
        itrex_gateway::{Fee, ITREXGateway},
    };
    use openzeppelin_access::ownable::{
        OwnableComponent, interface::{IOwnableDispatcher, IOwnableDispatcherTrait},
    };
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use roles::agent_role::AgentRoleComponent;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    component!(path: AgentRoleComponent, storage: agent_role, event: AgentRoleEvent);

    #[abi(embed_v0)]
    impl AgentRoleImpl = AgentRoleComponent::AgentRoleImpl<ContractState>;
    impl AgentRoleInternalImpl = AgentRoleComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        factory: ContractAddress,
        public_deployment_status: bool,
        deployment_fee: Fee,
        deployment_fee_enabled: bool,
        deployers: Map<ContractAddress, bool>,
        fee_discount: Map<ContractAddress, u16>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        agent_role: AgentRoleComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        FactorySet: FactorySet,
        PublicDeploymentStatusSet: PublicDeploymentStatusSet,
        DeploymentFeeSet: DeploymentFeeSet,
        DeploymentFeeEnabled: DeploymentFeeEnabled,
        DeployerAdded: DeployerAdded,
        DeployerRemoved: DeployerRemoved,
        FeeDiscountApplied: FeeDiscountApplied,
        GatewaySuiteDeploymentProcessed: GatewaySuiteDeploymentProcessed,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        AgentRoleEvent: AgentRoleComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FactorySet {
        #[key]
        factory: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PublicDeploymentStatusSet {
        #[key]
        public_deployment_status: bool,
    }

    #[derive(Drop, starknet::Event)]
    pub struct DeploymentFeeSet {
        #[key]
        fee: u256,
        #[key]
        fee_token: ContractAddress,
        #[key]
        fee_collector: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct DeploymentFeeEnabled {
        #[key]
        is_enabled: bool,
    }

    #[derive(Drop, starknet::Event)]
    pub struct DeployerAdded {
        #[key]
        deployer: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct DeployerRemoved {
        #[key]
        deployer: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FeeDiscountApplied {
        #[key]
        deployer: ContractAddress,
        discount: u16,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GatewaySuiteDeploymentProcessed {
        #[key]
        requester: ContractAddress,
        intended_owner: ContractAddress,
        fee_applied: u256,
    }

    pub mod Errors {
        pub const ZERO_ADDRESS: felt252 = 'Zero Address';
        pub const PUBLIC_DEPLOYMENT_ALREADY_ENABLED: felt252 = 'Public deploy already enabled';
        pub const PUBLIC_DEPLOYMENT_ALREADY_DISABLED: felt252 = 'Public deploy already disabled';
        pub const DEPLOYMENT_FEES_ALREADY_ENABLED: felt252 = 'Fees already enabled';
        pub const DEPLOYMENT_FEES_ALREADY_DISABLED: felt252 = 'Fees already disabled';
        pub const DEPLOYER_ALREADY_EXISTS: felt252 = 'Deployer already exists';
        pub const DEPLOYER_DOES_NOT_EXISTS: felt252 = 'Deployer does not exists';
        pub const PUBLIC_DEPLOYMENTS_NOT_ALLOWED: felt252 = 'Public deployment not allowed';
        pub const PUBLIC_CANNOT_DEPLOY_ON_BEHALF: felt252 = 'Public cannot deploy on behalf';
        pub const DISCOUNT_OUT_OF_RANGE: felt252 = 'Discount out of range';
        pub const ONLY_ADMIN_CALL: felt252 = 'Only admin call';
        pub const BATCH_MAX_LENGTH_EXCEEDED: felt252 = 'Batch max length exceeded';
        pub const ARRAY_LEN_MISMATCH: felt252 = 'Arrays have different length';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        factory: ContractAddress,
        public_deployment_status: bool,
        owner: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self.factory.write(factory);
        self.public_deployment_status.write(public_deployment_status);
        self.emit(FactorySet { factory });
        self.emit(PublicDeploymentStatusSet { public_deployment_status });
    }

    #[abi(embed_v0)]
    impl TREXGatewayImpl of ITREXGateway<ContractState> {
        fn set_factory(ref self: ContractState, factory: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(factory.is_non_zero(), Errors::ZERO_ADDRESS);
            self.factory.write(factory);
            self.emit(FactorySet { factory });
        }

        fn set_public_deployment_status(ref self: ContractState, is_enabled: bool) {
            self.ownable.assert_only_owner();
            let current_public_deployment_status = self.public_deployment_status.read();
            if is_enabled == current_public_deployment_status {
                if is_enabled {
                    panic_with_felt252(Errors::PUBLIC_DEPLOYMENT_ALREADY_ENABLED);
                } else {
                    panic_with_felt252(Errors::PUBLIC_DEPLOYMENT_ALREADY_DISABLED);
                }
            }

            self.public_deployment_status.write(is_enabled);
            self.emit(PublicDeploymentStatusSet { public_deployment_status: is_enabled });
        }

        fn transfer_factory_ownership(ref self: ContractState, new_owner: ContractAddress) {
            self.ownable.assert_only_owner();
            IOwnableDispatcher { contract_address: self.factory.read() }
                .transfer_ownership(new_owner);
        }

        fn enable_deployment_fee(ref self: ContractState, is_enabled: bool) {
            self.ownable.assert_only_owner();
            let deployment_fee_enabled = self.deployment_fee_enabled.read();
            if is_enabled == deployment_fee_enabled {
                if is_enabled {
                    panic_with_felt252(Errors::DEPLOYMENT_FEES_ALREADY_ENABLED);
                } else {
                    panic_with_felt252(Errors::DEPLOYMENT_FEES_ALREADY_DISABLED);
                }
            }

            self.deployment_fee_enabled.write(is_enabled);
            self.emit(DeploymentFeeEnabled { is_enabled });
        }

        /// TODO: check if fee needs to be constrained or not within a range.
        fn set_deployment_fee(
            ref self: ContractState,
            fee: u256,
            fee_token: ContractAddress,
            fee_collector: ContractAddress,
        ) {
            self.ownable.assert_only_owner();
            assert(fee_token.is_non_zero() && fee_collector.is_non_zero(), Errors::ZERO_ADDRESS);
            self.deployment_fee.write(Fee { fee, fee_token, fee_collector });
            self.emit(DeploymentFeeSet { fee, fee_token, fee_collector });
        }

        fn add_deployer(ref self: ContractState, deployer: ContractAddress) {
            let caller = starknet::get_caller_address();
            assert(
                self.agent_role.is_agent(caller) || self.ownable.owner() == caller,
                Errors::ONLY_ADMIN_CALL,
            );
            let deployer_storage_path = self.deployers.entry(deployer);
            assert(!deployer_storage_path.read(), Errors::DEPLOYER_ALREADY_EXISTS);
            deployer_storage_path.write(true);
            self.emit(DeployerAdded { deployer });
        }

        fn batch_add_deployer(ref self: ContractState, deployers: Span<ContractAddress>) {
            let caller = starknet::get_caller_address();
            assert(
                self.agent_role.is_agent(caller) || self.ownable.owner() == caller,
                Errors::ONLY_ADMIN_CALL,
            );
            assert(deployers.len() < 500, Errors::BATCH_MAX_LENGTH_EXCEEDED);
            for deployer in deployers {
                let deployer_storage_path = self.deployers.entry(*deployer);
                assert(!deployer_storage_path.read(), Errors::DEPLOYER_ALREADY_EXISTS);
                deployer_storage_path.write(true);
                self.emit(DeployerAdded { deployer: *deployer });
            };
        }

        fn remove_deployer(ref self: ContractState, deployer: ContractAddress) {
            let caller = starknet::get_caller_address();
            assert(
                self.agent_role.is_agent(caller) || self.ownable.owner() == caller,
                Errors::ONLY_ADMIN_CALL,
            );
            let deployer_storage_path = self.deployers.entry(deployer);
            assert(deployer_storage_path.read(), Errors::DEPLOYER_DOES_NOT_EXISTS);
            deployer_storage_path.write(false);
            self.emit(DeployerRemoved { deployer });
        }

        fn batch_remove_deployer(ref self: ContractState, deployers: Span<ContractAddress>) {
            let caller = starknet::get_caller_address();
            assert(
                self.agent_role.is_agent(caller) || self.ownable.owner() == caller,
                Errors::ONLY_ADMIN_CALL,
            );
            assert(deployers.len() < 500, Errors::BATCH_MAX_LENGTH_EXCEEDED);
            for deployer in deployers {
                let deployer_storage_path = self.deployers.entry(*deployer);
                assert(deployer_storage_path.read(), Errors::DEPLOYER_DOES_NOT_EXISTS);
                deployer_storage_path.write(false);
                self.emit(DeployerRemoved { deployer: *deployer });
            };
        }

        fn apply_fee_discount(ref self: ContractState, deployer: ContractAddress, discount: u16) {
            let caller = starknet::get_caller_address();
            assert(
                self.agent_role.is_agent(caller) || self.ownable.owner() == caller,
                Errors::ONLY_ADMIN_CALL,
            );
            assert(discount <= 10_000, Errors::DISCOUNT_OUT_OF_RANGE);

            self.fee_discount.entry(deployer).write(discount);
            self.emit(FeeDiscountApplied { deployer, discount });
        }

        fn batch_apply_fee_discount(
            ref self: ContractState, deployers: Span<ContractAddress>, discounts: Span<u16>,
        ) {
            let caller = starknet::get_caller_address();
            assert(
                self.agent_role.is_agent(caller) || self.ownable.owner() == caller,
                Errors::ONLY_ADMIN_CALL,
            );
            assert(deployers.len() == discounts.len(), Errors::ARRAY_LEN_MISMATCH);
            assert(deployers.len() <= 500, Errors::BATCH_MAX_LENGTH_EXCEEDED);
            for i in 0..deployers.len() {
                let discount = *discounts.at(i);
                assert(discount <= 10_000, Errors::DISCOUNT_OUT_OF_RANGE);
                let deployer = *deployers.at(i);
                self.fee_discount.entry(deployer).write(discount);
                self.emit(FeeDiscountApplied { deployer, discount });
            };
        }

        fn deploy_TREX_suite(
            ref self: ContractState, token_details: TokenDetails, claim_details: ClaimDetails,
        ) {
            let caller = starknet::get_caller_address();
            let public_deployment_status = self.public_deployment_status.read();
            assert(
                public_deployment_status || self.is_deployer(caller),
                Errors::PUBLIC_DEPLOYMENTS_NOT_ALLOWED,
            );
            assert(
                !public_deployment_status
                    || caller == token_details.owner
                    || self.is_deployer(caller),
                Errors::PUBLIC_CANNOT_DEPLOY_ON_BEHALF,
            );

            let mut fee_applied = 0;
            let deployment_fee_enabled = self.deployment_fee_enabled.read();
            if deployment_fee_enabled {
                let deployment_fee = self.deployment_fee.read();
                /// fee_discount range check might be unneccesary
                if deployment_fee.fee.is_non_zero()
                    && self.fee_discount.entry(caller).read() < 10_000 {
                    fee_applied = self.calculate_fee(caller);
                    assert(
                        IERC20Dispatcher { contract_address: deployment_fee.fee_token }
                            .transfer_from(caller, deployment_fee.fee_collector, fee_applied),
                        'ERC20: Transfer from failed',
                    );
                }
            }

            let mut serialized_data: Array<felt252> = array![];
            let token_owner = token_details.owner;
            token_owner.serialize(ref serialized_data);
            token_details.name.serialize(ref serialized_data);
            /// TODO: either pass the hash or pure data. Decide on factory.
            let salt = serialized_data.clone();
            ITREXFactoryDispatcher { contract_address: self.factory.read() }
                .deploy_TREX_suite(salt.span(), token_details, claim_details);
            self
                .emit(
                    GatewaySuiteDeploymentProcessed {
                        requester: caller, intended_owner: token_owner, fee_applied,
                    },
                );
        }

        fn batch_deploy_TREX_suite(
            ref self: ContractState,
            token_details: Span<TokenDetails>,
            claim_details: Span<ClaimDetails>,
        ) {
            assert(token_details.len().is_non_zero(), 'No token to deploy');
            assert(token_details.len() <= 5, Errors::BATCH_MAX_LENGTH_EXCEEDED);
            assert(token_details.len() == claim_details.len(), Errors::ARRAY_LEN_MISMATCH);

            let caller = starknet::get_caller_address();
            let public_deployment_status = self.public_deployment_status.read();
            let is_deployer = self.is_deployer(caller);

            assert(public_deployment_status || is_deployer, Errors::PUBLIC_DEPLOYMENTS_NOT_ALLOWED);

            if public_deployment_status && !is_deployer {
                for token in token_details {
                    assert(*token.owner == caller, Errors::PUBLIC_CANNOT_DEPLOY_ON_BEHALF);
                };
            }

            let deployment_fee_enabled = self.deployment_fee_enabled.read();
            let mut fee_applied = 0;
            if deployment_fee_enabled {
                let deployment_fee = self.deployment_fee.read();
                /// fee_discount range check might be unneccesary
                if deployment_fee.fee.is_non_zero()
                    && self.fee_discount.entry(caller).read() < 10_000 {
                    fee_applied = self.calculate_fee(caller);
                    let fee_total = fee_applied * token_details.len().into();
                    assert(
                        IERC20Dispatcher { contract_address: deployment_fee.fee_token }
                            .transfer_from(caller, deployment_fee.fee_collector, fee_total),
                        'ERC20: Transfer from failed',
                    );
                }
            }

            let factory_dispatcher = ITREXFactoryDispatcher {
                contract_address: self.factory.read(),
            };
            for i in 0..token_details.len() {
                let token_detail = token_details.at(i);

                let mut serialized_data: Array<felt252> = array![];
                token_detail.owner.serialize(ref serialized_data);
                token_detail.name.serialize(ref serialized_data);
                /// TODO: either pass the hash or pure data. Decide on factory.
                let salt = serialized_data.clone();
                factory_dispatcher
                    .deploy_TREX_suite(
                        salt.span(), token_detail.clone(), claim_details.at(i).clone(),
                    );
                self
                    .emit(
                        GatewaySuiteDeploymentProcessed {
                            requester: caller, intended_owner: *token_detail.owner, fee_applied,
                        },
                    );
            };
        }

        fn get_public_deployment_status(self: @ContractState) -> bool {
            self.public_deployment_status.read()
        }

        fn get_factory(self: @ContractState) -> ContractAddress {
            self.factory.read()
        }

        fn get_deployment_fee(self: @ContractState) -> Fee {
            self.deployment_fee.read()
        }

        fn is_deployment_fee_enabled(self: @ContractState) -> bool {
            self.deployment_fee_enabled.read()
        }

        fn is_deployer(self: @ContractState, deployer: ContractAddress) -> bool {
            self.deployers.entry(deployer).read()
        }

        fn calculate_fee(self: @ContractState, deployer: ContractAddress) -> u256 {
            let fee = self.deployment_fee.read().fee;
            let fee_discount = self.fee_discount.entry(deployer).read().into();
            fee - ((fee_discount * fee) / 10_000)
        }
    }
}
