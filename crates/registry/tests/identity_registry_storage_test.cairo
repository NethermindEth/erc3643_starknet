use registry::interface::iidentity_registry_storage::IIdentityRegistryStorageDispatcher;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;

#[derive(Drop, Copy)]
struct Setup {
    registry_storage: IIdentityRegistryStorageDispatcher,
    alice: ContractAddress,
    alice_id: ContractAddress,
}

fn setup() -> Setup {
    let identity_registry_storage_contract = declare("IdentityRegistryStorage")
        .unwrap()
        .contract_class();
    let (deployed_address, _) = identity_registry_storage_contract
        .deploy(
            @array![
                starknet::contract_address_const::<'IMPLEMENTATION_AUTHORITY'>().into(),
                starknet::get_contract_address().into(),
            ],
        )
        .unwrap();

    Setup {
        registry_storage: IIdentityRegistryStorageDispatcher { contract_address: deployed_address },
        alice: starknet::contract_address_const::<'ALICE'>(),
        alice_id: starknet::contract_address_const::<'ALICE_ID'>(),
    }
}

pub mod add_identity_to_storage {
    use core::num::traits::Zero;
    use registry::{
        identity_registry_storage::IdentityRegistryStorage,
        interface::iidentity_registry_storage::IIdentityRegistryStorageDispatcherTrait,
    };
    use roles::agent_role::{IAgentRoleDispatcher, IAgentRoleDispatcherTrait};
    use snforge_std::{EventSpyAssertionsTrait, spy_events};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_panic_when_sender_is_not_agent() {
        let setup = setup();

        setup.registry_storage.add_identity_to_storage(setup.alice, setup.alice_id, 42);
    }

    #[test]
    #[should_panic(expected: 'Zero Address')]
    fn test_should_panic_when_sender_is_agent_and_identity_is_zero_address() {
        let setup = setup();

        IAgentRoleDispatcher { contract_address: setup.registry_storage.contract_address }
            .add_agent(starknet::get_contract_address());
        setup.registry_storage.add_identity_to_storage(setup.alice, Zero::zero(), 42);
    }

    #[test]
    #[should_panic(expected: 'Zero Address')]
    fn test_should_panic_when_sender_is_agent_and_wallet_is_zero_address() {
        let setup = setup();

        IAgentRoleDispatcher { contract_address: setup.registry_storage.contract_address }
            .add_agent(starknet::get_contract_address());
        setup.registry_storage.add_identity_to_storage(Zero::zero(), setup.alice_id, 42);
    }

