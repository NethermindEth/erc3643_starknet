///! Add tests for batch operations
///! NOTE: Migth deploy full suite instead of mocks
use registry::interface::{
    iclaim_topics_registry::IClaimTopicsRegistryDispatcher,
    iidentity_registry::IIdentityRegistryDispatcher,
    iidentity_registry_storage::{
        IIdentityRegistryStorageDispatcher, IIdentityRegistryStorageDispatcherTrait,
    },
    itrusted_issuers_registry::ITrustedIssuersRegistryDispatcher,
};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};

#[derive(Drop, Copy)]
struct Setup {
    trusted_issuers_registry: ITrustedIssuersRegistryDispatcher,
    claim_topics_registry: IClaimTopicsRegistryDispatcher,
    identity_registry_storage: IIdentityRegistryStorageDispatcher,
    identity_registry: IIdentityRegistryDispatcher,
}

fn setup() -> Setup {
    // Deploy trusted issuers registry
    let trusted_issuers_registry_contract = declare("TrustedIssuersRegistry")
        .unwrap()
        .contract_class();
    let (trusted_issuers_registry_address, _) = trusted_issuers_registry_contract
        .deploy(@array![starknet::get_contract_address().into()])
        .unwrap();
    let trusted_issuers_registry = ITrustedIssuersRegistryDispatcher {
        contract_address: trusted_issuers_registry_address,
    };
    // Deploy identity registry storage
    let identity_registry_storage_contract = declare("IdentityRegistryStorage")
        .unwrap()
        .contract_class();
    let (identity_registry_storage_address, _) = identity_registry_storage_contract
        .deploy(@array![starknet::get_contract_address().into()])
        .unwrap();
    let identity_registry_storage = IIdentityRegistryStorageDispatcher {
        contract_address: identity_registry_storage_address,
    };
    // Deploy claim topics registry
    let claim_topics_registry_contract = declare("ClaimTopicsRegistry").unwrap().contract_class();
    let (claim_topics_registry_address, _) = claim_topics_registry_contract
        .deploy(@array![starknet::get_contract_address().into()])
        .unwrap();
    let claim_topics_registry = IClaimTopicsRegistryDispatcher {
        contract_address: claim_topics_registry_address,
    };
    // Deploy identity registry
    let identity_registry_contract = declare("IdentityRegistry").unwrap().contract_class();
    let (identity_registry_address, _) = identity_registry_contract
        .deploy(
            @array![
                trusted_issuers_registry_address.into(),
                claim_topics_registry_address.into(),
                identity_registry_storage_address.into(),
                starknet::get_contract_address().into(),
            ],
        )
        .unwrap();
    let identity_registry = IIdentityRegistryDispatcher {
        contract_address: identity_registry_address,
    };

    identity_registry_storage.bind_identity_registry(identity_registry_address);

    Setup {
        trusted_issuers_registry,
        claim_topics_registry,
        identity_registry_storage,
        identity_registry,
    }
}

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
                    Zero::zero(),
                ],
            )
            .unwrap();
    }
}

pub mod register_identity {
    use registry::{
        identity_registry::IdentityRegistry,
        interface::iidentity_registry::IIdentityRegistryDispatcherTrait,
    };
    use roles::agent_role::{IAgentRoleDispatcher, IAgentRoleDispatcherTrait};
    use snforge_std::{EventSpyAssertionsTrait, spy_events};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_panic_when_caller_is_not_agent() {
        let setup = setup();

        let investor_address = starknet::contract_address_const::<'ALICE'>();
        let investor_identity = starknet::contract_address_const::<'ALICE_ID'>();
        let investor_country = 42;

        setup
            .identity_registry
            .register_identity(investor_address, investor_identity, investor_country);
    }

