pub mod init {
    use core::num::traits::Zero;
    use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};

    #[test]
    #[should_panic]
    fn test_should_panic_zero_address_for_trusted_issuers_registry() {
        let identity_registry_contract = declare("IdentityRegistry").unwrap().contract_class();
        identity_registry_contract
            .deploy(
                @array![
                    Zero::zero(),
                    starknet::contract_address_const::<'CLAIM_TOPICS_REGISTRY'>().into(),
                    starknet::contract_address_const::<'IDENTITY_STORAGE'>().into(),
                    starknet::contract_address_const::<'IMPLEMENTATION_AUTHORITY'>().into(),
                    starknet::get_contract_address().into(),
                ],
            )
            .unwrap();
    }

    #[test]
    #[should_panic]
    fn test_should_panic_zero_address_for_claim_topics_registry() {
        let identity_registry_contract = declare("IdentityRegistry").unwrap().contract_class();
        identity_registry_contract
            .deploy(
                @array![
                    starknet::contract_address_const::<'TRUSTED_ISSUERS_REGISTRY'>().into(),
                    Zero::zero(),
                    starknet::contract_address_const::<'IDENTITY_STORAGE'>().into(),
                    starknet::contract_address_const::<'IMPLEMENTATION_AUTHORITY'>().into(),
                    starknet::get_contract_address().into(),
                ],
            )
            .unwrap();
    }

    #[test]
    #[should_panic]
    fn test_should_panic_zero_address_for_identity_storage() {
        let identity_registry_contract = declare("IdentityRegistry").unwrap().contract_class();
        identity_registry_contract
            .deploy(
                @array![
                    starknet::contract_address_const::<'TRUSTED_ISSUERS_REGISTRY'>().into(),
                    starknet::contract_address_const::<'CLAIM_TOPICS_REGISTRY'>().into(),
                    Zero::zero(),
                    starknet::contract_address_const::<'IMPLEMENTATION_AUTHORITY'>().into(),
                    starknet::get_contract_address().into(),
                ],
            )
            .unwrap();
    }

    #[test]
    #[should_panic]
    fn test_should_panic_zero_address_for_owner() {
        let identity_registry_contract = declare("IdentityRegistry").unwrap().contract_class();
        identity_registry_contract
            .deploy(
                @array![
                    starknet::contract_address_const::<'TRUSTED_ISSUERS_REGISTRY'>().into(),
                    starknet::contract_address_const::<'CLAIM_TOPICS_REGISTRY'>().into(),
                    starknet::contract_address_const::<'IDENTITY_STORAGE'>().into(),
                    starknet::contract_address_const::<'IMPLEMENTATION_AUTHORITY'>().into(),
                    Zero::zero(),
                ],
            )
            .unwrap();
    }
}