    #[test]
    fn test_should_add_identity_to_storage() {
        let setup = setup();

        IAgentRoleDispatcher { contract_address: setup.registry_storage.contract_address }
            .add_agent(starknet::get_contract_address());
        let country_code = 42;

        let mut spy = spy_events();
        setup.registry_storage.add_identity_to_storage(setup.alice, setup.alice_id, country_code);

        assert(
            setup.registry_storage.stored_identity(setup.alice) == setup.alice_id,
            'Identity not stored',
        );
        assert(
            setup.registry_storage.stored_investor_country(setup.alice) == country_code,
            'Identity not stored',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        setup.registry_storage.contract_address,
                        IdentityRegistryStorage::Event::IdentityStored(
                            IdentityRegistryStorage::IdentityStored {
                                investor_address: setup.alice, identity: setup.alice_id,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic(expected: 'Identity already stored')]
    fn test_should_panic_when_sender_is_agent_and_wallet_already_registered() {
        let setup = setup();

        IAgentRoleDispatcher { contract_address: setup.registry_storage.contract_address }
            .add_agent(starknet::get_contract_address());
        let country_code = 42;

        setup.registry_storage.add_identity_to_storage(setup.alice, setup.alice_id, country_code);
        /// Adding second time should panic
        setup.registry_storage.add_identity_to_storage(setup.alice, setup.alice_id, country_code);
    }
}

pub mod remove_identity_from_storage {
    use core::num::traits::Zero;
    use registry::{
        identity_registry_storage::IdentityRegistryStorage,
        interface::iidentity_registry_storage::IIdentityRegistryStorageDispatcherTrait,
    };
    use roles::agent_role::{IAgentRoleDispatcher, IAgentRoleDispatcherTrait};
    use snforge_std::{EventSpyAssertionsTrait, spy_events};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_panic_when_sender_is_not_agent() {
        let setup = setup();

        setup.registry_storage.remove_identity_from_storage(setup.alice);
    }

    #[test]
    #[should_panic(expected: 'Zero Address')]
    fn test_should_panic_when_sender_is_agent_and_wallet_is_zero_address() {
        let setup = setup();

        IAgentRoleDispatcher { contract_address: setup.registry_storage.contract_address }
            .add_agent(starknet::get_contract_address());
        setup.registry_storage.remove_identity_from_storage(Zero::zero());
    }

    #[test]
    #[should_panic(expected: 'Identity not stored')]
    fn test_should_panic_when_sender_is_agent_and_wallet_is_not_registered() {
        let setup = setup();

        IAgentRoleDispatcher { contract_address: setup.registry_storage.contract_address }
            .add_agent(starknet::get_contract_address());
        setup.registry_storage.remove_identity_from_storage(setup.alice);
    }

    #[test]
    fn test_should_remove_identity_from_storage() {
        let setup = setup();

        IAgentRoleDispatcher { contract_address: setup.registry_storage.contract_address }
            .add_agent(starknet::get_contract_address());
        setup.registry_storage.add_identity_to_storage(setup.alice, setup.alice_id, 42);

        let mut spy = spy_events();
        setup.registry_storage.remove_identity_from_storage(setup.alice);
        assert(
            setup.registry_storage.stored_identity(setup.alice) == Zero::zero(),
            'Identity not stored',
        );
        assert(
            setup.registry_storage.stored_investor_country(setup.alice) == Zero::zero(),
            'Identity not stored',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        setup.registry_storage.contract_address,
                        IdentityRegistryStorage::Event::IdentityUnstored(
                            IdentityRegistryStorage::IdentityUnstored {
                                investor_address: setup.alice, identity: setup.alice_id,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod modify_stored_identity {
    use core::num::traits::Zero;
    use registry::{
        identity_registry_storage::IdentityRegistryStorage,
        interface::iidentity_registry_storage::IIdentityRegistryStorageDispatcherTrait,
    };
    use roles::agent_role::{IAgentRoleDispatcher, IAgentRoleDispatcherTrait};
    use snforge_std::{EventSpyAssertionsTrait, spy_events};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_panic_when_sender_is_not_agent() {
        let setup = setup();

        setup.registry_storage.modify_stored_identity(setup.alice, setup.alice_id);
    }

    #[test]
    #[should_panic(expected: 'Zero Address')]
    fn test_should_panic_when_sender_is_agent_and_identity_is_zero_address() {
        let setup = setup();

        IAgentRoleDispatcher { contract_address: setup.registry_storage.contract_address }
            .add_agent(starknet::get_contract_address());
        setup.registry_storage.modify_stored_identity(setup.alice, Zero::zero());
    }

    #[test]
    #[should_panic(expected: 'Zero Address')]
    fn test_should_panic_when_sender_is_agent_and_wallet_is_zero_address() {
        let setup = setup();

        IAgentRoleDispatcher { contract_address: setup.registry_storage.contract_address }
            .add_agent(starknet::get_contract_address());
        setup.registry_storage.modify_stored_identity(Zero::zero(), setup.alice_id);
    }

    #[test]
    #[should_panic(expected: 'Identity not stored')]
    fn test_should_panic_when_sender_is_agent_and_wallet_is_not_registered() {
        let setup = setup();

        IAgentRoleDispatcher { contract_address: setup.registry_storage.contract_address }
            .add_agent(starknet::get_contract_address());
        setup.registry_storage.modify_stored_identity(setup.alice, setup.alice_id);
    }

    #[test]
    fn test_should_modify_stored_identity() {
        let setup = setup();

        IAgentRoleDispatcher { contract_address: setup.registry_storage.contract_address }
            .add_agent(starknet::get_contract_address());
        setup.registry_storage.add_identity_to_storage(setup.alice, setup.alice_id, 42);

        let new_identity = starknet::contract_address_const::<'NEW_ALICE_ID'>();
        let mut spy = spy_events();
        setup.registry_storage.modify_stored_identity(setup.alice, new_identity);

        assert(
            setup.registry_storage.stored_identity(setup.alice) == new_identity,
            'Identity not updated',
        );
        spy
            .assert_emitted(
                @array![
                    (
                        setup.registry_storage.contract_address,
                        IdentityRegistryStorage::Event::IdentityModified(
                            IdentityRegistryStorage::IdentityModified {
                                old_identity: setup.alice_id, new_identity,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod modify_stored_investor_country {
    use core::num::traits::Zero;
    use registry::{
        identity_registry_storage::IdentityRegistryStorage,
        interface::iidentity_registry_storage::IIdentityRegistryStorageDispatcherTrait,
    };
    use roles::agent_role::{IAgentRoleDispatcher, IAgentRoleDispatcherTrait};
    use snforge_std::{EventSpyAssertionsTrait, spy_events};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_panic_when_sender_is_not_agent() {
        let setup = setup();

        setup.registry_storage.modify_stored_investor_country(setup.alice, 30);
    }

    #[test]
    #[should_panic(expected: 'Zero Address')]
    fn test_should_panic_when_sender_is_agent_and_wallet_is_zero_address() {
        let setup = setup();

        IAgentRoleDispatcher { contract_address: setup.registry_storage.contract_address }
            .add_agent(starknet::get_contract_address());
        setup.registry_storage.modify_stored_investor_country(Zero::zero(), 30);
    }

    #[test]
    #[should_panic(expected: 'Identity not stored')]
    fn test_should_panic_when_sender_is_agent_and_wallet_is_not_registered() {
        let setup = setup();

        IAgentRoleDispatcher { contract_address: setup.registry_storage.contract_address }
            .add_agent(starknet::get_contract_address());
        setup.registry_storage.modify_stored_investor_country(setup.alice, 30);
    }

    #[test]
    fn test_should_modify_stored_investor_country() {
        let setup = setup();

        IAgentRoleDispatcher { contract_address: setup.registry_storage.contract_address }
            .add_agent(starknet::get_contract_address());
        setup.registry_storage.add_identity_to_storage(setup.alice, setup.alice_id, 42);

        let new_country = 30;
        let mut spy = spy_events();
        setup.registry_storage.modify_stored_investor_country(setup.alice, new_country);

        assert(
            setup.registry_storage.stored_investor_country(setup.alice) == new_country,
            'Country not updated',
        );
        spy
            .assert_emitted(
                @array![
                    (
                        setup.registry_storage.contract_address,
                        IdentityRegistryStorage::Event::CountryModified(
                            IdentityRegistryStorage::CountryModified {
                                investor_address: setup.alice, country: new_country,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod bind_identity_registry {
    use core::num::traits::Zero;
    use registry::{
        identity_registry_storage::IdentityRegistryStorage,
        interface::iidentity_registry_storage::IIdentityRegistryStorageDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_sender_is_not_owner() {
        let setup = setup();
        let identity_registry = starknet::contract_address_const::<'IDENTITY_REGISTRY'>();
        start_cheat_caller_address(
            setup.registry_storage.contract_address,
            starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        setup.registry_storage.bind_identity_registry(identity_registry);
        stop_cheat_caller_address(setup.registry_storage.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Zero Address')]
    fn test_should_panic_when_identity_registry_is_zero_address() {
        let setup = setup();

        setup.registry_storage.bind_identity_registry(Zero::zero());
    }

    #[test]
    fn test_should_bind_identity_registry() {
        let setup = setup();
        let identity_registry = starknet::contract_address_const::<'IDENTITY_REGISTRY'>();

        let mut spy = spy_events();
        setup.registry_storage.bind_identity_registry(identity_registry);

        assert!(
            setup.registry_storage.linked_identity_registries() == [identity_registry].span(),
            "Identity registries does not match",
        );

        spy
            .assert_emitted(
                @array![
                    (
                        setup.registry_storage.contract_address,
                        IdentityRegistryStorage::Event::IdentityRegistryBound(
                            IdentityRegistryStorage::IdentityRegistryBound { identity_registry },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic(expected: 'Registry already binded')]
    fn test_should_panic_when_identity_registry_already_bound() {
        let setup = setup();
        let identity_registry = starknet::contract_address_const::<'IDENTITY_REGISTRY'>();

        setup.registry_storage.bind_identity_registry(identity_registry);
        /// Binding same registry twice should panic
        setup.registry_storage.bind_identity_registry(identity_registry);
    }

    #[test]
    #[should_panic(expected: 'Cannot bind more than 300 IR')]
    fn test_should_panic_when_already_300_identity_registries_bound() {
        let setup = setup();

        for i in 100..400_u16 {
            setup
                .registry_storage
                .bind_identity_registry(Into::<u16, felt252>::into(i).try_into().unwrap());
        };

        setup.registry_storage.bind_identity_registry('EXCESS_REGISTRY'.try_into().unwrap());
    }
}

pub mod unbind_identity_registry {
    use core::num::traits::Zero;
    use registry::{
        identity_registry_storage::IdentityRegistryStorage,
        interface::iidentity_registry_storage::IIdentityRegistryStorageDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_sender_is_not_owner() {
        let setup = setup();
        let identity_registry = starknet::contract_address_const::<'IDENTITY_REGISTRY'>();
        start_cheat_caller_address(
            setup.registry_storage.contract_address,
            starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        setup.registry_storage.unbind_identity_registry(identity_registry);
        stop_cheat_caller_address(setup.registry_storage.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Zero Address')]
    fn test_should_panic_when_sender_is_owner_and_identity_registry_is_zero_address() {
        let setup = setup();

        setup.registry_storage.unbind_identity_registry(Zero::zero());
    }

    #[test]
    #[should_panic(expected: 'Registry not bound')]
    fn test_should_panic_when_sender_is_owner_and_identity_registry_not_bound() {
        let setup = setup();

        let identity_registry = starknet::contract_address_const::<'IDENTITY_REGISTRY'>();
        setup.registry_storage.unbind_identity_registry(identity_registry);
    }

    #[test]
    fn test_should_unbind_identity_registry_when_sender_is_owner_and_identity_registry_is_bound() {
        let setup = setup();

        let identity_registry = starknet::contract_address_const::<'IDENTITY_REGISTRY'>();
        setup.registry_storage.bind_identity_registry(identity_registry);

        let mut spy = spy_events();
        setup.registry_storage.unbind_identity_registry(identity_registry);

        assert!(
            setup.registry_storage.linked_identity_registries() == [].span(),
            "Identity registries does not match",
        );

        spy
            .assert_emitted(
                @array![
                    (
                        setup.registry_storage.contract_address,
                        IdentityRegistryStorage::Event::IdentityRegistryUnbound(
                            IdentityRegistryStorage::IdentityRegistryUnbound { identity_registry },
                        ),
                    ),
                ],
            );
    }
}
