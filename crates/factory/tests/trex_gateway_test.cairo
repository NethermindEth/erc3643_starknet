use core::poseidon::poseidon_hash_span;
use factory::{
    itrex_factory::{ITREXFactoryDispatcherTrait, TokenDetails},
    itrex_gateway::ITREXGatewayDispatcher, tests_common::{FullSuiteSetup, setup_full_suite},
    trex_factory::TREXFactory, trex_gateway::TREXGateway,
};
use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use openzeppelin_token::erc20::interface::IERC20Dispatcher;
use registry::interface::iidentity_registry::IIdentityRegistryDispatcherTrait;
use roles::agent_role::{IAgentRoleDispatcher, IAgentRoleDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpy, EventSpyAssertionsTrait, declare,
};
use starknet::ContractAddress;
use token::itoken::{ITokenDispatcher, ITokenDispatcherTrait};

fn setup_gateway(public_deployment_status: bool) -> (FullSuiteSetup, ITREXGatewayDispatcher) {
    let setup = setup_full_suite();
    let gateway_contract = declare("TREXGateway").unwrap().contract_class();
    let (gateway_address, _) = gateway_contract
        .deploy(
            @array![
                setup.trex_factory.contract_address.into(),
                public_deployment_status.into(),
                starknet::get_contract_address().into(),
            ],
        )
        .unwrap();
    IOwnableDispatcher { contract_address: setup.trex_factory.contract_address }
        .transfer_ownership(gateway_address);
    let gateway_dispatcher = ITREXGatewayDispatcher { contract_address: gateway_address };
    let agent_role_dispatcher = IAgentRoleDispatcher { contract_address: gateway_address };
    agent_role_dispatcher.add_agent(setup.accounts.token_agent.account.contract_address);
    (setup, gateway_dispatcher)
}

fn assert_deployment_events_emitted(
    setup: @FullSuiteSetup,
    gateway: ITREXGatewayDispatcher,
    ref spy: EventSpy,
    token_details: TokenDetails,
    requester: ContractAddress,
    expected_fee: u256,
) {
    spy
        .assert_emitted(
            @array![
                (
                    gateway.contract_address,
                    TREXGateway::Event::GatewaySuiteDeploymentProcessed(
                        TREXGateway::GatewaySuiteDeploymentProcessed {
                            requester,
                            intended_owner: token_details.owner,
                            fee_applied: expected_fee,
                        },
                    ),
                ),
            ],
        );

    let mut salt_preimage: Array<felt252> = array![token_details.owner.into()];
    token_details.name.serialize(ref salt_preimage);
    let salt = poseidon_hash_span(salt_preimage.span());

    let token_address = (*setup.trex_factory).get_token(salt);
    let token = ITokenDispatcher { contract_address: token_address };
    let identity_registry = token.identity_registry();
    let compliance = token.compliance();
    let identity_registry_storage = identity_registry.identity_storage();
    let trusted_issuers_registry = identity_registry.issuers_registry();
    let claim_topics_registry = identity_registry.topics_registry();

    spy
        .assert_emitted(
            @array![
                (
                    *setup.trex_factory.contract_address,
                    TREXFactory::Event::TREXSuiteDeployed(
                        TREXFactory::TREXSuiteDeployed {
                            token: token_address,
                            ir: identity_registry.contract_address,
                            irs: identity_registry_storage.contract_address,
                            tir: trusted_issuers_registry.contract_address,
                            ctr: claim_topics_registry.contract_address,
                            mc: compliance.contract_address,
                            salt,
                        },
                    ),
                ),
            ],
        );
}

fn deploy_fee_token() -> IERC20Dispatcher {
    let (fee_token_address, _) = declare("MockERC20")
        .unwrap()
        .contract_class()
        .deploy(@array![starknet::get_contract_address().into()])
        .unwrap();
    IERC20Dispatcher { contract_address: fee_token_address }
}

