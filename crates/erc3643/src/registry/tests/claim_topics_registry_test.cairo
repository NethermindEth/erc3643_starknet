use crate::registry::interface::iclaim_topics_registry::IClaimTopicsRegistryDispatcher;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};

fn setup() -> IClaimTopicsRegistryDispatcher {
    let claim_topics_registry_contract = declare("ClaimTopicsRegistry").unwrap().contract_class();
    let (deployed_address, _) = claim_topics_registry_contract
        .deploy(
            @array![
                starknet::contract_address_const::<'IMPLEMENTATION_AUTHORITY'>().into(),
                starknet::get_contract_address().into(),
            ],
        )
        .unwrap();
    IClaimTopicsRegistryDispatcher { contract_address: deployed_address }
}

pub mod add_claim_topic {
    use crate::registry::{
        claim_topics_registry::ClaimTopicsRegistry,
        interface::iclaim_topics_registry::IClaimTopicsRegistryDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_sender_is_not_owner() {
        let registry = setup();

        start_cheat_caller_address(
            registry.contract_address, starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        registry.add_claim_topic('CLAIM_TOPIC');
        stop_cheat_caller_address(registry.contract_address);
    }

    #[test]
    fn test_should_add_claim_topic() {
        let registry = setup();

        let claim_topic = 'CLAIM_TOPIC';
        let mut spy = spy_events();

        registry.add_claim_topic(claim_topic);

        assert(registry.get_claim_topics() == [claim_topic].span(), 'Claim topics does not match');

        spy
            .assert_emitted(
                @array![
                    (
                        registry.contract_address,
                        ClaimTopicsRegistry::Event::ClaimTopicAdded(
                            ClaimTopicsRegistry::ClaimTopicAdded { claim_topic },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic(expected: 'Claim topic already exist')]
    fn test_should_panic_when_topic_already_added() {
        let registry = setup();

        let claim_topic = 'CLAIM_TOPIC';
        registry.add_claim_topic(claim_topic);
        /// Adding second time should panic
        registry.add_claim_topic(claim_topic);
    }

    #[test]
    #[should_panic(expected: 'Max 15 claim topics exceeded')]
    fn test_should_panic_when_topic_array_contains_more_than_15_elements() {
        let registry = setup();

        for i in 0..15_u8 {
            registry.add_claim_topic(i.into());
        };
        /// Adding 16th should panic
        registry.add_claim_topic('16');
    }
}

pub mod remove_claim_topic {
    use crate::registry::{
        claim_topics_registry::ClaimTopicsRegistry,
        interface::iclaim_topics_registry::IClaimTopicsRegistryDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_sender_is_not_owner() {
        let registry = setup();

        start_cheat_caller_address(
            registry.contract_address, starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        registry.remove_claim_topic('CLAIM_TOPIC');
        stop_cheat_caller_address(registry.contract_address);
    }

    #[test]
    fn test_should_remove_claim_topic() {
        let registry = setup();
        let first_claim_topic = 'FIRST_CLAIM_TOPIC';
        let second_claim_topic = 'SECOND_CLAIM_TOPIC';
        let third_claim_topic = 'THIRD_CLAIM_TOPIC';

        registry.add_claim_topic(first_claim_topic);
        registry.add_claim_topic(second_claim_topic);
        registry.add_claim_topic(third_claim_topic);

        let mut spy = spy_events();
        registry.remove_claim_topic(second_claim_topic);
        assert(
            registry.get_claim_topics() == [first_claim_topic, third_claim_topic].span(),
            'Claim topic not removed',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        registry.contract_address,
                        ClaimTopicsRegistry::Event::ClaimTopicRemoved(
                            ClaimTopicsRegistry::ClaimTopicRemoved {
                                claim_topic: second_claim_topic,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod get_claim_topics {
    use crate::registry::interface::iclaim_topics_registry::IClaimTopicsRegistryDispatcherTrait;
    use super::setup;

    fn test_should_return_claim_topics() {
        let registry = setup();
        let first_claim_topic = 'FIRST_CLAIM_TOPIC';
        let second_claim_topic = 'SECOND_CLAIM_TOPIC';

        registry.add_claim_topic(first_claim_topic);
        registry.add_claim_topic(second_claim_topic);

        assert(
            registry.get_claim_topics() == [first_claim_topic, second_claim_topic].span(),
            'Claim topics does not match',
        );
    }
}
