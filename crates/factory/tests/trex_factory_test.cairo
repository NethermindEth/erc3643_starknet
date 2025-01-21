pub mod deploy_trex_suite {
    use core::num::traits::Zero;
    use factory::{
        itrex_factory::{ClaimDetails, ComplianceSetting, ITREXFactoryDispatcherTrait, TokenDetails},
        tests_common::setup_full_suite, trex_factory::TREXFactory,
    };
    use onchain_id_starknet::factory::id_factory::IdFactory;
    use registry::interface::iidentity_registry::IIdentityRegistryDispatcherTrait;
    use snforge_std::{
        ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
        start_cheat_caller_address, stop_cheat_caller_address,
    };
    use token::itoken::{ITokenDispatcher, ITokenDispatcherTrait};

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_called_by_not_owner() {
        let setup = setup_full_suite();

        let token_details = TokenDetails {
            owner: starknet::get_contract_address(),
            name: "Token Name",
            symbol: "SYM",
            decimals: 0,
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

        start_cheat_caller_address(
            setup.trex_factory.contract_address, starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        setup.trex_factory.deploy_TREX_suite('salt', token_details, claim_details);
        stop_cheat_caller_address(setup.trex_factory.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Token already deployed')]
    fn test_should_panic_when_salt_was_already_used() {
        let setup = setup_full_suite();

        let token_details = TokenDetails {
            owner: starknet::get_contract_address(),
            name: "TREXDINO",
            symbol: "TREX",
            decimals: 0,
            irs: Zero::zero(),
            onchain_id: Zero::zero(),
            ir_agents: [setup.accounts.token_agent.account.contract_address].span(),
            token_agents: [setup.accounts.token_agent.account.contract_address].span(),
            compliance_modules: [].span(),
            compliance_settings: [].span(),
        };

        let claim_details = ClaimDetails {
            claim_topics: ['CLAIM_TOPIC'].span(),
            issuers: [setup.onchain_id.claim_issuer.contract_address].span(),
            issuer_claims: [['CLAIM_TOPIC'].span()].span(),
        };

        setup.trex_factory.deploy_TREX_suite('MY_SALT', token_details, claim_details);
    }

    #[test]
    #[should_panic(expected: 'Invalid claim pattern')]
    fn test_should_panic_when_claim_pattern_is_not_valid() {
        let setup = setup_full_suite();

        let token_details = TokenDetails {
            owner: starknet::get_contract_address(),
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
            claim_topics: ['CLAIM_TOPIC'].span(),
            issuers: [Zero::zero()].span(),
            issuer_claims: [].span(),
        };

        setup.trex_factory.deploy_TREX_suite('salt', token_details, claim_details);
    }

    #[test]
    #[should_panic(expected: 'Max 5 issuers at deployment')]
    fn test_should_panic_when_configuring_more_than_5_claim_issuers() {
        let setup = setup_full_suite();

        let token_details = TokenDetails {
            owner: starknet::get_contract_address(),
            name: "Token Name",
            symbol: "SYM",
            decimals: 8,
            irs: Zero::zero(),
            onchain_id: Zero::zero(),
            ir_agents: [setup.accounts.token_agent.account.contract_address].span(),
            token_agents: [setup.accounts.token_agent.account.contract_address].span(),
            compliance_modules: [].span(),
            compliance_settings: [].span(),
        };

        let claim_details = ClaimDetails {
            claim_topics: [].span(),
            issuers: [
                Zero::zero(), Zero::zero(), Zero::zero(), Zero::zero(), Zero::zero(), Zero::zero(),
            ]
                .span(),
            issuer_claims: [
                ['1'].span(), ['2'].span(), ['3'].span(), ['4'].span(), ['5'].span(), ['6'].span(),
            ]
                .span(),
        };

        setup.trex_factory.deploy_TREX_suite('salt', token_details, claim_details);
    }

    #[test]
    #[should_panic(expected: 'Max 5 topics at deployment')]
    fn test_should_panic_when_configuring_more_than_5_claim_topics() {
        let setup = setup_full_suite();

        let token_details = TokenDetails {
            owner: starknet::get_contract_address(),
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
            claim_topics: ['1', '2', '3', '4', '5', '6'].span(),
            issuers: [].span(),
            issuer_claims: [].span(),
        };

        setup.trex_factory.deploy_TREX_suite('salt', token_details, claim_details);
    }

    #[test]
    #[should_panic(expected: 'Max 5 agents at deployment')]
    fn test_should_panic_when_configuring_more_than_5_agents() {
        let setup = setup_full_suite();

        let token_details = TokenDetails {
            owner: starknet::get_contract_address(),
            name: "Token Name",
            symbol: "SYM",
            decimals: 8,
            irs: Zero::zero(),
            onchain_id: Zero::zero(),
            ir_agents: [
                Zero::zero(), Zero::zero(), Zero::zero(), Zero::zero(), Zero::zero(), Zero::zero(),
            ]
                .span(),
            token_agents: [].span(),
            compliance_modules: [].span(),
            compliance_settings: [].span(),
        };

        let claim_details = ClaimDetails {
            claim_topics: [].span(), issuers: [].span(), issuer_claims: [].span(),
        };

        setup.trex_factory.deploy_TREX_suite('salt', token_details, claim_details);
    }

    #[test]
    #[should_panic(expected: 'Max 30 compliance at deployment')]
    fn test_should_panic_when_configuring_more_than_30_compliance_modules() {
        let setup = setup_full_suite();

        let mut compliance_modules: Array<starknet::ContractAddress> = array![];
        for _ in 0..31_u8 {
            compliance_modules.append(Zero::zero());
        };

        let token_details = TokenDetails {
            owner: starknet::get_contract_address(),
            name: "Token Name",
            symbol: "SYM",
            decimals: 8,
            irs: Zero::zero(),
            onchain_id: Zero::zero(),
            ir_agents: [].span(),
            token_agents: [].span(),
            compliance_modules: compliance_modules.span(),
            compliance_settings: [].span(),
        };

        let claim_details = ClaimDetails {
            claim_topics: [].span(), issuers: [].span(), issuer_claims: [].span(),
        };

        setup.trex_factory.deploy_TREX_suite('salt', token_details, claim_details);
    }

    #[test]
    #[should_panic(expected: 'Invalid compliance pattern')]
    fn test_should_panic_when_compliance_configuration_is_not_valid() {
        let setup = setup_full_suite();

        let token_details = TokenDetails {
            owner: starknet::get_contract_address(),
            name: "Token Name",
            symbol: "SYM",
            decimals: 8,
            irs: Zero::zero(),
            onchain_id: Zero::zero(),
            ir_agents: [].span(),
            token_agents: [].span(),
            compliance_modules: [].span(),
            compliance_settings: [
                ComplianceSetting { selector: 'selector', calldata: ['0x000'].span() }
            ]
                .span(),
        };

        let claim_details = ClaimDetails {
            claim_topics: [].span(), issuers: [].span(), issuer_claims: [].span(),
        };

        setup.trex_factory.deploy_TREX_suite('salt', token_details, claim_details);
    }

    #[test]
    fn test_should_deploy_a_new_suite_when_configuration_is_valid() {
        let setup = setup_full_suite();

        let compliance_module_contract = declare("CountryAllowModule").unwrap().contract_class();
        let (compliance_module_address, _) = compliance_module_contract
            .deploy(@array![starknet::get_contract_address().into()])
            .unwrap();
        let compliance_setting_calldata = array![42_u16, 66_u16];
        let mut serialized_calldata: Array<felt252> = array![];
        compliance_setting_calldata.serialize(ref serialized_calldata);
        let token_details = TokenDetails {
            owner: starknet::get_contract_address(),
            name: "Token Name",
            symbol: "SYM",
            decimals: 8,
            irs: Zero::zero(),
            onchain_id: Zero::zero(),
            ir_agents: [setup.accounts.alice.account.contract_address].span(),
            token_agents: [setup.accounts.bob.account.contract_address].span(),
            compliance_modules: [compliance_module_address].span(),
            compliance_settings: [
                ComplianceSetting {
                    selector: selector!("batch_allow_countries"),
                    calldata: serialized_calldata.span(),
                }
            ]
                .span(),
        };

        let claim_details = ClaimDetails {
            claim_topics: ['DEMO_TOPIC'].span(),
            issuers: [setup.onchain_id.claim_issuer.contract_address].span(),
            issuer_claims: [['DEMO_TOPIC'].span()].span(),
        };

        let mut spy = spy_events();
        setup.trex_factory.deploy_TREX_suite('salt', token_details, claim_details);

        let token_address = setup.trex_factory.get_token('salt');
        let token = ITokenDispatcher { contract_address: token_address };
        let identity_registry = token.identity_registry();
        let compliance = token.compliance();
        let token_identity_adddress = token.onchain_id();
        let identity_registry_storage = identity_registry.identity_storage();
        let trusted_issuers_registry = identity_registry.issuers_registry();
        let claim_topics_registry = identity_registry.topics_registry();

        spy
            .assert_emitted(
                @array![
                    (
                        setup.trex_factory.contract_address,
                        TREXFactory::Event::TREXSuiteDeployed(
                            TREXFactory::TREXSuiteDeployed {
                                token: token_address,
                                ir: identity_registry.contract_address,
                                irs: identity_registry_storage.contract_address,
                                tir: trusted_issuers_registry.contract_address,
                                ctr: claim_topics_registry.contract_address,
                                mc: compliance.contract_address,
                                salt: 'salt',
                            },
                        ),
                    ),
                ],
            );

        spy
            .assert_emitted(
                @array![
                    (
                        setup.onchain_id.identity_factory.contract_address,
                        IdFactory::Event::Deployed(
                            IdFactory::Deployed { deployed_address: token_identity_adddress },
                        ),
                    ),
                    (
                        setup.onchain_id.identity_factory.contract_address,
                        IdFactory::Event::TokenLinked(
                            IdFactory::TokenLinked {
                                token: token_address, identity: token_identity_adddress,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod set_id_factory {
    use core::num::traits::Zero;
    use factory::{
        itrex_factory::ITREXFactoryDispatcherTrait, tests_common::setup_full_suite,
        trex_factory::TREXFactory,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_caller_is_not_the_owner() {
        let setup = setup_full_suite();

        start_cheat_caller_address(
            setup.trex_factory.contract_address, starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        setup.trex_factory.set_id_factory(starknet::contract_address_const::<'ID_FACTORY'>());
        stop_cheat_caller_address(setup.trex_factory.contract_address);
    }

    #[test]
    #[should_panic(expected: 'id_factory: Zero Address')]
    fn test_should_panic_when_try_to_input_address_zero() {
        let setup = setup_full_suite();

        setup.trex_factory.set_id_factory(Zero::zero());
    }

    #[test]
    fn test_should_set_new_id_factory_when_input_a_valid_address() {
        let setup = setup_full_suite();
        let new_id_factory = starknet::contract_address_const::<'ID_FACTORY'>();
        let mut spy = spy_events();
        setup.trex_factory.set_id_factory(new_id_factory);

        assert(setup.trex_factory.get_id_factory() == new_id_factory, 'Id factory not set');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.trex_factory.contract_address,
                        TREXFactory::Event::IdFactorySet(
                            TREXFactory::IdFactorySet { id_factory: new_id_factory },
                        ),
                    ),
                ],
            );
    }
}

pub mod set_implementation_authority {
    use core::num::traits::Zero;
    use factory::{
        itrex_factory::ITREXFactoryDispatcherTrait, tests_common::setup_full_suite,
        trex_factory::TREXFactory,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_caller_is_not_the_owner() {
        let setup = setup_full_suite();

        start_cheat_caller_address(
            setup.trex_factory.contract_address, starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        setup
            .trex_factory
            .set_implementation_authority(
                starknet::contract_address_const::<'IMPLEMENTATION_AUTHORITY'>(),
            );
        stop_cheat_caller_address(setup.trex_factory.contract_address);
    }

    #[test]
    #[should_panic(expected: 'IA: Zero Address')]
    fn test_should_panic_when_try_to_input_address_zero() {
        let setup = setup_full_suite();

        setup.trex_factory.set_implementation_authority(Zero::zero());
    }

    #[test]
    fn test_should_set_implementation_authority_when_input_a_valid_address() {
        let setup = setup_full_suite();
        let new_impl_auth = starknet::contract_address_const::<'IMPLEMENTATION_AUTHORITY'>();
        let mut spy = spy_events();
        setup.trex_factory.set_implementation_authority(new_impl_auth);

        assert(
            setup.trex_factory.get_implementation_authority() == new_impl_auth, 'Impl auth not set',
        );
        spy
            .assert_emitted(
                @array![
                    (
                        setup.trex_factory.contract_address,
                        TREXFactory::Event::ImplementationAuthoritySet(
                            TREXFactory::ImplementationAuthoritySet {
                                implementation_authority: new_impl_auth,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod recover_contract_ownership {
    use core::num::traits::Zero;
    use factory::{
        itrex_factory::{ClaimDetails, ITREXFactoryDispatcherTrait, TokenDetails},
        tests_common::setup_full_suite,
    };
    use openzeppelin_access::ownable::{
        OwnableComponent, interface::{IOwnableDispatcher, IOwnableDispatcherTrait},
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_sender_is_not_owner() {
        let setup = setup_full_suite();

        start_cheat_caller_address(
            setup.trex_factory.contract_address, starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        setup
            .trex_factory
            .recover_contract_ownership(
                setup.token.contract_address, setup.accounts.alice.account.contract_address,
            );
        stop_cheat_caller_address(setup.trex_factory.contract_address);
    }

    #[test]
    fn test_should_transfer_ownership_on_desired_contract_when_sender_is_owner_and_factory_owns_trex_contract() {
        let setup = setup_full_suite();

        let token_details = TokenDetails {
            owner: setup.trex_factory.contract_address,
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

        setup.trex_factory.deploy_TREX_suite('salt', token_details, claim_details);

        let token_address = setup.trex_factory.get_token('salt');
        let alice_address = setup.accounts.alice.account.contract_address;

        let mut spy = spy_events();
        setup.trex_factory.recover_contract_ownership(token_address, alice_address);

        assert(
            IOwnableDispatcher { contract_address: token_address }.owner() == alice_address,
            'Ownership didnt transferred',
        );
        spy
            .assert_emitted(
                @array![
                    (
                        token_address,
                        OwnableComponent::Event::OwnershipTransferred(
                            OwnableComponent::OwnershipTransferred {
                                previous_owner: setup.trex_factory.contract_address,
                                new_owner: alice_address,
                            },
                        ),
                    ),
                ],
            );
    }
}