    #[test]
    fn test_should_register_identity() {
        let setup = setup();
        IAgentRoleDispatcher { contract_address: setup.identity_registry.contract_address }
            .add_agent(starknet::get_contract_address());

        let investor_address = starknet::contract_address_const::<'ALICE'>();
        let investor_identity = starknet::contract_address_const::<'ALICE_ID'>();
        let investor_country = 42;

        let mut spy = spy_events();
        setup
            .identity_registry
            .register_identity(investor_address, investor_identity, investor_country);

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

pub mod delete_identity {
    use core::num::traits::Zero;
    use registry::{
        identity_registry::IdentityRegistry,
        interface::iidentity_registry::IIdentityRegistryDispatcherTrait,
    };
    use roles::agent_role::{IAgentRoleDispatcher, IAgentRoleDispatcherTrait};
    use snforge_std::{EventSpyAssertionsTrait, spy_events};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_panic_when_caller_is_not_agent() {
        let setup = setup();

        let investor_address = starknet::contract_address_const::<'ALICE'>();

        setup.identity_registry.delete_identity(investor_address);
    }

    #[test]
    fn test_should_delete_identity() {
        let setup = setup();
        IAgentRoleDispatcher { contract_address: setup.identity_registry.contract_address }
            .add_agent(starknet::get_contract_address());

        let investor_address = starknet::contract_address_const::<'ALICE'>();
        let investor_identity = starknet::contract_address_const::<'ALICE_ID'>();
        let investor_country = 42;

        setup
            .identity_registry
            .register_identity(investor_address, investor_identity, investor_country);

        let mut spy = spy_events();
        setup.identity_registry.delete_identity(investor_address);

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
    use registry::{
        identity_registry::IdentityRegistry,
        interface::iidentity_registry::IIdentityRegistryDispatcherTrait,
    };
    use roles::agent_role::{IAgentRoleDispatcher, IAgentRoleDispatcherTrait};
    use snforge_std::{EventSpyAssertionsTrait, spy_events};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_panic_when_caller_is_not_agent() {
        let setup = setup();

        let investor_address = starknet::contract_address_const::<'ALICE'>();
        let new_identity = starknet::contract_address_const::<'NEW_ALICE_ID'>();

        setup.identity_registry.update_identity(investor_address, new_identity);
    }

    #[test]
    fn test_should_update_identity() {
        let setup = setup();
        IAgentRoleDispatcher { contract_address: setup.identity_registry.contract_address }
            .add_agent(starknet::get_contract_address());

        let investor_address = starknet::contract_address_const::<'ALICE'>();
        let investor_identity = starknet::contract_address_const::<'ALICE_ID'>();
        let investor_country = 42;
        let new_identity = starknet::contract_address_const::<'NEW_ALICE_ID'>();

        setup
            .identity_registry
            .register_identity(investor_address, investor_identity, investor_country);

        let mut spy = spy_events();
        setup.identity_registry.update_identity(investor_address, new_identity);

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
    use registry::{
        identity_registry::IdentityRegistry,
        interface::iidentity_registry::IIdentityRegistryDispatcherTrait,
    };
    use roles::agent_role::{IAgentRoleDispatcher, IAgentRoleDispatcherTrait};
    use snforge_std::{EventSpyAssertionsTrait, spy_events};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_panic_when_caller_is_not_agent() {
        let setup = setup();

        let investor_address = starknet::contract_address_const::<'ALICE'>();
        let new_country = 30;

        setup.identity_registry.update_country(investor_address, new_country);
    }

    #[test]
    fn test_should_update_country() {
        let setup = setup();
        IAgentRoleDispatcher { contract_address: setup.identity_registry.contract_address }
            .add_agent(starknet::get_contract_address());

        let investor_address = starknet::contract_address_const::<'ALICE'>();
        let investor_identity = starknet::contract_address_const::<'ALICE_ID'>();
        let investor_country = 42;
        let new_country = 30;

        setup
            .identity_registry
            .register_identity(investor_address, investor_identity, investor_country);

        let mut spy = spy_events();
        setup.identity_registry.update_country(investor_address, new_country);

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
    use registry::{
        identity_registry::IdentityRegistry,
        interface::iidentity_registry::IIdentityRegistryDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_the_owner() {
        let setup = setup();
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
        let setup = setup();
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
    use registry::{
        identity_registry::IdentityRegistry,
        interface::iidentity_registry::IIdentityRegistryDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_the_owner() {
        let setup = setup();
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
        let setup = setup();
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
    use registry::{
        identity_registry::IdentityRegistry,
        interface::iidentity_registry::IIdentityRegistryDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_the_owner() {
        let setup = setup();
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
        let setup = setup();
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
    use onchain_id_starknet::storage::structs::Signature;
    use registry::interface::{
        iclaim_topics_registry::IClaimTopicsRegistryDispatcherTrait,
        iidentity_registry::IIdentityRegistryDispatcherTrait,
        itrusted_issuers_registry::ITrustedIssuersRegistryDispatcherTrait,
    };
    use roles::agent_role::{IAgentRoleDispatcher, IAgentRoleDispatcherTrait};
    use snforge_std::mock_call;
    use super::setup;

    #[test]
    fn test_should_return_true_when_the_identity_is_registered_when_there_are_no_required_claim_topics() {
        let setup = setup();

        let investor_address = starknet::contract_address_const::<'ALICE'>();
        let investor_identity = starknet::contract_address_const::<'ALICE_ID'>();
        let investor_country = 42;

        IAgentRoleDispatcher { contract_address: setup.identity_registry.contract_address }
            .add_agent(starknet::get_contract_address());

        setup
            .identity_registry
            .register_identity(investor_address, investor_identity, investor_country);

        let verification_result = setup.identity_registry.is_verified(investor_address);
        assert(verification_result, 'Should have returned true');
    }

    #[test]
    fn test_should_return_false_when_claim_topics_are_required_but_there_are_no_trusted_issuers_for_them() {
        let setup = setup();

        let investor_address = starknet::contract_address_const::<'ALICE'>();
        let investor_identity = starknet::contract_address_const::<'ALICE_ID'>();
        let investor_country = 42;

        IAgentRoleDispatcher { contract_address: setup.identity_registry.contract_address }
            .add_agent(starknet::get_contract_address());

        setup
            .identity_registry
            .register_identity(investor_address, investor_identity, investor_country);

        setup.claim_topics_registry.add_claim_topic('CLAIM_TOPIC');

        let verification_result = setup.identity_registry.is_verified(investor_address);
        assert(!verification_result, 'Should have returned false');
    }

    #[test]
    fn test_should_return_false_when_the_there_is_no_valid_claim() {
        let setup = setup();

        let investor_address = starknet::contract_address_const::<'ALICE'>();
        let investor_identity = starknet::contract_address_const::<'ALICE_ID'>();
        let investor_country = 42;
        let trusted_issuer = starknet::contract_address_const::<'TRUSTED_ISSUER'>();
        let claim_topic = 'CLAIM_TOPIC';
        IAgentRoleDispatcher { contract_address: setup.identity_registry.contract_address }
            .add_agent(starknet::get_contract_address());

        setup
            .identity_registry
            .register_identity(investor_address, investor_identity, investor_country);

        setup.claim_topics_registry.add_claim_topic(claim_topic);
        setup.trusted_issuers_registry.add_trusted_issuer(trusted_issuer, [claim_topic].span());
        let empty_bytearray: ByteArray = "";
        mock_call(
            investor_identity,
            selector!("get_claim"),
            (
                claim_topic,
                0,
                trusted_issuer,
                Signature::StarkSignature(Default::default()),
                empty_bytearray.clone(),
                empty_bytearray,
            ),
            1,
        );
        mock_call(trusted_issuer, selector!("is_claim_valid"), false, 1);

        let verification_result = setup.identity_registry.is_verified(investor_address);
        assert(!verification_result, 'Should have returned false');
    }

    #[test]
    fn test_should_return_true_when_the_there_is_valid_claim() {
        let setup = setup();

        let investor_address = starknet::contract_address_const::<'ALICE'>();
        let investor_identity = starknet::contract_address_const::<'ALICE_ID'>();
        let investor_country = 42;
        let trusted_issuer = starknet::contract_address_const::<'TRUSTED_ISSUER'>();
        let claim_topic = 'CLAIM_TOPIC';

        IAgentRoleDispatcher { contract_address: setup.identity_registry.contract_address }
            .add_agent(starknet::get_contract_address());

        setup
            .identity_registry
            .register_identity(investor_address, investor_identity, investor_country);

        setup.claim_topics_registry.add_claim_topic(claim_topic);
        setup.trusted_issuers_registry.add_trusted_issuer(trusted_issuer, [claim_topic].span());
        let empty_bytearray: ByteArray = "";
        mock_call(
            investor_identity,
            selector!("get_claim"),
            (
                claim_topic,
                0,
                trusted_issuer,
                Signature::StarkSignature(Default::default()),
                empty_bytearray.clone(),
                empty_bytearray,
            ),
            1,
        );
        mock_call(trusted_issuer, selector!("is_claim_valid"), true, 1);

        let verification_result = setup.identity_registry.is_verified(investor_address);
        assert(verification_result, 'Should have returned true');
    }
    //#[test]
//fn
//test_should_return_true_if_there_is_another_valid_claim_when_the_claim_issuer_throws_an_error()
//{
//    assert(true, '');
//}
//
//#[test]
//fn
//test_should_return_false_if_there_are_no_other_valid_claim_when_the_claim_issuer_throws_an_error()
//{
//    assert(true, '');
//}
}