pub mod set_factory {
    use core::num::traits::Zero;
    use factory::{itrex_gateway::ITREXGatewayDispatcherTrait, trex_gateway::TREXGateway};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup_gateway;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_owner() {
        let (_, gateway) = setup_gateway(false);
        let new_factory = starknet::contract_address_const::<'ANOTHER_FACTORY'>();
        start_cheat_caller_address(
            gateway.contract_address, starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        gateway.set_factory(new_factory);
        stop_cheat_caller_address(gateway.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Zero Address')]
    fn test_should_panic_when_factory_address_zero() {
        let (_, gateway) = setup_gateway(false);

        gateway.set_factory(Zero::zero());
    }

    #[test]
    fn test_should_set_factory() {
        let (_, gateway) = setup_gateway(false);
        let new_factory = starknet::contract_address_const::<'ANOTHER_FACTORY'>();
        let mut spy = spy_events();

        gateway.set_factory(new_factory);

        assert(gateway.get_factory() == new_factory, 'Factory not set');
        spy
            .assert_emitted(
                @array![
                    (
                        gateway.contract_address,
                        TREXGateway::Event::FactorySet(
                            TREXGateway::FactorySet { factory: new_factory },
                        ),
                    ),
                ],
            );
    }
}

pub mod set_public_deployment_status {
    use factory::{itrex_gateway::ITREXGatewayDispatcherTrait, trex_gateway::TREXGateway};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup_gateway;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_owner() {
        let (_, gateway) = setup_gateway(false);
        start_cheat_caller_address(
            gateway.contract_address, starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        gateway.set_public_deployment_status(true);
        stop_cheat_caller_address(gateway.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Public deploy already enabled')]
    fn test_should_panic_when_enabled_when_doesnt_change_status() {
        let (_, gateway) = setup_gateway(true);

        gateway.set_public_deployment_status(true);
    }

    #[test]
    #[should_panic(expected: 'Public deploy already disabled')]
    fn test_should_panic_when_disabled_when_doesnt_change_status() {
        let (_, gateway) = setup_gateway(false);

        gateway.set_public_deployment_status(false);
    }

    #[test]
    fn test_should_set_new_status() {
        let (_, gateway) = setup_gateway(false);
        let mut spy = spy_events();
        /// Set status false -> true
        gateway.set_public_deployment_status(true);
        assert(gateway.get_public_deployment_status() == true, 'Status didnt changed');
        spy
            .assert_emitted(
                @array![
                    (
                        gateway.contract_address,
                        TREXGateway::Event::PublicDeploymentStatusSet(
                            TREXGateway::PublicDeploymentStatusSet {
                                public_deployment_status: true,
                            },
                        ),
                    ),
                ],
            );
        /// Set status true -> false
        let mut spy = spy_events();
        gateway.set_public_deployment_status(false);
        assert(gateway.get_public_deployment_status() == false, 'Status didnt changed');
        spy
            .assert_emitted(
                @array![
                    (
                        gateway.contract_address,
                        TREXGateway::Event::PublicDeploymentStatusSet(
                            TREXGateway::PublicDeploymentStatusSet {
                                public_deployment_status: false,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod transfer_factory_ownership {
    use factory::itrex_gateway::ITREXGatewayDispatcherTrait;
    use openzeppelin_access::ownable::{
        OwnableComponent, interface::{IOwnableDispatcher, IOwnableDispatcherTrait},
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup_gateway;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_owner() {
        let (_, gateway) = setup_gateway(false);
        start_cheat_caller_address(
            gateway.contract_address, starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        gateway.transfer_factory_ownership(starknet::contract_address_const::<'SOME_ADDRESS'>());
        stop_cheat_caller_address(gateway.contract_address);
    }

    #[test]
    fn test_should_transfer_factory_ownership() {
        let (setup, gateway) = setup_gateway(false);

        let mut spy = spy_events();
        let new_owner = starknet::contract_address_const::<'SOME_ADDRESS'>();
        gateway.transfer_factory_ownership(new_owner);

        assert(
            IOwnableDispatcher { contract_address: setup.trex_factory.contract_address }
                .owner() == new_owner,
            'Ownership didnt transferred',
        );
        spy
            .assert_emitted(
                @array![
                    (
                        setup.trex_factory.contract_address,
                        OwnableComponent::Event::OwnershipTransferred(
                            OwnableComponent::OwnershipTransferred {
                                previous_owner: gateway.contract_address, new_owner,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod enable_deployment_fee {
    use factory::{itrex_gateway::ITREXGatewayDispatcherTrait, trex_gateway::TREXGateway};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup_gateway;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_owner() {
        let (_, gateway) = setup_gateway(false);
        start_cheat_caller_address(
            gateway.contract_address, starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        gateway.enable_deployment_fee(true);
        stop_cheat_caller_address(gateway.contract_address);
    }

    #[should_panic(expected: 'Fees already enabled')]
    fn test_should_panic_when_enabled_when_doesnt_change_status() {
        let (_, gateway) = setup_gateway(false);
        gateway.enable_deployment_fee(true);
        /// second time enabling should panic
        gateway.enable_deployment_fee(true);
    }

    #[test]
    #[should_panic(expected: 'Fees already disabled')]
    fn test_should_panic_when_disabled_when_doesnt_change_status() {
        let (_, gateway) = setup_gateway(false);

        gateway.enable_deployment_fee(false);
    }

    #[test]
    fn test_should_set_enable_fees() {
        let (_, gateway) = setup_gateway(false);

        let mut spy = spy_events();
        gateway.enable_deployment_fee(true);
        assert(gateway.is_deployment_fee_enabled(), 'Fee not enabled');
        spy
            .assert_emitted(
                @array![
                    (
                        gateway.contract_address,
                        TREXGateway::Event::DeploymentFeeEnabled(
                            TREXGateway::DeploymentFeeEnabled { is_enabled: true },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_should_set_disable_fees() {
        let (_, gateway) = setup_gateway(false);
        gateway.enable_deployment_fee(true);

        let mut spy = spy_events();
        gateway.enable_deployment_fee(false);
        assert(!gateway.is_deployment_fee_enabled(), 'Fee not disabled');
        spy
            .assert_emitted(
                @array![
                    (
                        gateway.contract_address,
                        TREXGateway::Event::DeploymentFeeEnabled(
                            TREXGateway::DeploymentFeeEnabled { is_enabled: false },
                        ),
                    ),
                ],
            );
    }
}

pub mod set_deployment_fee {
    use core::num::traits::Zero;
    use factory::{itrex_gateway::ITREXGatewayDispatcherTrait, trex_gateway::TREXGateway};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup_gateway;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_owner() {
        let (setup, gateway) = setup_gateway(false);
        let fee_collector = starknet::contract_address_const::<'FEE_COLLECTOR'>();
        let fee_token = setup.token.contract_address;
        let fee = 100;

        start_cheat_caller_address(
            gateway.contract_address, starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        gateway.set_deployment_fee(fee, fee_token, fee_collector);
        stop_cheat_caller_address(gateway.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Zero Address')]
    fn test_should_panic_when_fee_collector_zero_address() {
        let (setup, gateway) = setup_gateway(false);
        let fee_token = setup.token.contract_address;
        let fee = 100;

        gateway.set_deployment_fee(fee, fee_token, Zero::zero());
    }

    #[test]
    #[should_panic(expected: 'Zero Address')]
    fn test_should_panic_when_fee_token_zero_address() {
        let (_, gateway) = setup_gateway(false);
        let fee_collector = starknet::contract_address_const::<'FEE_COLLECTOR'>();
        let fee = 100;

        gateway.set_deployment_fee(fee, Zero::zero(), fee_collector);
    }

    #[test]
    fn test_should_set_new_fees_structure() {
        let (setup, gateway) = setup_gateway(false);
        let fee_collector = starknet::contract_address_const::<'FEE_COLLECTOR'>();
        let fee_token = setup.token.contract_address;
        let fee = 100;

        let mut spy = spy_events();
        gateway.set_deployment_fee(fee, fee_token, fee_collector);

        let deployment_fee = gateway.get_deployment_fee();
        assert(deployment_fee.fee == fee, 'Fee does not match');
        assert(deployment_fee.fee_token == fee_token, 'Fee Token does not match');
        assert(deployment_fee.fee_collector == fee_collector, 'Fee Collector does not match');
        spy
            .assert_emitted(
                @array![
                    (
                        gateway.contract_address,
                        TREXGateway::Event::DeploymentFeeSet(
                            TREXGateway::DeploymentFeeSet { fee, fee_token, fee_collector },
                        ),
                    ),
                ],
            );
    }
}

pub mod add_deployer {
    use factory::{itrex_gateway::ITREXGatewayDispatcherTrait, trex_gateway::TREXGateway};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup_gateway;

    #[test]
    #[should_panic(expected: 'Only admin can call')]
    fn test_should_panic_when_called_by_not_admin() {
        let (setup, gateway) = setup_gateway(false);

        start_cheat_caller_address(
            gateway.contract_address, starknet::contract_address_const::<'NOT_ADMIN'>(),
        );
        gateway.add_deployer(setup.accounts.alice.account.contract_address);
        stop_cheat_caller_address(gateway.contract_address);
    }

    #[test]
    fn test_should_add_new_deployer_when_called_by_owner() {
        let (setup, gateway) = setup_gateway(false);
        let deployer = setup.accounts.alice.account.contract_address;
        let mut spy = spy_events();

        gateway.add_deployer(deployer);

        assert(gateway.is_deployer(deployer), 'Deployer not added');
        spy
            .assert_emitted(
                @array![
                    (
                        gateway.contract_address,
                        TREXGateway::Event::DeployerAdded(TREXGateway::DeployerAdded { deployer }),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic(expected: 'Deployer already exists')]
    fn test_should_panic_when_called_by_owner_when_deployer_already_exists() {
        let (setup, gateway) = setup_gateway(false);
        let deployer = setup.accounts.alice.account.contract_address;

        gateway.add_deployer(deployer);
        // Second time adding same deployer should panic
        gateway.add_deployer(deployer);
    }

    #[test]
    fn test_should_add_new_deployer_when_called_by_agent() {
        let (setup, gateway) = setup_gateway(false);
        let deployer = setup.accounts.alice.account.contract_address;
        let agent = setup.accounts.token_agent.account.contract_address;
        let mut spy = spy_events();

        start_cheat_caller_address(gateway.contract_address, agent);
        gateway.add_deployer(deployer);
        stop_cheat_caller_address(gateway.contract_address);

        assert(gateway.is_deployer(deployer), 'Deployer not added');
        spy
            .assert_emitted(
                @array![
                    (
                        gateway.contract_address,
                        TREXGateway::Event::DeployerAdded(TREXGateway::DeployerAdded { deployer }),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic(expected: 'Deployer already exists')]
    fn test_should_panic_when_called_by_agent_if_deployer_already_exists() {
        let (setup, gateway) = setup_gateway(false);
        let deployer = setup.accounts.alice.account.contract_address;

        start_cheat_caller_address(
            gateway.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        gateway.add_deployer(deployer);
        // Second time adding same deployer should panic
        gateway.add_deployer(deployer);
        stop_cheat_caller_address(gateway.contract_address);
    }
}

pub mod batch_add_deployer {
    use factory::{itrex_gateway::ITREXGatewayDispatcherTrait, trex_gateway::TREXGateway};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup_gateway;

    #[test]
    #[should_panic(expected: 'Only admin can call')]
    fn test_should_panic_when_called_by_not_admin() {
        let (setup, gateway) = setup_gateway(false);

        start_cheat_caller_address(
            gateway.contract_address, starknet::contract_address_const::<'NOT_ADMIN'>(),
        );
        gateway.batch_add_deployer([setup.accounts.alice.account.contract_address].span());
        stop_cheat_caller_address(gateway.contract_address);
    }

    #[test]
    fn test_should_add_new_deployers_when_called_by_owner() {
        let (setup, gateway) = setup_gateway(false);
        let first_deployer = setup.accounts.alice.account.contract_address;
        let second_deployer = setup.accounts.bob.account.contract_address;
        let mut spy = spy_events();

        gateway.batch_add_deployer([first_deployer, second_deployer].span());
        assert(gateway.is_deployer(first_deployer), 'Deployer not added');
        assert(gateway.is_deployer(second_deployer), 'Deployer not added');
        spy
            .assert_emitted(
                @array![
                    (
                        gateway.contract_address,
                        TREXGateway::Event::DeployerAdded(
                            TREXGateway::DeployerAdded { deployer: first_deployer },
                        ),
                    ),
                    (
                        gateway.contract_address,
                        TREXGateway::Event::DeployerAdded(
                            TREXGateway::DeployerAdded { deployer: second_deployer },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic(expected: 'Deployer already exists')]
    fn test_should_panic_when_called_by_owner_when_batch_includes_already_registered_deployer() {
        let (setup, gateway) = setup_gateway(false);
        let deployer = setup.accounts.alice.account.contract_address;
        gateway.add_deployer(deployer);
        let mut deployers = array![];
        for i in 100..110_u128 {
            deployers.append(Into::<u128, felt252>::into(i).try_into().unwrap());
        };
        deployers.append(deployer);
        // When batch has registered deployer should revert the whole batch
        gateway.batch_add_deployer(deployers.span());
    }

    #[test]
    #[should_panic(expected: 'Batch max length exceeded')]
    fn test_should_panic_when_called_by_owner_when_batch_size_exceeds_max() {
        let (_, gateway) = setup_gateway(false);

        let mut deployers = array![];
        for i in 100..601_u128 {
            deployers.append(Into::<u128, felt252>::into(i).try_into().unwrap());
        };

        gateway.batch_add_deployer(deployers.span());
    }

    #[test]
    #[should_panic(expected: 'Deployer already exists')]
    fn test_should_panic_when_called_by_agent_when_batch_includes_already_registered_deployer() {
        let (setup, gateway) = setup_gateway(false);
        let deployer = setup.accounts.alice.account.contract_address;
        start_cheat_caller_address(
            gateway.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        gateway.add_deployer(deployer);
        let mut deployers = array![];
        for i in 100..110_u128 {
            deployers.append(Into::<u128, felt252>::into(i).try_into().unwrap());
        };
        deployers.append(deployer);
        // When batch has registered deployer should revert the whole batch
        gateway.batch_add_deployer(deployers.span());
        stop_cheat_caller_address(gateway.contract_address);
    }

    #[test]
    fn test_should_add_new_deployers_when_called_by_agent() {
        let (setup, gateway) = setup_gateway(false);
        let first_deployer = setup.accounts.alice.account.contract_address;
        let second_deployer = setup.accounts.bob.account.contract_address;
        let mut spy = spy_events();

        start_cheat_caller_address(
            gateway.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        gateway.batch_add_deployer([first_deployer, second_deployer].span());
        stop_cheat_caller_address(gateway.contract_address);

        assert(gateway.is_deployer(first_deployer), 'Deployer not added');
        assert(gateway.is_deployer(second_deployer), 'Deployer not added');
        spy
            .assert_emitted(
                @array![
                    (
                        gateway.contract_address,
                        TREXGateway::Event::DeployerAdded(
                            TREXGateway::DeployerAdded { deployer: first_deployer },
                        ),
                    ),
                    (
                        gateway.contract_address,
                        TREXGateway::Event::DeployerAdded(
                            TREXGateway::DeployerAdded { deployer: second_deployer },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic(expected: 'Batch max length exceeded')]
    fn test_should_panic_when_called_by_agent_when_batch_size_exceeds_max() {
        let (setup, gateway) = setup_gateway(false);

        let mut deployers = array![];
        for i in 100..601_u128 {
            deployers.append(Into::<u128, felt252>::into(i).try_into().unwrap());
        };

        start_cheat_caller_address(
            gateway.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        gateway.batch_add_deployer(deployers.span());
        stop_cheat_caller_address(gateway.contract_address);
    }
}

pub mod remove_deployer {
    use factory::{itrex_gateway::ITREXGatewayDispatcherTrait, trex_gateway::TREXGateway};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup_gateway;

    #[test]
    #[should_panic(expected: 'Only admin can call')]
    fn test_should_panic_when_called_by_not_admin() {
        let (setup, gateway) = setup_gateway(false);
        let deployer = setup.accounts.alice.account.contract_address;

        start_cheat_caller_address(
            gateway.contract_address, starknet::contract_address_const::<'NOT_ADMIN'>(),
        );
        gateway.remove_deployer(deployer);
        stop_cheat_caller_address(gateway.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Deployer does not exists')]
    fn test_should_panic_when_called_by_owner_deployer_does_not_exist() {
        let (setup, gateway) = setup_gateway(false);
        let deployer = setup.accounts.alice.account.contract_address;

        gateway.remove_deployer(deployer);
    }

    #[test]
    fn test_should_remove_deployer_when_called_by_owner() {
        let (setup, gateway) = setup_gateway(false);
        let deployer = setup.accounts.alice.account.contract_address;
        gateway.add_deployer(deployer);

        let mut spy = spy_events();
        gateway.remove_deployer(deployer);

        assert(!gateway.is_deployer(deployer), 'Deployer not removed');
        spy
            .assert_emitted(
                @array![
                    (
                        gateway.contract_address,
                        TREXGateway::Event::DeployerRemoved(
                            TREXGateway::DeployerRemoved { deployer },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic(expected: 'Deployer does not exists')]
    fn test_should_panic_when_called_by_agent_deployer_does_not_exist() {
        let (setup, gateway) = setup_gateway(false);
        let deployer = setup.accounts.alice.account.contract_address;

        start_cheat_caller_address(
            gateway.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        gateway.remove_deployer(deployer);
        stop_cheat_caller_address(gateway.contract_address);
    }

    #[test]
    fn test_should_remove_deployer_when_called_by_agent() {
        let (setup, gateway) = setup_gateway(false);
        let deployer = setup.accounts.alice.account.contract_address;
        gateway.add_deployer(deployer);

        let mut spy = spy_events();
        start_cheat_caller_address(
            gateway.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        gateway.remove_deployer(deployer);
        stop_cheat_caller_address(gateway.contract_address);

        assert(!gateway.is_deployer(deployer), 'Deployer not removed');
        spy
            .assert_emitted(
                @array![
                    (
                        gateway.contract_address,
                        TREXGateway::Event::DeployerRemoved(
                            TREXGateway::DeployerRemoved { deployer },
                        ),
                    ),
                ],
            );
    }
}

pub mod batch_remove_deployer {
    use factory::{itrex_gateway::ITREXGatewayDispatcherTrait, trex_gateway::TREXGateway};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup_gateway;

    #[test]
    #[should_panic(expected: 'Only admin can call')]
    fn test_should_panic_when_called_by_not_admin() {
        let (setup, gateway) = setup_gateway(false);
        let deployer = setup.accounts.alice.account.contract_address;

        start_cheat_caller_address(
            gateway.contract_address, starknet::contract_address_const::<'NOT_ADMIN'>(),
        );
        gateway.batch_remove_deployer([deployer].span());
        stop_cheat_caller_address(gateway.contract_address);
    }

    #[test]
    fn test_should_remove_deployers_when_called_by_owner() {
        let (setup, gateway) = setup_gateway(false);
        let first_deployer = setup.accounts.alice.account.contract_address;
        let second_deployer = setup.accounts.bob.account.contract_address;
        gateway.batch_add_deployer([first_deployer, second_deployer].span());

        let mut spy = spy_events();
        gateway.batch_remove_deployer([first_deployer, second_deployer].span());

        assert(!gateway.is_deployer(first_deployer), 'Deployer not removed');
        assert(!gateway.is_deployer(second_deployer), 'Deployer not removed');
        spy
            .assert_emitted(
                @array![
                    (
                        gateway.contract_address,
                        TREXGateway::Event::DeployerRemoved(
                            TREXGateway::DeployerRemoved { deployer: first_deployer },
                        ),
                    ),
                    (
                        gateway.contract_address,
                        TREXGateway::Event::DeployerRemoved(
                            TREXGateway::DeployerRemoved { deployer: second_deployer },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic(expected: 'Deployer does not exists')]
    fn test_should_panic_when_called_by_owner_when_at_least_one_deployer_does_not_exist() {
        let (setup, gateway) = setup_gateway(false);
        let first_deployer = setup.accounts.alice.account.contract_address;
        let second_deployer = setup.accounts.bob.account.contract_address;
        gateway.batch_add_deployer([first_deployer, second_deployer].span());

        gateway
            .batch_remove_deployer(
                [
                    first_deployer, starknet::contract_address_const::<'NOT_DEPLOYER'>(),
                    second_deployer,
                ]
                    .span(),
            );
    }

    #[test]
    #[should_panic(expected: 'Batch max length exceeded')]
    fn test_should_panic_when_when_called_by_owner_when_batch_size_exceeds_max() {
        let (_, gateway) = setup_gateway(false);

        let mut deployers = array![];
        for i in 100..601_u128 {
            deployers.append(Into::<u128, felt252>::into(i).try_into().unwrap());
        };

        gateway.batch_remove_deployer(deployers.span());
    }

    #[test]
    #[should_panic(expected: 'Deployer does not exists')]
    fn test_should_panic_when_called_by_agent_when_at_least_one_deployer_does_not_exist() {
        let (setup, gateway) = setup_gateway(false);
        let first_deployer = setup.accounts.alice.account.contract_address;
        let second_deployer = setup.accounts.bob.account.contract_address;
        gateway.batch_add_deployer([first_deployer, second_deployer].span());

        start_cheat_caller_address(
            gateway.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        gateway
            .batch_remove_deployer(
                [
                    first_deployer, starknet::contract_address_const::<'NOT_DEPLOYER'>(),
                    second_deployer,
                ]
                    .span(),
            );
        stop_cheat_caller_address(gateway.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Batch max length exceeded')]
    fn test_should_panic_when_called_by_agent_when_batch_size_exceeds_max() {
        let (setup, gateway) = setup_gateway(false);

        let mut deployers = array![];
        for i in 100..601_u128 {
            deployers.append(Into::<u128, felt252>::into(i).try_into().unwrap());
        };

        start_cheat_caller_address(
            gateway.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        gateway.batch_remove_deployer(deployers.span());
        stop_cheat_caller_address(gateway.contract_address);
    }

    #[test]
    fn test_should_remove_deployers_when_called_by_agent() {
        let (setup, gateway) = setup_gateway(false);
        let first_deployer = setup.accounts.alice.account.contract_address;
        let second_deployer = setup.accounts.bob.account.contract_address;
        gateway.batch_add_deployer([first_deployer, second_deployer].span());

        let mut spy = spy_events();
        start_cheat_caller_address(
            gateway.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        gateway.batch_remove_deployer([first_deployer, second_deployer].span());
        stop_cheat_caller_address(gateway.contract_address);

        assert(!gateway.is_deployer(first_deployer), 'Deployer not removed');
        assert(!gateway.is_deployer(second_deployer), 'Deployer not removed');
        spy
            .assert_emitted(
                @array![
                    (
                        gateway.contract_address,
                        TREXGateway::Event::DeployerRemoved(
                            TREXGateway::DeployerRemoved { deployer: first_deployer },
                        ),
                    ),
                    (
                        gateway.contract_address,
                        TREXGateway::Event::DeployerRemoved(
                            TREXGateway::DeployerRemoved { deployer: second_deployer },
                        ),
                    ),
                ],
            );
    }
}

pub mod apply_fee_discount {
    use factory::{itrex_gateway::ITREXGatewayDispatcherTrait, trex_gateway::TREXGateway};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup_gateway;

    #[test]
    #[should_panic(expected: 'Only admin can call')]
    fn test_should_panic_when_called_by_not_admin() {
        let (setup, gateway) = setup_gateway(false);

        start_cheat_caller_address(
            gateway.contract_address, starknet::contract_address_const::<'NOT_ADMIN'>(),
        );
        gateway.apply_fee_discount(setup.accounts.alice.account.contract_address, 5_000);
        stop_cheat_caller_address(gateway.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Discount out of range')]
    fn test_should_panic_when_discount_out_of_range() {
        let (setup, gateway) = setup_gateway(false);

        gateway.apply_fee_discount(setup.accounts.alice.account.contract_address, 12_000);
    }

    #[test]
    fn test_should_apply_discount_when_caller_owner() {
        let (setup, gateway) = setup_gateway(false);
        let fee_collector = starknet::contract_address_const::<'FEE_COLLECTOR'>();
        let deployer = setup.accounts.bob.account.contract_address;
        gateway.set_deployment_fee(2_000, setup.token.contract_address, fee_collector);
        assert(gateway.calculate_fee(deployer) == 2_000, 'Fee does not match');

        let mut spy = spy_events();
        gateway.apply_fee_discount(deployer, 5_000);
        assert(gateway.calculate_fee(deployer) == 1_000, 'Fee does not match');
        spy
            .assert_emitted(
                @array![
                    (
                        gateway.contract_address,
                        TREXGateway::Event::FeeDiscountApplied(
                            TREXGateway::FeeDiscountApplied { deployer, discount: 5_000 },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_should_apply_discount_when_caller_agent() {
        let (setup, gateway) = setup_gateway(false);
        let fee_collector = starknet::contract_address_const::<'FEE_COLLECTOR'>();
        let deployer = setup.accounts.bob.account.contract_address;
        gateway.set_deployment_fee(2_000, setup.token.contract_address, fee_collector);
        assert(gateway.calculate_fee(deployer) == 2_000, 'Fee does not match');

        let mut spy = spy_events();

        start_cheat_caller_address(
            gateway.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        gateway.apply_fee_discount(deployer, 5_000);
        stop_cheat_caller_address(gateway.contract_address);

        assert(gateway.calculate_fee(deployer) == 1_000, 'Fee does not match');
        spy
            .assert_emitted(
                @array![
                    (
                        gateway.contract_address,
                        TREXGateway::Event::FeeDiscountApplied(
                            TREXGateway::FeeDiscountApplied { deployer, discount: 5_000 },
                        ),
                    ),
                ],
            );
    }
}

pub mod batch_apply_fee_discount {
    use factory::{itrex_gateway::ITREXGatewayDispatcherTrait, trex_gateway::TREXGateway};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup_gateway;

    #[test]
    #[should_panic(expected: 'Only admin can call')]
    fn test_should_panic_when_called_by_not_admin() {
        let (setup, gateway) = setup_gateway(false);
        let first_deployer = setup.accounts.alice.account.contract_address;
        let second_deployer = setup.accounts.bob.account.contract_address;

        start_cheat_caller_address(
            gateway.contract_address, starknet::contract_address_const::<'NOT_ADMIN'>(),
        );
        gateway
            .batch_apply_fee_discount(
                [first_deployer, second_deployer].span(), [5_000, 4_000].span(),
            );
        stop_cheat_caller_address(gateway.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Discount out of range')]
    fn test_should_panic_the_whole_batch_when_discount_out_of_range() {
        let (setup, gateway) = setup_gateway(false);
        let first_deployer = setup.accounts.alice.account.contract_address;
        let second_deployer = setup.accounts.bob.account.contract_address;

        gateway
            .batch_apply_fee_discount(
                [first_deployer, second_deployer].span(), [5_000, 12_000].span(),
            );
    }

    #[test]
    #[should_panic(expected: 'Batch max length exceeded')]
    fn test_should_panic_when_batch_size_exceeds_max() {
        let (_, gateway) = setup_gateway(false);

        let mut deployers = array![];
        let mut discounts = array![];
        for i in 100..601_u128 {
            deployers.append(Into::<u128, felt252>::into(i).try_into().unwrap());
            discounts.append(5_000);
        };

        gateway.batch_apply_fee_discount(deployers.span(), discounts.span());
    }

    #[test]
    fn test_should_apply_discount_when_caller_owner() {
        let (setup, gateway) = setup_gateway(false);
        let fee_collector = starknet::contract_address_const::<'FEE_COLLECTOR'>();
        let first_deployer = setup.accounts.alice.account.contract_address;
        let second_deployer = setup.accounts.bob.account.contract_address;

        gateway.set_deployment_fee(2_000, setup.token.contract_address, fee_collector);
        assert(gateway.calculate_fee(first_deployer) == 2_000, 'Fee does not match');
        assert(gateway.calculate_fee(second_deployer) == 2_000, 'Fee does not match');

        let mut spy = spy_events();

        gateway
            .batch_apply_fee_discount(
                [first_deployer, second_deployer].span(), [5_000, 4_000].span(),
            );

        assert(gateway.calculate_fee(first_deployer) == 1_000, 'Fee does not match');
        assert(gateway.calculate_fee(second_deployer) == 1_200, 'Fee does not match');
        spy
            .assert_emitted(
                @array![
                    (
                        gateway.contract_address,
                        TREXGateway::Event::FeeDiscountApplied(
                            TREXGateway::FeeDiscountApplied {
                                deployer: first_deployer, discount: 5_000,
                            },
                        ),
                    ),
                    (
                        gateway.contract_address,
                        TREXGateway::Event::FeeDiscountApplied(
                            TREXGateway::FeeDiscountApplied {
                                deployer: second_deployer, discount: 4_000,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_should_apply_discount_when_caller_agent() {
        let (setup, gateway) = setup_gateway(false);
        let fee_collector = starknet::contract_address_const::<'FEE_COLLECTOR'>();
        let first_deployer = setup.accounts.alice.account.contract_address;
        let second_deployer = setup.accounts.bob.account.contract_address;

        gateway.set_deployment_fee(2_000, setup.token.contract_address, fee_collector);
        assert(gateway.calculate_fee(first_deployer) == 2_000, 'Fee does not match');
        assert(gateway.calculate_fee(second_deployer) == 2_000, 'Fee does not match');

        let mut spy = spy_events();

        start_cheat_caller_address(
            gateway.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        gateway
            .batch_apply_fee_discount(
                [first_deployer, second_deployer].span(), [5_000, 4_000].span(),
            );
        stop_cheat_caller_address(gateway.contract_address);

        assert(gateway.calculate_fee(first_deployer) == 1_000, 'Fee does not match');
        assert(gateway.calculate_fee(second_deployer) == 1_200, 'Fee does not match');
        spy
            .assert_emitted(
                @array![
                    (
                        gateway.contract_address,
                        TREXGateway::Event::FeeDiscountApplied(
                            TREXGateway::FeeDiscountApplied {
                                deployer: first_deployer, discount: 5_000,
                            },
                        ),
                    ),
                    (
                        gateway.contract_address,
                        TREXGateway::Event::FeeDiscountApplied(
                            TREXGateway::FeeDiscountApplied {
                                deployer: second_deployer, discount: 4_000,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod deploy_trex_suite {
    use core::num::traits::Zero;
    use factory::{
        itrex_factory::{ClaimDetails, TokenDetails}, itrex_gateway::ITREXGatewayDispatcherTrait,
    };
    use mocks::mock_erc20::{IMintableDispatcher, IMintableDispatcherTrait};
    use openzeppelin_token::erc20::{ERC20Component, interface::IERC20DispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::{assert_deployment_events_emitted, deploy_fee_token, setup_gateway};

    #[test]
    #[should_panic(expected: 'Public deployment not allowed')]
    fn test_should_panic_when_caller_not_deployer_when_public_deployments_disabled() {
        let (_, gateway) = setup_gateway(false);
        let not_deployer = starknet::contract_address_const::<'NOT_DEPLOYER'>();

        let token_details = TokenDetails {
            owner: not_deployer,
            name: "Token Name",
            symbol: "SYM",
            decimals: 8,
            irs: Zero::zero(),
            onchain_id: Zero::zero(),
            ir_agents: [].span(),
            token_agents: [].span(),
            compliance_modules: [].span(),
            compliance_settings: [].span(),
        };

        let claim_details = ClaimDetails {
            claim_topics: [].span(), issuers: [].span(), issuer_claims: [].span(),
        };

        start_cheat_caller_address(gateway.contract_address, not_deployer);
        gateway.deploy_TREX_suite(token_details, claim_details);
        stop_cheat_caller_address(gateway.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Public cannot deploy on behalf')]
    fn test_should_panic_when_caller_not_deployer_when_public_deployments_are_enabled_when_try_to_deploy_on_behalf() {
        let (setup, gateway) = setup_gateway(true);
        let not_deployer = starknet::contract_address_const::<'NOT_DEPLOYER'>();

        let token_details = TokenDetails {
            owner: setup.accounts.bob.account.contract_address,
            name: "Token Name",
            symbol: "SYM",
            decimals: 8,
            irs: Zero::zero(),
            onchain_id: Zero::zero(),
            ir_agents: [].span(),
            token_agents: [].span(),
            compliance_modules: [].span(),
            compliance_settings: [].span(),
        };

        let claim_details = ClaimDetails {
            claim_topics: [].span(), issuers: [].span(), issuer_claims: [].span(),
        };

        start_cheat_caller_address(gateway.contract_address, not_deployer);
        gateway.deploy_TREX_suite(token_details, claim_details);
        stop_cheat_caller_address(gateway.contract_address);
    }

    #[test]
    fn test_should_deploy_a_token_for_free_when_public_deployments_are_enabled_when_deployment_fees_are_not_activated() {
        let (setup, gateway) = setup_gateway(true);
        let not_deployer = starknet::contract_address_const::<'NOT_DEPLOYER'>();

        let token_details = TokenDetails {
            owner: not_deployer,
            name: "Token Name",
            symbol: "SYM",
            decimals: 8,
            irs: Zero::zero(),
            onchain_id: Zero::zero(),
            ir_agents: [].span(),
            token_agents: [].span(),
            compliance_modules: [].span(),
            compliance_settings: [].span(),
        };

        let claim_details = ClaimDetails {
            claim_topics: [].span(), issuers: [].span(), issuer_claims: [].span(),
        };

        let mut spy = spy_events();
        start_cheat_caller_address(gateway.contract_address, not_deployer);
        gateway.deploy_TREX_suite(token_details.clone(), claim_details);
        stop_cheat_caller_address(gateway.contract_address);

        assert_deployment_events_emitted(@setup, gateway, ref spy, token_details, not_deployer, 0);
    }

    #[test]
    fn test_should_deploy_a_token_for_full_fee_when_public_deployments_are_enabled_when_deployment_fees_are_activated_when_caller_has_no_discount() {
        let (setup, gateway) = setup_gateway(true);
        let not_deployer = starknet::contract_address_const::<'NOT_DEPLOYER'>();
        let fee_collector = starknet::contract_address_const::<'FEE_TOKEN'>();
        let fee_token = deploy_fee_token();
        IMintableDispatcher { contract_address: fee_token.contract_address }
            .mint(not_deployer, 100_000);
        gateway.set_deployment_fee(20_000, fee_token.contract_address, fee_collector);
        gateway.enable_deployment_fee(true);
        start_cheat_caller_address(fee_token.contract_address, not_deployer);
        fee_token.approve(gateway.contract_address, 20_000);
        stop_cheat_caller_address(fee_token.contract_address);

        let token_details = TokenDetails {
            owner: not_deployer,
            name: "Token Name",
            symbol: "SYM",
            decimals: 8,
            irs: Zero::zero(),
            onchain_id: Zero::zero(),
            ir_agents: [].span(),
            token_agents: [].span(),
            compliance_modules: [].span(),
            compliance_settings: [].span(),
        };

        let claim_details = ClaimDetails {
            claim_topics: [].span(), issuers: [].span(), issuer_claims: [].span(),
        };

        let mut spy = spy_events();
        start_cheat_caller_address(gateway.contract_address, not_deployer);
        gateway.deploy_TREX_suite(token_details.clone(), claim_details);
        stop_cheat_caller_address(gateway.contract_address);

        assert_deployment_events_emitted(
            @setup, gateway, ref spy, token_details, not_deployer, 20_000,
        );
        /// Check token transfer
        assert(fee_token.balance_of(fee_collector) == 20_000, 'Fee not transferred');
        assert(fee_token.balance_of(not_deployer) == 80_000, 'Fee not transferred');
        spy
            .assert_emitted(
                @array![
                    (
                        fee_token.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: not_deployer, to: fee_collector, value: 20_000,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_should_deploy_a_token_for_half_fee_when_public_deployments_are_enabled_when_deployment_fees_are_activated_when_caller_has_50_percent_discount() {
        let (setup, gateway) = setup_gateway(true);
        let not_deployer = starknet::contract_address_const::<'NOT_DEPLOYER'>();
        let fee_collector = starknet::contract_address_const::<'FEE_TOKEN'>();
        let fee_token = deploy_fee_token();
        IMintableDispatcher { contract_address: fee_token.contract_address }
            .mint(not_deployer, 100_000);
        gateway.set_deployment_fee(20_000, fee_token.contract_address, fee_collector);
        gateway.enable_deployment_fee(true);
        gateway.apply_fee_discount(not_deployer, 5_000);
        start_cheat_caller_address(fee_token.contract_address, not_deployer);
        fee_token.approve(gateway.contract_address, 20_000);
        stop_cheat_caller_address(fee_token.contract_address);

        let token_details = TokenDetails {
            owner: not_deployer,
            name: "Token Name",
            symbol: "SYM",
            decimals: 8,
            irs: Zero::zero(),
            onchain_id: Zero::zero(),
            ir_agents: [].span(),
            token_agents: [].span(),
            compliance_modules: [].span(),
            compliance_settings: [].span(),
        };

        let claim_details = ClaimDetails {
            claim_topics: [].span(), issuers: [].span(), issuer_claims: [].span(),
        };

        let mut spy = spy_events();
        start_cheat_caller_address(gateway.contract_address, not_deployer);
        gateway.deploy_TREX_suite(token_details.clone(), claim_details);
        stop_cheat_caller_address(gateway.contract_address);

        assert_deployment_events_emitted(
            @setup, gateway, ref spy, token_details, not_deployer, 10_000,
        );

        /// Check token transfer
        assert(fee_token.balance_of(fee_collector) == 10_000, 'Fee not transferred');
        assert(fee_token.balance_of(not_deployer) == 90_000, 'Fee not transferred');
        spy
            .assert_emitted(
                @array![
                    (
                        fee_token.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: not_deployer, to: fee_collector, value: 10_000,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_should_deploy_when_called_by_deployer_when_public_deployments_disabled() {
        let (setup, gateway) = setup_gateway(false);
        let another_deployer = starknet::contract_address_const::<'ANOTHER_DEPLOYER'>();
        gateway.add_deployer(another_deployer);

        let token_details = TokenDetails {
            owner: another_deployer,
            name: "Token Name",
            symbol: "SYM",
            decimals: 8,
            irs: Zero::zero(),
            onchain_id: Zero::zero(),
            ir_agents: [].span(),
            token_agents: [].span(),
            compliance_modules: [].span(),
            compliance_settings: [].span(),
        };

        let claim_details = ClaimDetails {
            claim_topics: [].span(), issuers: [].span(), issuer_claims: [].span(),
        };

        let mut spy = spy_events();
        start_cheat_caller_address(gateway.contract_address, another_deployer);
        gateway.deploy_TREX_suite(token_details.clone(), claim_details);
        stop_cheat_caller_address(gateway.contract_address);

        assert_deployment_events_emitted(
            @setup, gateway, ref spy, token_details, another_deployer, 0,
        );
    }

    #[test]
    fn test_should_deploy_when_called_by_deployer_when_try_to_deploy_on_behalf() {
        let (setup, gateway) = setup_gateway(false);
        let another_deployer = starknet::contract_address_const::<'ANOTHER_DEPLOYER'>();
        gateway.add_deployer(another_deployer);

        let token_owner = setup.accounts.bob.account.contract_address;
        let token_details = TokenDetails {
            owner: token_owner,
            name: "Token Name",
            symbol: "SYM",
            decimals: 8,
            irs: Zero::zero(),
            onchain_id: Zero::zero(),
            ir_agents: [].span(),
            token_agents: [].span(),
            compliance_modules: [].span(),
            compliance_settings: [].span(),
        };

        let claim_details = ClaimDetails {
            claim_topics: [].span(), issuers: [].span(), issuer_claims: [].span(),
        };

        let mut spy = spy_events();
        start_cheat_caller_address(gateway.contract_address, another_deployer);
        gateway.deploy_TREX_suite(token_details.clone(), claim_details);
        stop_cheat_caller_address(gateway.contract_address);

        assert_deployment_events_emitted(
            @setup, gateway, ref spy, token_details, another_deployer, 0,
        );
    }

    #[test]
    fn test_should_deploy_a_token_for_full_fee_when_called_by_deployer_when_deployment_fees_are_activated_when_caller_has_no_discount() {
        let (setup, gateway) = setup_gateway(false);
        let another_deployer = starknet::contract_address_const::<'ANOTHER_DEPLOYER'>();
        gateway.add_deployer(another_deployer);
        let fee_collector = starknet::contract_address_const::<'FEE_TOKEN'>();
        let fee_token = deploy_fee_token();
        IMintableDispatcher { contract_address: fee_token.contract_address }
            .mint(another_deployer, 100_000);
        gateway.set_deployment_fee(20_000, fee_token.contract_address, fee_collector);
        gateway.enable_deployment_fee(true);
        start_cheat_caller_address(fee_token.contract_address, another_deployer);
        fee_token.approve(gateway.contract_address, 20_000);
        stop_cheat_caller_address(fee_token.contract_address);

        let token_details = TokenDetails {
            owner: another_deployer,
            name: "Token Name",
            symbol: "SYM",
            decimals: 8,
            irs: Zero::zero(),
            onchain_id: Zero::zero(),
            ir_agents: [].span(),
            token_agents: [].span(),
            compliance_modules: [].span(),
            compliance_settings: [].span(),
        };

        let claim_details = ClaimDetails {
            claim_topics: [].span(), issuers: [].span(), issuer_claims: [].span(),
        };

        let mut spy = spy_events();
        start_cheat_caller_address(gateway.contract_address, another_deployer);
        gateway.deploy_TREX_suite(token_details.clone(), claim_details);
        stop_cheat_caller_address(gateway.contract_address);

        assert_deployment_events_emitted(
            @setup, gateway, ref spy, token_details, another_deployer, 20_000,
        );

        /// Check token transfer
        assert(fee_token.balance_of(fee_collector) == 20_000, 'Fee not transferred');
        assert(fee_token.balance_of(another_deployer) == 80_000, 'Fee not transferred');
        spy
            .assert_emitted(
                @array![
                    (
                        fee_token.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: another_deployer, to: fee_collector, value: 20_000,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_should_deploy_a_token_for_half_fee_when_called_by_deployer_when_deployment_fees_are_activated_when_caller_has_50_percent_discount() {
        let (setup, gateway) = setup_gateway(false);
        let another_deployer = starknet::contract_address_const::<'ANOTHER_DEPLOYER'>();
        gateway.add_deployer(another_deployer);
        let fee_collector = starknet::contract_address_const::<'FEE_TOKEN'>();
        let fee_token = deploy_fee_token();
        IMintableDispatcher { contract_address: fee_token.contract_address }
            .mint(another_deployer, 100_000);
        gateway.set_deployment_fee(20_000, fee_token.contract_address, fee_collector);
        gateway.enable_deployment_fee(true);
        gateway.apply_fee_discount(another_deployer, 5_000);
        start_cheat_caller_address(fee_token.contract_address, another_deployer);
        fee_token.approve(gateway.contract_address, 20_000);
        stop_cheat_caller_address(fee_token.contract_address);

        let token_details = TokenDetails {
            owner: another_deployer,
            name: "Token Name",
            symbol: "SYM",
            decimals: 8,
            irs: Zero::zero(),
            onchain_id: Zero::zero(),
            ir_agents: [].span(),
            token_agents: [].span(),
            compliance_modules: [].span(),
            compliance_settings: [].span(),
        };

        let claim_details = ClaimDetails {
            claim_topics: [].span(), issuers: [].span(), issuer_claims: [].span(),
        };

        let mut spy = spy_events();
        start_cheat_caller_address(gateway.contract_address, another_deployer);
        gateway.deploy_TREX_suite(token_details.clone(), claim_details);
        stop_cheat_caller_address(gateway.contract_address);

        assert_deployment_events_emitted(
            @setup, gateway, ref spy, token_details, another_deployer, 10_000,
        );

        /// Check token transfer
        assert(fee_token.balance_of(fee_collector) == 10_000, 'Fee not transferred');
        assert(fee_token.balance_of(another_deployer) == 90_000, 'Fee not transferred');
        spy
            .assert_emitted(
                @array![
                    (
                        fee_token.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: another_deployer, to: fee_collector, value: 10_000,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_should_deploy_a_token_for_free_when_called_by_deployer_when_deployment_fees_are_activated_when_caller_has_100_percent_discount() {
        let (setup, gateway) = setup_gateway(false);
        let another_deployer = starknet::contract_address_const::<'ANOTHER_DEPLOYER'>();
        gateway.add_deployer(another_deployer);
        let fee_collector = starknet::contract_address_const::<'FEE_TOKEN'>();
        let fee_token = deploy_fee_token();
        IMintableDispatcher { contract_address: fee_token.contract_address }
            .mint(another_deployer, 100_000);
        gateway.set_deployment_fee(20_000, fee_token.contract_address, fee_collector);
        gateway.enable_deployment_fee(true);
        gateway.apply_fee_discount(another_deployer, 10_000);
        start_cheat_caller_address(fee_token.contract_address, another_deployer);
        fee_token.approve(gateway.contract_address, 20_000);
        stop_cheat_caller_address(fee_token.contract_address);

        let token_details = TokenDetails {
            owner: another_deployer,
            name: "Token Name",
            symbol: "SYM",
            decimals: 8,
            irs: Zero::zero(),
            onchain_id: Zero::zero(),
            ir_agents: [].span(),
            token_agents: [].span(),
            compliance_modules: [].span(),
            compliance_settings: [].span(),
        };

        let claim_details = ClaimDetails {
            claim_topics: [].span(), issuers: [].span(), issuer_claims: [].span(),
        };

        let mut spy = spy_events();
        start_cheat_caller_address(gateway.contract_address, another_deployer);
        gateway.deploy_TREX_suite(token_details.clone(), claim_details);
        stop_cheat_caller_address(gateway.contract_address);

        assert_deployment_events_emitted(
            @setup, gateway, ref spy, token_details, another_deployer, 0,
        );

        /// Check token transfer
        assert(fee_token.balance_of(fee_collector) == 0, 'Balance mismatch');
        assert(fee_token.balance_of(another_deployer) == 100_000, 'Fee not transferred');
        spy
            .assert_not_emitted(
                @array![
                    (
                        fee_token.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: another_deployer, to: fee_collector, value: 0,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod batch_deploy_trex_suite {
    use core::num::traits::Zero;
    use factory::{
        itrex_factory::{ClaimDetails, TokenDetails}, itrex_gateway::ITREXGatewayDispatcherTrait,
    };
    use mocks::mock_erc20::{IMintableDispatcher, IMintableDispatcherTrait};
    use openzeppelin_token::erc20::{ERC20Component, interface::IERC20DispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::{assert_deployment_events_emitted, deploy_fee_token, setup_gateway};

    #[test]
    #[should_panic(expected: 'Public deployment not allowed')]
    fn test_should_panic_for_batch_deployment_when_called_by_not_deployer_when_public_deployments_disabled() {
        let (_, gateway) = setup_gateway(false);
        let not_deployer = starknet::contract_address_const::<'NOT_DEPLOYER'>();

        let mut token_details_array = array![];
        let mut claim_details_array = array![];

        for i in 0..5_u8 {
            let token_details = TokenDetails {
                owner: not_deployer,
                name: format!("Token Name {i}"),
                symbol: format!("SYM{i}"),
                decimals: 8,
                irs: Zero::zero(),
                onchain_id: Zero::zero(),
                ir_agents: [].span(),
                token_agents: [].span(),
                compliance_modules: [].span(),
                compliance_settings: [].span(),
            };

            let claim_details = ClaimDetails {
                claim_topics: [].span(), issuers: [].span(), issuer_claims: [].span(),
            };
            token_details_array.append(token_details);
            claim_details_array.append(claim_details);
        };

        start_cheat_caller_address(gateway.contract_address, not_deployer);
        gateway.batch_deploy_TREX_suite(token_details_array.span(), claim_details_array.span());
        stop_cheat_caller_address(gateway.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Public cannot deploy on behalf')]
    fn test_should_panic_the_whole_batch_when_called_by_not_deployer_when_public_deployments_are_enabled_when_try_to_deploy_on_behalf_in_a_batch() {
        let (setup, gateway) = setup_gateway(true);
        let not_deployer = starknet::contract_address_const::<'NOT_DEPLOYER'>();

        let mut token_details_array = array![];
        let mut claim_details_array = array![];

        for i in 0..4_u8 {
            let token_details = TokenDetails {
                owner: not_deployer,
                name: format!("Token Name {i}"),
                symbol: format!("SYM{i}"),
                decimals: 8,
                irs: Zero::zero(),
                onchain_id: Zero::zero(),
                ir_agents: [].span(),
                token_agents: [].span(),
                compliance_modules: [].span(),
                compliance_settings: [].span(),
            };

            let claim_details = ClaimDetails {
                claim_topics: [].span(), issuers: [].span(), issuer_claims: [].span(),
            };
            token_details_array.append(token_details);
            claim_details_array.append(claim_details);
        };

        token_details_array
            .append(
                TokenDetails {
                    owner: setup.accounts.bob.account.contract_address,
                    name: "Token Name Behalf",
                    symbol: "SYM42",
                    decimals: 8,
                    irs: Zero::zero(),
                    onchain_id: Zero::zero(),
                    ir_agents: [].span(),
                    token_agents: [].span(),
                    compliance_modules: [].span(),
                    compliance_settings: [].span(),
                },
            );

        claim_details_array
            .append(
                ClaimDetails {
                    claim_topics: [].span(), issuers: [].span(), issuer_claims: [].span(),
                },
            );

        start_cheat_caller_address(gateway.contract_address, not_deployer);
        gateway.batch_deploy_TREX_suite(token_details_array.span(), claim_details_array.span());
        stop_cheat_caller_address(gateway.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Batch max length exceeded')]
    fn test_should_panic_the_batch_when_called_by_not_deployer_when_public_deployments_are_enabled_when_try_to_deploy_a_batch_of_more_than_5_tokens() {
        let (_, gateway) = setup_gateway(true);
        let not_deployer = starknet::contract_address_const::<'NOT_DEPLOYER'>();

        let mut token_details_array = array![];
        let mut claim_details_array = array![];

        for i in 0..6_u8 {
            let token_details = TokenDetails {
                owner: not_deployer,
                name: format!("Token Name {i}"),
                symbol: format!("SYM{i}"),
                decimals: 8,
                irs: Zero::zero(),
                onchain_id: Zero::zero(),
                ir_agents: [].span(),
                token_agents: [].span(),
                compliance_modules: [].span(),
                compliance_settings: [].span(),
            };

            let claim_details = ClaimDetails {
                claim_topics: [].span(), issuers: [].span(), issuer_claims: [].span(),
            };
            token_details_array.append(token_details);
            claim_details_array.append(claim_details);
        };

        start_cheat_caller_address(gateway.contract_address, not_deployer);
        gateway.batch_deploy_TREX_suite(token_details_array.span(), claim_details_array.span());
        stop_cheat_caller_address(gateway.contract_address);
    }

    #[test]
    fn test_should_deploy_tokens_for_free_in_a_batch_when_called_by_not_deployer_when_deployment_fees_are_not_activated() {
        let (setup, gateway) = setup_gateway(true);
        let not_deployer = starknet::contract_address_const::<'NOT_DEPLOYER'>();

        let mut token_details_array = array![];
        let mut claim_details_array = array![];

        for i in 0..5_u8 {
            let token_details = TokenDetails {
                owner: not_deployer,
                name: format!("Token Name {i}"),
                symbol: format!("SYM{i}"),
                decimals: 8,
                irs: Zero::zero(),
                onchain_id: Zero::zero(),
                ir_agents: [].span(),
                token_agents: [].span(),
                compliance_modules: [].span(),
                compliance_settings: [].span(),
            };

            let claim_details = ClaimDetails {
                claim_topics: [].span(), issuers: [].span(), issuer_claims: [].span(),
            };
            token_details_array.append(token_details);
            claim_details_array.append(claim_details);
        };

        let mut spy = spy_events();
        start_cheat_caller_address(gateway.contract_address, not_deployer);
        gateway.batch_deploy_TREX_suite(token_details_array.span(), claim_details_array.span());
        stop_cheat_caller_address(gateway.contract_address);

        for i in 0..token_details_array.len() {
            assert_deployment_events_emitted(
                @setup, gateway, ref spy, token_details_array.at(i).clone(), not_deployer, 0,
            );
        };
    }

    #[test]
    fn test_should_deploy_tokens_for_full_fee_in_a_batch_when_called_by_not_deployer_when_deployment_fees_are_activated_when_caller_has_no_discount() {
        let (setup, gateway) = setup_gateway(true);
        let not_deployer = starknet::contract_address_const::<'NOT_DEPLOYER'>();
        let fee_collector = starknet::contract_address_const::<'FEE_TOKEN'>();
        let fee_token = deploy_fee_token();
        IMintableDispatcher { contract_address: fee_token.contract_address }
            .mint(not_deployer, 100_000);
        gateway.set_deployment_fee(20_000, fee_token.contract_address, fee_collector);
        gateway.enable_deployment_fee(true);
        start_cheat_caller_address(fee_token.contract_address, not_deployer);
        fee_token.approve(gateway.contract_address, 100_000);
        stop_cheat_caller_address(fee_token.contract_address);

        let mut token_details_array = array![];
        let mut claim_details_array = array![];

        for i in 0..5_u8 {
            let token_details = TokenDetails {
                owner: not_deployer,
                name: format!("Token Name {i}"),
                symbol: format!("SYM{i}"),
                decimals: 8,
                irs: Zero::zero(),
                onchain_id: Zero::zero(),
                ir_agents: [].span(),
                token_agents: [].span(),
                compliance_modules: [].span(),
                compliance_settings: [].span(),
            };

            let claim_details = ClaimDetails {
                claim_topics: [].span(), issuers: [].span(), issuer_claims: [].span(),
            };
            token_details_array.append(token_details);
            claim_details_array.append(claim_details);
        };

        let mut spy = spy_events();
        start_cheat_caller_address(gateway.contract_address, not_deployer);
        gateway.batch_deploy_TREX_suite(token_details_array.span(), claim_details_array.span());
        stop_cheat_caller_address(gateway.contract_address);

        for i in 0..token_details_array.len() {
            assert_deployment_events_emitted(
                @setup, gateway, ref spy, token_details_array.at(i).clone(), not_deployer, 20_000,
            );
        };

        /// Check token transfer
        assert(fee_token.balance_of(fee_collector) == 100_000, 'Balance mismatch');
        assert(fee_token.balance_of(not_deployer) == 0, 'Balance mismatch');
        spy
            .assert_emitted(
                @array![
                    (
                        fee_token.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: not_deployer, to: fee_collector, value: 100_000,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_should_deploy_tokens_for_half_fee_in_a_batch_when_called_by_not_deployer_when_deployment_fees_are_activated_when_caller_has_50_percent_discount() {
        let (setup, gateway) = setup_gateway(true);
        let not_deployer = starknet::contract_address_const::<'NOT_DEPLOYER'>();
        let fee_collector = starknet::contract_address_const::<'FEE_TOKEN'>();
        let fee_token = deploy_fee_token();
        IMintableDispatcher { contract_address: fee_token.contract_address }
            .mint(not_deployer, 100_000);
        gateway.set_deployment_fee(20_000, fee_token.contract_address, fee_collector);
        gateway.enable_deployment_fee(true);
        gateway.apply_fee_discount(not_deployer, 5_000);
        start_cheat_caller_address(fee_token.contract_address, not_deployer);
        fee_token.approve(gateway.contract_address, 100_000);
        stop_cheat_caller_address(fee_token.contract_address);

        let mut token_details_array = array![];
        let mut claim_details_array = array![];

        for i in 0..5_u8 {
            let token_details = TokenDetails {
                owner: not_deployer,
                name: format!("Token Name {i}"),
                symbol: format!("SYM{i}"),
                decimals: 8,
                irs: Zero::zero(),
                onchain_id: Zero::zero(),
                ir_agents: [].span(),
                token_agents: [].span(),
                compliance_modules: [].span(),
                compliance_settings: [].span(),
            };

            let claim_details = ClaimDetails {
                claim_topics: [].span(), issuers: [].span(), issuer_claims: [].span(),
            };
            token_details_array.append(token_details);
            claim_details_array.append(claim_details);
        };

        let mut spy = spy_events();
        start_cheat_caller_address(gateway.contract_address, not_deployer);
        gateway.batch_deploy_TREX_suite(token_details_array.span(), claim_details_array.span());
        stop_cheat_caller_address(gateway.contract_address);

        for i in 0..token_details_array.len() {
            assert_deployment_events_emitted(
                @setup, gateway, ref spy, token_details_array.at(i).clone(), not_deployer, 10_000,
            );
        };

        /// Check token transfer
        assert(fee_token.balance_of(fee_collector) == 50_000, 'Balance mismatch');
        assert(fee_token.balance_of(not_deployer) == 50_000, 'Balance mismatch');
        spy
            .assert_emitted(
                @array![
                    (
                        fee_token.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: not_deployer, to: fee_collector, value: 50_000,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_should_deploy_in_batch_when_called_by_deployer_when_public_deployments_disabled_when_fees_are_not_activated() {
        let (setup, gateway) = setup_gateway(false);
        let another_deployer = starknet::contract_address_const::<'ANOTHER_DEPLOYER'>();
        gateway.add_deployer(another_deployer);

        let mut token_details_array = array![];
        let mut claim_details_array = array![];

        for i in 0..5_u8 {
            let token_details = TokenDetails {
                owner: another_deployer,
                name: format!("Token Name {i}"),
                symbol: format!("SYM{i}"),
                decimals: 8,
                irs: Zero::zero(),
                onchain_id: Zero::zero(),
                ir_agents: [].span(),
                token_agents: [].span(),
                compliance_modules: [].span(),
                compliance_settings: [].span(),
            };

            let claim_details = ClaimDetails {
                claim_topics: [].span(), issuers: [].span(), issuer_claims: [].span(),
            };
            token_details_array.append(token_details);
            claim_details_array.append(claim_details);
        };

        let mut spy = spy_events();
        start_cheat_caller_address(gateway.contract_address, another_deployer);
        gateway.batch_deploy_TREX_suite(token_details_array.span(), claim_details_array.span());
        stop_cheat_caller_address(gateway.contract_address);

        for i in 0..token_details_array.len() {
            assert_deployment_events_emitted(
                @setup, gateway, ref spy, token_details_array.at(i).clone(), another_deployer, 0,
            );
        };
    }

    #[test]
    fn test_should_deploy_in_batch_when_called_by_deployer_when_trying_to_deploy_on_behalf_when_fees_are_not_activated() {
        let (setup, gateway) = setup_gateway(false);
        let another_deployer = starknet::contract_address_const::<'ANOTHER_DEPLOYER'>();
        gateway.add_deployer(another_deployer);

        let mut token_details_array = array![];
        let mut claim_details_array = array![];

        let token_owner = setup.accounts.bob.account.contract_address;
        for i in 0..5_u8 {
            let token_details = TokenDetails {
                owner: token_owner,
                name: format!("Token Name {i}"),
                symbol: format!("SYM{i}"),
                decimals: 8,
                irs: Zero::zero(),
                onchain_id: Zero::zero(),
                ir_agents: [].span(),
                token_agents: [].span(),
                compliance_modules: [].span(),
                compliance_settings: [].span(),
            };

            let claim_details = ClaimDetails {
                claim_topics: [].span(), issuers: [].span(), issuer_claims: [].span(),
            };
            token_details_array.append(token_details);
            claim_details_array.append(claim_details);
        };

        let mut spy = spy_events();
        start_cheat_caller_address(gateway.contract_address, another_deployer);
        gateway.batch_deploy_TREX_suite(token_details_array.span(), claim_details_array.span());
        stop_cheat_caller_address(gateway.contract_address);

        for i in 0..token_details_array.len() {
            assert_deployment_events_emitted(
                @setup, gateway, ref spy, token_details_array.at(i).clone(), another_deployer, 0,
            );
        };
    }
}