pub mod register_identity {
    use factory::tests_common::setup_full_suite;
    use registry::{
        identity_registry::IdentityRegistry,
        interface::iidentity_registry::IIdentityRegistryDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_panic_when_caller_is_not_agent() {
        let setup = setup_full_suite();

        let investor_address = starknet::contract_address_const::<'INVESTOR_ADDRESS'>();
        let investor_identity = starknet::contract_address_const::<'INVESTOR_ID'>();
        let investor_country = 42;

        setup
            .identity_registry
            .register_identity(investor_address, investor_identity, investor_country);
    }

    #[test]
    fn test_should_register_identity() {
        let setup = setup_full_suite();
        let investor_address = starknet::contract_address_const::<'INVESTOR_ADDRESS'>();
        let investor_identity = starknet::contract_address_const::<'INVESTOR_ID'>();
        let investor_country = 42;

        let mut spy = spy_events();
        start_cheat_caller_address(
            setup.identity_registry.contract_address,
            setup.accounts.token_agent.account.contract_address,
        );
        setup
            .identity_registry
            .register_identity(investor_address, investor_identity, investor_country);
        stop_cheat_caller_address(setup.identity_registry.contract_address);
        assert(
            setup.identity_registry.identity(investor_address) == investor_identity,
            'Investor id does not match',
        );
        assert(
            setup.identity_registry.investor_country(investor_address) == investor_country,
            'Investor country does not match',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        setup.identity_registry.contract_address,
                        IdentityRegistry::Event::IdentityRegistered(
                            IdentityRegistry::IdentityRegistered {
                                investor_address, identity: investor_identity,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod batch_register_identity {
    use factory::tests_common::setup_full_suite;
    use registry::{
        identity_registry::IdentityRegistry,
        interface::iidentity_registry::IIdentityRegistryDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_panic_when_caller_is_not_agent() {
        let setup = setup_full_suite();

        let first_investor_address = starknet::contract_address_const::<'FIRST_INVESTOR_ADDRESS'>();
        let first_investor_identity = starknet::contract_address_const::<'FIRST_INVESTOR_ID'>();
        let first_investor_country = 42;
        let second_investor_address = starknet::contract_address_const::<
            'SECOND_INVESTOR_ADDRESS',
        >();
        let second_investor_identity = starknet::contract_address_const::<'SECOND_INVESTOR_ID'>();
        let second_investor_country = 43;

        setup
            .identity_registry
            .batch_register_identity(
                [first_investor_address, second_investor_address].span(),
                [first_investor_identity, second_investor_identity].span(),
                [first_investor_country, second_investor_country].span(),
            );
    }

    #[test]
    #[should_panic(expected: 'Arrays lenghts not equal')]
    fn test_should_panic_when_arrays_not_parralel() {
        let setup = setup_full_suite();

        let first_investor_address = starknet::contract_address_const::<'FIRST_INVESTOR_ADDRESS'>();
        let first_investor_identity = starknet::contract_address_const::<'FIRST_INVESTOR_ID'>();
        let first_investor_country = 42;
        let second_investor_address = starknet::contract_address_const::<
            'SECOND_INVESTOR_ADDRESS',
        >();
        let second_investor_identity = starknet::contract_address_const::<'SECOND_INVESTOR_ID'>();
        let second_investor_country = 43;

        start_cheat_caller_address(
            setup.identity_registry.contract_address,
            setup.accounts.token_agent.account.contract_address,
        );
        setup
            .identity_registry
            .batch_register_identity(
                [first_investor_address, second_investor_address].span(),
                [first_investor_identity, second_investor_identity].span(),
                [first_investor_country, second_investor_country, 66].span(),
            );
        stop_cheat_caller_address(setup.identity_registry.contract_address);
    }

    #[test]
    fn test_should_batch_register_identity() {
        let setup = setup_full_suite();
        let first_investor_address = starknet::contract_address_const::<'FIRST_INVESTOR_ADDRESS'>();
        let first_investor_identity = starknet::contract_address_const::<'FIRST_INVESTOR_ID'>();
        let first_investor_country = 42;
        let second_investor_address = starknet::contract_address_const::<
            'SECOND_INVESTOR_ADDRESS',
        >();
        let second_investor_identity = starknet::contract_address_const::<'SECOND_INVESTOR_ID'>();
        let second_investor_country = 43;

        let mut spy = spy_events();
        start_cheat_caller_address(
            setup.identity_registry.contract_address,
            setup.accounts.token_agent.account.contract_address,
        );
        setup
            .identity_registry
            .batch_register_identity(
                [first_investor_address, second_investor_address].span(),
                [first_investor_identity, second_investor_identity].span(),
                [first_investor_country, second_investor_country].span(),
            );
        stop_cheat_caller_address(setup.identity_registry.contract_address);

        assert(
            setup.identity_registry.identity(first_investor_address) == first_investor_identity,
            'Investor id does not match',
        );
        assert(
            setup
                .identity_registry
                .investor_country(first_investor_address) == first_investor_country,
            'Investor country does not match',
        );
        assert(
            setup.identity_registry.identity(second_investor_address) == second_investor_identity,
            'Investor id does not match',
        );
        assert(
            setup
                .identity_registry
                .investor_country(second_investor_address) == second_investor_country,
            'Investor country does not match',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        setup.identity_registry.contract_address,
                        IdentityRegistry::Event::IdentityRegistered(
                            IdentityRegistry::IdentityRegistered {
                                investor_address: first_investor_address,
                                identity: first_investor_identity,
                            },
                        ),
                    ),
                    (
                        setup.identity_registry.contract_address,
                        IdentityRegistry::Event::IdentityRegistered(
                            IdentityRegistry::IdentityRegistered {
                                investor_address: second_investor_address,
                                identity: second_investor_identity,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod delete_identity {
    use core::num::traits::Zero;
    use factory::tests_common::setup_full_suite;
    use registry::{
        identity_registry::IdentityRegistry,
        interface::iidentity_registry::IIdentityRegistryDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_panic_when_caller_is_not_agent() {
        let setup = setup_full_suite();
        let investor_address = starknet::contract_address_const::<'INVESTOR_ADDRESS'>();

        setup.identity_registry.delete_identity(investor_address);
    }

    #[test]
    fn test_should_delete_identity() {
        let setup = setup_full_suite();
        let investor_address = starknet::contract_address_const::<'INVESTOR_ADDRESS'>();
        let investor_identity = starknet::contract_address_const::<'INVESTOR_ID'>();
        let investor_country = 42;

        start_cheat_caller_address(
            setup.identity_registry.contract_address,
            setup.accounts.token_agent.account.contract_address,
        );
        setup
            .identity_registry
            .register_identity(investor_address, investor_identity, investor_country);

        let mut spy = spy_events();
        setup.identity_registry.delete_identity(investor_address);
        stop_cheat_caller_address(setup.identity_registry.contract_address);

        assert(
            setup.identity_registry.identity(investor_address) == Zero::zero(),
            'Investor id does not match',
        );
        assert(
            setup.identity_registry.investor_country(investor_address) == Zero::zero(),
            'Investor country does not match',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        setup.identity_registry.contract_address,
                        IdentityRegistry::Event::IdentityRemoved(
                            IdentityRegistry::IdentityRemoved {
                                investor_address, identity: investor_identity,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod update_identity {
    use factory::tests_common::setup_full_suite;
    use registry::{
        identity_registry::IdentityRegistry,
        interface::iidentity_registry::IIdentityRegistryDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_panic_when_caller_is_not_agent() {
        let setup = setup_full_suite();
        let investor_address = starknet::contract_address_const::<'INVESTOR_ADDRESS'>();
        let new_identity = starknet::contract_address_const::<'NEW_INVESTOR_ID'>();

        setup.identity_registry.update_identity(investor_address, new_identity);
    }

    #[test]
    fn test_should_update_identity() {
        let setup = setup_full_suite();
        let investor_address = starknet::contract_address_const::<'INVESTOR_ADDRESS'>();
        let investor_identity = starknet::contract_address_const::<'INVESTOR_ID'>();
        let investor_country = 42;
        let new_identity = starknet::contract_address_const::<'NEW_INVESTOR_ID'>();

        start_cheat_caller_address(
            setup.identity_registry.contract_address,
            setup.accounts.token_agent.account.contract_address,
        );
        setup
            .identity_registry
            .register_identity(investor_address, investor_identity, investor_country);

        let mut spy = spy_events();
        setup.identity_registry.update_identity(investor_address, new_identity);
        stop_cheat_caller_address(setup.identity_registry.contract_address);

        assert(
            setup.identity_registry.identity(investor_address) == new_identity,
            'Investor id does not match',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        setup.identity_registry.contract_address,
                        IdentityRegistry::Event::IdentityUpdated(
                            IdentityRegistry::IdentityUpdated {
                                old_identity: investor_identity, new_identity,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod update_country {
    use factory::tests_common::setup_full_suite;
    use registry::{
        identity_registry::IdentityRegistry,
        interface::iidentity_registry::IIdentityRegistryDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_panic_when_caller_is_not_agent() {
        let setup = setup_full_suite();
        let investor_address = starknet::contract_address_const::<'INVESTOR_ADDRESS'>();
        let new_country = 30;

        setup.identity_registry.update_country(investor_address, new_country);
    }

    #[test]
    fn test_should_update_country() {
        let setup = setup_full_suite();
        let investor_address = starknet::contract_address_const::<'INVESTOR_ADDRESS'>();
        let investor_identity = starknet::contract_address_const::<'INVESTOR_ID'>();
        let investor_country = 42;
        let new_country = 30;

        start_cheat_caller_address(
            setup.identity_registry.contract_address,
            setup.accounts.token_agent.account.contract_address,
        );
        setup
            .identity_registry
            .register_identity(investor_address, investor_identity, investor_country);

        let mut spy = spy_events();
        setup.identity_registry.update_country(investor_address, new_country);
        stop_cheat_caller_address(setup.identity_registry.contract_address);

        assert(
            setup.identity_registry.investor_country(investor_address) == new_country,
            'Investor country does not match',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        setup.identity_registry.contract_address,
                        IdentityRegistry::Event::CountryUpdated(
                            IdentityRegistry::CountryUpdated {
                                investor_address, country: new_country,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod set_identity_registry_storage {
    use factory::tests_common::setup_full_suite;
    use registry::{
        identity_registry::IdentityRegistry,
        interface::iidentity_registry::IIdentityRegistryDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_the_owner() {
        let setup = setup_full_suite();
        let new_ir_storage = starknet::contract_address_const::<'NEW_IR_STORAGE'>();

        start_cheat_caller_address(
            setup.identity_registry.contract_address,
            starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        setup.identity_registry.set_identity_registry_storage(new_ir_storage);
        stop_cheat_caller_address(setup.identity_registry.contract_address);
    }

    #[test]
    fn test_should_set_the_identity_registry_storage() {
        let setup = setup_full_suite();
        let new_ir_storage = starknet::contract_address_const::<'NEW_IR_STORAGE'>();

        let mut spy = spy_events();
        setup.identity_registry.set_identity_registry_storage(new_ir_storage);

        assert(
            setup.identity_registry.identity_storage().contract_address == new_ir_storage,
            'Identity Storage does not match',
        );
        spy
            .assert_emitted(
                @array![
                    (
                        setup.identity_registry.contract_address,
                        IdentityRegistry::Event::IdentityStorageSet(
                            IdentityRegistry::IdentityStorageSet {
                                identity_storage: new_ir_storage,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod set_claim_topics_registry {
    use factory::tests_common::setup_full_suite;
    use registry::{
        identity_registry::IdentityRegistry,
        interface::iidentity_registry::IIdentityRegistryDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_the_owner() {
        let setup = setup_full_suite();
        let new_claim_topics_registry = starknet::contract_address_const::<
            'NEW_CLAIM_TOPICS_REGISTRY',
        >();

        start_cheat_caller_address(
            setup.identity_registry.contract_address,
            starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        setup.identity_registry.set_claim_topics_registry(new_claim_topics_registry);
        stop_cheat_caller_address(setup.identity_registry.contract_address);
    }

    #[test]
    fn test_should_set_the_claim_topics_registry() {
        let setup = setup_full_suite();
        let new_claim_topics_registry = starknet::contract_address_const::<
            'NEW_CLAIM_TOPICS_REGISTRY',
        >();

        let mut spy = spy_events();
        setup.identity_registry.set_claim_topics_registry(new_claim_topics_registry);

        assert!(
            setup.identity_registry.topics_registry().contract_address == new_claim_topics_registry,
            "Claim topics registry does not match",
        );
        spy
            .assert_emitted(
                @array![
                    (
                        setup.identity_registry.contract_address,
                        IdentityRegistry::Event::ClaimTopicsRegistrySet(
                            IdentityRegistry::ClaimTopicsRegistrySet {
                                claim_topics_registry: new_claim_topics_registry,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod set_trusted_issuers_registry {
    use factory::tests_common::setup_full_suite;
    use registry::{
        identity_registry::IdentityRegistry,
        interface::iidentity_registry::IIdentityRegistryDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_the_owner() {
        let setup = setup_full_suite();
        let new_trusted_issuers_registry = starknet::contract_address_const::<
            'NEW_TRUSTED_ISSUERS_REGISTRY',
        >();

        start_cheat_caller_address(
            setup.identity_registry.contract_address,
            starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        setup.identity_registry.set_trusted_issuers_registry(new_trusted_issuers_registry);
        stop_cheat_caller_address(setup.identity_registry.contract_address);
    }

    #[test]
    fn test_should_set_the_trusted_issuers_registry() {
        let setup = setup_full_suite();
        let new_trusted_issuers_registry = starknet::contract_address_const::<
            'NEW_TRUSTED_ISSUERS_REGISTRY',
        >();

        let mut spy = spy_events();
        setup.identity_registry.set_trusted_issuers_registry(new_trusted_issuers_registry);

        assert!(
            setup
                .identity_registry
                .issuers_registry()
                .contract_address == new_trusted_issuers_registry,
            "Trusted issuers registry does not match",
        );
        spy
            .assert_emitted(
                @array![
                    (
                        setup.identity_registry.contract_address,
                        IdentityRegistry::Event::TrustedIssuersRegistrySet(
                            IdentityRegistry::TrustedIssuersRegistrySet {
                                trusted_issuers_registry: new_trusted_issuers_registry,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod is_verified {
    use core::num::traits::Zero;
    use factory::tests_common::setup_full_suite;
    use onchain_id_starknet::interface::{
        iclaim_issuer::ClaimIssuerABIDispatcherTrait, iidentity::IdentityABIDispatcherTrait,
    };
    use registry::interface::{
        iclaim_topics_registry::IClaimTopicsRegistryDispatcherTrait,
        iidentity_registry::IIdentityRegistryDispatcherTrait,
        itrusted_issuers_registry::ITrustedIssuersRegistryDispatcherTrait,
    };
    use snforge_std::{mock_call, start_cheat_caller_address, stop_cheat_caller_address};

    #[test]
    fn test_should_return_true_when_the_identity_is_registered_when_there_are_no_required_claim_topics() {
        let setup = setup_full_suite();
        let investor_address = setup.accounts.charlie.account.contract_address;
        let investor_identity = setup.onchain_id.charlie_identity.contract_address;
        let investor_country = Zero::zero();

        start_cheat_caller_address(
            setup.identity_registry.contract_address,
            setup.accounts.token_agent.account.contract_address,
        );
        setup
            .identity_registry
            .register_identity(investor_address, investor_identity, investor_country);
        stop_cheat_caller_address(setup.identity_registry.contract_address);

        let verification_result = setup.identity_registry.is_verified(investor_address);
        assert(!verification_result, 'Should have returned false');

        let topics = setup.claim_topics_registry.get_claim_topics();
        for topic in topics {
            setup.claim_topics_registry.remove_claim_topic(*topic);
        };

        let verification_result = setup.identity_registry.is_verified(investor_address);
        assert(verification_result, 'Should have returned true');
    }

    #[test]
    fn test_should_return_false_when_claim_topics_are_required_but_there_are_no_trusted_issuers_for_them() {
        let setup = setup_full_suite();
        let investor_address = setup.accounts.alice.account.contract_address;
        let topics = setup.claim_topics_registry.get_claim_topics();
        let trusted_issuers = setup
            .trusted_issuers_registry
            .get_trusted_issuers_for_claim_topic(*topics.at(0));
        for issuer in trusted_issuers {
            setup.trusted_issuers_registry.remove_trusted_issuer(*issuer);
        };

        let verification_result = setup.identity_registry.is_verified(investor_address);
        assert(!verification_result, 'Should have returned false');
    }

    #[test]
    fn test_should_return_false_when_the_only_claim_required_was_revoked() {
        let setup = setup_full_suite();
        let investor_address = setup.accounts.alice.account.contract_address;
        let verification_result = setup.identity_registry.is_verified(investor_address);
        assert(verification_result, 'Should have returned true');

        let topics = setup.claim_topics_registry.get_claim_topics();
        let claim_ids = setup.onchain_id.alice_identity.get_claim_ids_by_topics(*topics.at(0));
        let (_, _, _, sig, _, _) = setup.onchain_id.alice_identity.get_claim(*claim_ids.at(0));

        start_cheat_caller_address(
            setup.onchain_id.claim_issuer.contract_address,
            setup.accounts.claim_issuer.account.contract_address,
        );
        setup.onchain_id.claim_issuer.revoke_claim_by_signature(sig);
        stop_cheat_caller_address(setup.onchain_id.claim_issuer.contract_address);

        let verification_result = setup.identity_registry.is_verified(investor_address);
        assert(!verification_result, 'Should have returned false');
    }

    #[test]
    fn test_should_return_false_when_there_is_no_identity_stored_for_wallet() {
        let setup = setup_full_suite();

        let verification_result = setup
            .identity_registry
            .is_verified(starknet::contract_address_const::<'WALLET_W_O_IDENTITY'>());
        assert(!verification_result, 'Should have returned false');
    }

    #[test]
    fn test_should_return_true_when_there_is_valid_claim() {
        let setup = setup_full_suite();
        let investor_address = setup.accounts.alice.account.contract_address;
        let verification_result = setup.identity_registry.is_verified(investor_address);
        assert(verification_result, 'Should have returned true');
    }

    #[test]
    fn test_should_return_true_when_multiple_trusted_issuer_at_least_one_valid_claim() {
        let setup = setup_full_suite();
        let investor_address = setup.accounts.alice.account.contract_address;
        let topics = setup.claim_topics_registry.get_claim_topics();
        let trusted_issuers = setup
            .trusted_issuers_registry
            .get_trusted_issuers_for_claim_topic(*topics.at(0));
        for issuer in trusted_issuers {
            setup.trusted_issuers_registry.remove_trusted_issuer(*issuer);
        };

        let random_issuer = starknet::contract_address_const::<'RANDOM_ISSUER'>();
        setup.trusted_issuers_registry.add_trusted_issuer(random_issuer, [*topics.at(0)].span());
        mock_call(random_issuer, selector!("is_claim_valid"), false, 1);

        for issuer in trusted_issuers {
            setup.trusted_issuers_registry.add_trusted_issuer(*issuer, [*topics.at(0)].span());
        };
        let verification_result = setup.identity_registry.is_verified(investor_address);
        assert(verification_result, 'Should have returned true');
    }
}
