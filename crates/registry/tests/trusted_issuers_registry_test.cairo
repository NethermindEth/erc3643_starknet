use registry::interface::itrusted_issuers_registry::ITrustedIssuersRegistryDispatcher;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};

fn setup() -> ITrustedIssuersRegistryDispatcher {
    let trusted_issuers_registry_contract = declare("TrustedIssuersRegistry")
        .unwrap()
        .contract_class();
    let (deployed_address, _) = trusted_issuers_registry_contract
        .deploy(@array![starknet::get_contract_address().into()])
        .unwrap();
    ITrustedIssuersRegistryDispatcher { contract_address: deployed_address }
}

pub mod add_trusted_issuer {
    use core::num::traits::Zero;
    use registry::{
        interface::itrusted_issuers_registry::ITrustedIssuersRegistryDispatcherTrait,
        trusted_issuers_registry::TrustedIssuersRegistry,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_owner() {
        let registry = setup();

        start_cheat_caller_address(
            registry.contract_address, starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        registry
            .add_trusted_issuer(
                starknet::contract_address_const::<'TRUSTED_ISSUER'>(), ['CLAIM_TOPIC'].span(),
            );
        stop_cheat_caller_address(registry.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Zero Address: Trusted Issuer')]
    fn test_should_panic_when_trusted_issuer_is_zero_address() {
        let registry = setup();

        registry.add_trusted_issuer(Zero::zero(), ['CLAIM_TOPIC'].span());
    }


    #[test]
    #[should_panic(expected: 'Claim topics cannot be empty')]
    fn test_should_panic_when_claim_topics_empty() {
        let registry = setup();

        registry
            .add_trusted_issuer(starknet::contract_address_const::<'TRUSTED_ISSUER'>(), [].span());
    }

    #[test]
    #[should_panic(expected: 'Max 15 claim topics')]
    fn test_should_panic_when_claim_topics_more_than_15() {
        let registry = setup();

        let mut claim_topics: Array<felt252> = array![];
        for topic in 0..16_u8 {
            claim_topics.append(topic.into());
        };

        registry
            .add_trusted_issuer(
                starknet::contract_address_const::<'TRUSTED_ISSUER'>(), claim_topics.span(),
            );
    }

    #[test]
    fn test_should_add_trusted_issuer() {
        let registry = setup();
        let trusted_issuer = starknet::contract_address_const::<'TRUSTED_ISSUER'>();
        let claim_topic = 'CLAIM_TOPIC';
        let claim_topics = [claim_topic].span();

        let mut spy = spy_events();

        registry.add_trusted_issuer(trusted_issuer, claim_topics);

        assert(registry.is_trusted_issuer(trusted_issuer), 'Trusted issuer not added');
        assert!(
            registry.get_trusted_issuers() == [trusted_issuer].span(),
            "Trusted Issuer does not match",
        );
        assert!(
            registry.get_trusted_issuer_claim_topics(trusted_issuer) == claim_topics,
            "Trusted issuer claim topics mismatch",
        );
        assert!(
            registry.get_trusted_issuers_for_claim_topic(claim_topic) == [trusted_issuer].span(),
            "Trusted issuer for claim topics mismatch",
        );
        assert!(registry.has_claim_topic(trusted_issuer, claim_topic), "Does not has claim topic");

        spy
            .assert_emitted(
                @array![
                    (
                        registry.contract_address,
                        TrustedIssuersRegistry::Event::TrustedIssuerAdded(
                            TrustedIssuersRegistry::TrustedIssuerAdded {
                                trusted_issuer, claim_topics,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic(expected: 'Trusted Issuer already exists')]
    fn test_should_panic_when_trusted_issuer_already_exists() {
        let registry = setup();
        let trusted_issuer = starknet::contract_address_const::<'TRUSTED_ISSUER'>();
        let claim_topic = 'CLAIM_TOPIC';
        let claim_topics = [claim_topic].span();

        registry.add_trusted_issuer(trusted_issuer, claim_topics);
        /// adding second time should panic
        registry.add_trusted_issuer(trusted_issuer, claim_topics);
    }

    #[test]
    #[should_panic(expected: 'Max 50 trusted issuers')]
    fn test_should_panic_when_trusted_issuers_exceed_50() {
        let registry = setup();
        let trusted_issuer = starknet::contract_address_const::<'TRUSTED_ISSUER'>();
        let claim_topic = 'CLAIM_TOPIC';
        let claim_topics = [claim_topic].span();

        for i in 100..150_u16 {
            registry
                .add_trusted_issuer(
                    Into::<u16, felt252>::into(i).try_into().unwrap(), claim_topics,
                );
        };
        /// Adding the 51th should panic
        registry.add_trusted_issuer(trusted_issuer, claim_topics);
    }
}

pub mod remove_trusted_issuer {
    use core::num::traits::Zero;
    use registry::{
        interface::itrusted_issuers_registry::ITrustedIssuersRegistryDispatcherTrait,
        trusted_issuers_registry::TrustedIssuersRegistry,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_owner() {
        let registry = setup();

        start_cheat_caller_address(
            registry.contract_address, starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        registry.remove_trusted_issuer(starknet::contract_address_const::<'TRUSTED_ISSUER'>());
        stop_cheat_caller_address(registry.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Zero Address: Trusted Issuer')]
    fn test_should_panic_when_trusted_issuer_is_zero_address() {
        let registry = setup();

        registry.remove_trusted_issuer(Zero::zero());
    }

    #[test]
    #[should_panic(expected: 'Trusted Issuer not exists')]
    fn test_should_panic_when_trusted_issuer_not_exists() {
        let registry = setup();

        registry.remove_trusted_issuer(starknet::contract_address_const::<'TRUSTED_ISSUER'>());
    }

    #[test]
    fn test_should_remove_trusted_issuer() {
        let registry = setup();
        let trusted_issuer = starknet::contract_address_const::<'TRUSTED_ISSUER'>();
        let claim_topic = 'CLAIM_TOPIC';

        registry.add_trusted_issuer(trusted_issuer, [claim_topic].span());

        let mut spy = spy_events();

        registry.remove_trusted_issuer(trusted_issuer);

        assert(!registry.is_trusted_issuer(trusted_issuer), 'Trusted issuer not removed');
        assert!(registry.get_trusted_issuers() == [].span(), "Trusted Issuer does not match");
        assert!(
            registry.get_trusted_issuers_for_claim_topic(claim_topic) == [].span(),
            "Trusted issuer for claim topics mismatch",
        );
        assert!(
            !registry.has_claim_topic(trusted_issuer, claim_topic), "Issuer still has claim topic",
        );

        spy
            .assert_emitted(
                @array![
                    (
                        registry.contract_address,
                        TrustedIssuersRegistry::Event::TrustedIssuerRemoved(
                            TrustedIssuersRegistry::TrustedIssuerRemoved { trusted_issuer },
                        ),
                    ),
                ],
            );
    }
}

pub mod update_issuer_claim_topics {
    use core::num::traits::Zero;
    use registry::{
        interface::itrusted_issuers_registry::ITrustedIssuersRegistryDispatcherTrait,
        trusted_issuers_registry::TrustedIssuersRegistry,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_owner() {
        let registry = setup();

        start_cheat_caller_address(
            registry.contract_address, starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        registry
            .update_issuer_claim_topics(
                starknet::contract_address_const::<'TRUSTED_ISSUER'>(), ['CLAIM_TOPIC'].span(),
            );
        stop_cheat_caller_address(registry.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Zero Address: Trusted Issuer')]
    fn test_should_panic_when_trusted_issuer_is_zero_address() {
        let registry = setup();

        registry.update_issuer_claim_topics(Zero::zero(), ['CLAIM_TOPIC'].span());
    }

    #[test]
    #[should_panic(expected: 'Trusted Issuer not exists')]
    fn test_should_panic_when_trusted_issuer_not_exists() {
        let registry = setup();

        registry
            .update_issuer_claim_topics(
                starknet::contract_address_const::<'TRUSTED_ISSUER'>(), ['CLAIM_TOPIC'].span(),
            );
    }

    #[test]
    #[should_panic(expected: 'Claim topics cannot be empty')]
    fn test_should_panic_when_claim_topics_empty() {
        let registry = setup();

        let trusted_issuer = starknet::contract_address_const::<'TRUSTED_ISSUER'>();
        registry.add_trusted_issuer(trusted_issuer, ['CLAIM_TOPIC'].span());

        registry.update_issuer_claim_topics(trusted_issuer, [].span());
    }

    #[test]
    #[should_panic(expected: 'Max 15 claim topics')]
    fn test_should_panic_when_claim_topics_more_than_15() {
        let registry = setup();

        let trusted_issuer = starknet::contract_address_const::<'TRUSTED_ISSUER'>();
        registry.add_trusted_issuer(trusted_issuer, ['CLAIM_TOPIC'].span());

        let mut claim_topics: Array<felt252> = array![];
        for topic in 0..16_u8 {
            claim_topics.append(topic.into());
        };
        registry.update_issuer_claim_topics(trusted_issuer, claim_topics.span());
    }

    #[test]
    fn test_should_update_issuer_claim_topics() {
        let registry = setup();

        let trusted_issuer = starknet::contract_address_const::<'TRUSTED_ISSUER'>();
        registry.add_trusted_issuer(trusted_issuer, ['CLAIM_TOPIC'].span());

        let new_claim_topics = ['FIRST_CLAIM_TOPIC', 'SECOND_CLAIM_TOPIC'].span();

        let mut spy = spy_events();

        registry.update_issuer_claim_topics(trusted_issuer, new_claim_topics);

        assert!(
            registry.get_trusted_issuer_claim_topics(trusted_issuer) == new_claim_topics,
            "Trusted issuer claim topics mismatch",
        );
        assert!(
            !registry.has_claim_topic(trusted_issuer, 'CLAIM_TOPIC'), "Old claim topic not removed",
        );
        for topic in new_claim_topics {
            assert!(
                registry.get_trusted_issuers_for_claim_topic(*topic) == [trusted_issuer].span(),
                "Trusted issuer for claim topics mismatch",
            );
            assert!(registry.has_claim_topic(trusted_issuer, *topic), "Does not has claim topic");
        };

        spy
            .assert_emitted(
                @array![
                    (
                        registry.contract_address,
                        TrustedIssuersRegistry::Event::ClaimTopicsUpdated(
                            TrustedIssuersRegistry::ClaimTopicsUpdated {
                                trusted_issuer, claim_topics: new_claim_topics,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod get_trusted_issuers {
    use registry::interface::itrusted_issuers_registry::ITrustedIssuersRegistryDispatcherTrait;
    use super::setup;

    #[test]
    fn test_should_return_trusted_issuers() {
        let registry = setup();
        let trusted_issuers = [
            starknet::contract_address_const::<'FIRST_TRUSTED_ISSUER'>(),
            starknet::contract_address_const::<'SECOND_TRUSTED_ISSUER'>(),
        ]
            .span();
        let claim_topics = ['CLAIM_TOPIC'].span();

        for issuer in trusted_issuers {
            registry.add_trusted_issuer(*issuer, claim_topics);
        };

        assert(registry.get_trusted_issuers() == trusted_issuers, 'Trusted Issuers does not match');
    }
}

pub mod get_trusted_issuers_for_claim_topic {
    use registry::interface::itrusted_issuers_registry::ITrustedIssuersRegistryDispatcherTrait;
    use super::setup;

    #[test]
    fn test_should_return_trusted_issuers_for_claim_topic() {
        let registry = setup();
        let trusted_issuers = [
            starknet::contract_address_const::<'FIRST_TRUSTED_ISSUER'>(),
            starknet::contract_address_const::<'SECOND_TRUSTED_ISSUER'>(),
        ]
            .span();
        let claim_topics = ['CLAIM_TOPIC'].span();

        for issuer in trusted_issuers {
            registry.add_trusted_issuer(*issuer, claim_topics);
        };

        assert!(
            registry.get_trusted_issuers_for_claim_topic('CLAIM_TOPIC') == trusted_issuers,
            "Trusted Issuers for claim topic does not match",
        );
    }
}

pub mod is_trusted_issuer {
    use registry::interface::itrusted_issuers_registry::ITrustedIssuersRegistryDispatcherTrait;
    use super::setup;

    #[test]
    fn test_should_return_true_if_trusted_issuer_exists() {
        let registry = setup();
        let trusted_issuer = starknet::contract_address_const::<'TRUSTED_ISSUER'>();

        registry.add_trusted_issuer(trusted_issuer, ['CLAIM_TOPIC'].span());

        assert(registry.is_trusted_issuer(trusted_issuer), 'Should have returned true');
    }

    #[test]
    fn test_should_return_false_if_trusted_issuer_does_not_exist() {
        let registry = setup();

        assert(
            !registry.is_trusted_issuer(starknet::contract_address_const::<'TRUSTED_ISSUER'>()),
            'Should have returned false',
        );
    }
}

pub mod get_trusted_issuer_claim_topics {
    use registry::interface::itrusted_issuers_registry::ITrustedIssuersRegistryDispatcherTrait;
    use super::setup;

    #[test]
    fn test_should_return_claim_topics_for_trusted_issuer() {
        let registry = setup();
        let trusted_issuer = starknet::contract_address_const::<'TRUSTED_ISSUER'>();
        let claim_topics = ['FIRST_CLAIM_TOPIC', 'SECOND_CLAIM_TOPIC'].span();
        registry.add_trusted_issuer(trusted_issuer, claim_topics);

        assert!(
            registry.get_trusted_issuer_claim_topics(trusted_issuer) == claim_topics,
            "Trusted Issuer claim topics mismatch",
        );
    }

    #[test]
    #[should_panic(expected: 'Trusted Issuer not exists')]
    fn test_should_panic_when_trusted_issuer_does_not_exist() {
        let registry = setup();

        registry
            .get_trusted_issuer_claim_topics(
                starknet::contract_address_const::<'TRUSTED_ISSUER'>(),
            );
    }
}

pub mod has_claim_topic {
    use registry::interface::itrusted_issuers_registry::ITrustedIssuersRegistryDispatcherTrait;
    use super::setup;

    #[test]
    fn test_should_return_true_if_trusted_issuer_has_claim_topic() {
        let registry = setup();
        let trusted_issuer = starknet::contract_address_const::<'TRUSTED_ISSUER'>();
        let claim_topic = 'CLAIM_TOPIC';

        registry.add_trusted_issuer(trusted_issuer, [claim_topic].span());

        assert(registry.has_claim_topic(trusted_issuer, claim_topic), 'Should have returned true');
    }

    #[test]
    fn test_should_return_false_if_trusted_issuer_does_not_have_claim_topic() {
        let registry = setup();
        let trusted_issuer = starknet::contract_address_const::<'TRUSTED_ISSUER'>();
        let claim_topic = 'CLAIM_TOPIC';

        assert(
            !registry.has_claim_topic(trusted_issuer, claim_topic), 'Should have returned false',
        );
    }
}
