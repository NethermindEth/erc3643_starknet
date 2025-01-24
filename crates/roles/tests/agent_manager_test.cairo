pub mod call_force_transfer {
    use factory::tests_common::setup_full_suite;
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use openzeppelin_token::erc20::ERC20Component;
    use roles::{AgentRoles, agent::iagent_manager::IAgentManagerDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };

    #[test]
    #[should_panic(expected: 'OID is not transfer manager')]
    fn test_should_revert_when_specified_identity_missing_transfer_manager_role() {
        let setup = setup_full_suite();

        setup
            .agent_manager
            .call_forced_transfer(
                setup.accounts.alice.account.contract_address,
                setup.accounts.bob.account.contract_address,
                200,
                setup.onchain_id.alice_identity.contract_address,
            );
    }

    #[test]
    #[should_panic(expected: 'Caller is not management key')]
    fn test_should_revert_when_specified_identity_has_transfer_manager_role_but_sender_not_authorized() {
        let setup = setup_full_suite();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::TRANSFER_MANAGER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_MANAGER'>(),
        );
        setup
            .agent_manager
            .call_forced_transfer(
                setup.accounts.alice.account.contract_address,
                setup.accounts.bob.account.contract_address,
                200,
                alice_identity,
            );
        stop_cheat_caller_address(setup.agent_manager.contract_address);
    }

    #[test]
    fn test_should_perform_the_transfer_when_identity_has_role_and_sender_authorized() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let bob_wallet = setup.accounts.bob.account.contract_address;
        let amount = 200;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::TRANSFER_MANAGER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(setup.agent_manager.contract_address, alice_wallet);
        setup.agent_manager.call_forced_transfer(alice_wallet, bob_wallet, amount, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: alice_wallet, to: bob_wallet, value: amount,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_batch_force_transfer {
    use factory::tests_common::setup_full_suite;
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use openzeppelin_token::erc20::ERC20Component;
    use roles::{AgentRoles, agent::iagent_manager::IAgentManagerDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };

    #[test]
    #[should_panic(expected: 'OID is not transfer manager')]
    fn test_should_revert_when_specified_identity_missing_transfer_manager_role() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let bob_wallet = setup.accounts.bob.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        setup
            .agent_manager
            .call_batch_forced_transfer(
                [alice_wallet, bob_wallet].span(),
                [bob_wallet, alice_wallet].span(),
                [200, 200].span(),
                alice_identity,
            );
    }

    #[test]
    #[should_panic(expected: 'Caller is not management key')]
    fn test_should_revert_when_specified_identity_has_transfer_manager_role_but_sender_not_authorized() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let bob_wallet = setup.accounts.bob.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::TRANSFER_MANAGER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_MANAGER'>(),
        );
        setup
            .agent_manager
            .call_batch_forced_transfer(
                [alice_wallet, bob_wallet].span(),
                [bob_wallet, alice_wallet].span(),
                [200, 200].span(),
                alice_identity,
            );
        stop_cheat_caller_address(setup.agent_manager.contract_address);
    }

    #[test]
    fn test_should_perform_the_transfer_when_identity_has_role_and_sender_authorized() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let bob_wallet = setup.accounts.bob.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::TRANSFER_MANAGER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(setup.agent_manager.contract_address, alice_wallet);
        setup
            .agent_manager
            .call_batch_forced_transfer(
                [alice_wallet, bob_wallet].span(),
                [bob_wallet, alice_wallet].span(),
                [200, 200].span(),
                alice_identity,
            );
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: alice_wallet, to: bob_wallet, value: 200,
                            },
                        ),
                    ),
                    (
                        setup.token.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: bob_wallet, to: alice_wallet, value: 200,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_pause {
    use factory::tests_common::setup_full_suite;
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use openzeppelin_security::{
        interface::{IPausableDispatcher, IPausableDispatcherTrait}, pausable::PausableComponent,
    };
    use roles::{AgentRoles, agent::iagent_manager::IAgentManagerDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    #[test]
    #[should_panic(expected: 'OID is not freezer')]
    fn test_should_revert_when_specified_identity_missing_freezer_role() {
        let setup = setup_full_suite();

        setup.agent_manager.call_pause(setup.onchain_id.alice_identity.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Caller is not management key')]
    fn test_should_revert_when_specified_identity_has_freezer_role_but_sender_not_authorized() {
        let setup = setup_full_suite();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::FREEZER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_MANAGER'>(),
        );
        setup.agent_manager.call_pause(alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);
    }

    #[test]
    fn test_should_perform_the_pause_when_identity_has_role_and_sender_authorized() {
        let setup = setup_full_suite();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::FREEZER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(
            setup.agent_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        setup.agent_manager.call_pause(alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        assert(
            IPausableDispatcher { contract_address: setup.token.contract_address }.is_paused(),
            'Token is not paused',
        );
        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        PausableComponent::Event::Paused(
                            PausableComponent::Paused {
                                account: setup.agent_manager.contract_address,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_unpause {
    use factory::tests_common::setup_full_suite;
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use openzeppelin_security::{
        interface::{IPausableDispatcher, IPausableDispatcherTrait}, pausable::PausableComponent,
    };
    use roles::{AgentRoles, agent::iagent_manager::IAgentManagerDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    #[test]
    #[should_panic(expected: 'OID is not freezer')]
    fn test_should_revert_when_specified_identity_missing_freezer_role() {
        let setup = setup_full_suite();

        setup.agent_manager.call_unpause(setup.onchain_id.alice_identity.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Caller is not management key')]
    fn test_should_revert_when_specified_identity_has_freezer_role_but_sender_not_authorized() {
        let setup = setup_full_suite();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::FREEZER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_MANAGER'>(),
        );
        setup.agent_manager.call_unpause(alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);
    }

    #[test]
    fn test_should_perform_the_unpause_when_identity_has_role_and_sender_authorized() {
        let setup = setup_full_suite();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::FREEZER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        start_cheat_caller_address(
            setup.agent_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        setup.agent_manager.call_pause(alice_identity);

        let mut spy = spy_events();
        setup.agent_manager.call_unpause(alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        assert(
            !IPausableDispatcher { contract_address: setup.token.contract_address }.is_paused(),
            'Token is not unpaused',
        );
        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        PausableComponent::Event::Unpaused(
                            PausableComponent::Unpaused {
                                account: setup.agent_manager.contract_address,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_mint {
    use core::num::traits::Zero;
    use factory::tests_common::setup_full_suite;
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use openzeppelin_token::erc20::ERC20Component;
    use roles::{AgentRoles, agent::iagent_manager::IAgentManagerDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };

    #[test]
    #[should_panic(expected: 'OID is not supply modifier')]
    fn test_should_revert_when_specified_identity_missing_supply_modifier_role() {
        let setup = setup_full_suite();

        setup
            .agent_manager
            .call_mint(
                setup.accounts.bob.account.contract_address,
                1_000,
                setup.onchain_id.alice_identity.contract_address,
            );
    }

    #[test]
    #[should_panic(expected: 'Caller is not management key')]
    fn test_should_revert_when_specified_identity_has_supply_modifier_role_but_sender_not_authorized() {
        let setup = setup_full_suite();
        let recipient = setup.accounts.bob.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::SUPPLY_MODIFIER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_MANAGER'>(),
        );
        setup.agent_manager.call_mint(recipient, 1_000, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);
    }

    #[test]
    fn test_should_perform_the_mint_when_identity_has_role_and_sender_authorized() {
        let setup = setup_full_suite();
        let recipient = setup.accounts.bob.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;
        let amount = 1_000;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::SUPPLY_MODIFIER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(
            setup.agent_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        setup.agent_manager.call_mint(recipient, amount, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: Zero::zero(), to: recipient, value: amount,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_batch_mint {
    use core::num::traits::Zero;
    use factory::tests_common::setup_full_suite;
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use openzeppelin_token::erc20::ERC20Component;
    use roles::{AgentRoles, agent::iagent_manager::IAgentManagerDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };

    #[test]
    #[should_panic(expected: 'OID is not supply modifier')]
    fn test_should_revert_when_specified_identity_missing_supply_modifier_role() {
        let setup = setup_full_suite();

        setup
            .agent_manager
            .call_batch_mint(
                [
                    setup.accounts.bob.account.contract_address,
                    setup.accounts.alice.account.contract_address,
                ]
                    .span(),
                [1_000, 500].span(),
                setup.onchain_id.alice_identity.contract_address,
            );
    }

    #[test]
    #[should_panic(expected: 'Caller is not management key')]
    fn test_should_revert_when_specified_identity_has_supply_modifier_role_but_sender_not_authorized() {
        let setup = setup_full_suite();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::SUPPLY_MODIFIER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_MANAGER'>(),
        );
        setup
            .agent_manager
            .call_batch_mint(
                [
                    setup.accounts.bob.account.contract_address,
                    setup.accounts.alice.account.contract_address,
                ]
                    .span(),
                [1_000, 500].span(),
                alice_identity,
            );
        stop_cheat_caller_address(setup.agent_manager.contract_address);
    }

    #[test]
    fn test_should_perform_the_batch_mint_when_identity_has_role_and_sender_authorized() {
        let setup = setup_full_suite();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::SUPPLY_MODIFIER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(
            setup.agent_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        setup
            .agent_manager
            .call_batch_mint(
                [
                    setup.accounts.bob.account.contract_address,
                    setup.accounts.alice.account.contract_address,
                ]
                    .span(),
                [1_000, 500].span(),
                alice_identity,
            );
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: Zero::zero(),
                                to: setup.accounts.bob.account.contract_address,
                                value: 1_000,
                            },
                        ),
                    ),
                    (
                        setup.token.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: Zero::zero(),
                                to: setup.accounts.alice.account.contract_address,
                                value: 500,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_burn {
    use core::num::traits::Zero;
    use factory::tests_common::setup_full_suite;
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use openzeppelin_token::erc20::ERC20Component;
    use roles::{AgentRoles, agent::iagent_manager::IAgentManagerDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };

    #[test]
    #[should_panic(expected: 'OID is not supply modifier')]
    fn test_should_revert_when_specified_identity_missing_supply_modifier_role() {
        let setup = setup_full_suite();

        setup
            .agent_manager
            .call_burn(
                setup.accounts.bob.account.contract_address,
                1_000,
                setup.onchain_id.alice_identity.contract_address,
            );
    }

    #[test]
    #[should_panic(expected: 'Caller is not management key')]
    fn test_should_revert_when_specified_identity_has_supply_modifier_role_but_sender_not_authorized() {
        let setup = setup_full_suite();
        let bob_identity = setup.onchain_id.bob_identity.contract_address;
        let burner = setup.accounts.bob.account.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::SUPPLY_MODIFIER, bob_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            starknet::contract_address_const::<'NOT_BOB_ID_MANAGER'>(),
        );
        setup.agent_manager.call_burn(burner, 200, bob_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);
    }

    #[test]
    fn test_should_perform_the_burn_when_identity_has_role_and_sender_authorized() {
        let setup = setup_full_suite();
        let bob_identity = setup.onchain_id.bob_identity.contract_address;
        let burner = setup.accounts.bob.account.contract_address;
        let amount = 200;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::SUPPLY_MODIFIER, bob_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(setup.agent_manager.contract_address, burner);
        setup.agent_manager.call_burn(burner, amount, bob_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: burner, to: Zero::zero(), value: amount,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_batch_burn {
    use core::num::traits::Zero;
    use factory::tests_common::setup_full_suite;
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use openzeppelin_token::erc20::ERC20Component;
    use roles::{AgentRoles, agent::iagent_manager::IAgentManagerDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };

    #[test]
    #[should_panic(expected: 'OID is not supply modifier')]
    fn test_should_revert_when_specified_identity_missing_supply_modifier_role() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let bob_wallet = setup.accounts.bob.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        setup
            .agent_manager
            .call_batch_burn(
                [bob_wallet, alice_wallet].span(), [500, 1_000].span(), alice_identity,
            );
    }

    #[test]
    #[should_panic(expected: 'Caller is not management key')]
    fn test_should_revert_when_specified_identity_has_supply_modifier_role_but_sender_not_authorized() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let bob_wallet = setup.accounts.bob.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::SUPPLY_MODIFIER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_MANAGER'>(),
        );
        setup
            .agent_manager
            .call_batch_burn(
                [bob_wallet, alice_wallet].span(), [500, 1_000].span(), alice_identity,
            );
        stop_cheat_caller_address(setup.agent_manager.contract_address);
    }

    #[test]
    fn test_should_perform_the_batch_burn_when_identity_has_role_and_sender_authorized() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let bob_wallet = setup.accounts.bob.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::SUPPLY_MODIFIER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(setup.agent_manager.contract_address, alice_wallet);
        setup
            .agent_manager
            .call_batch_burn(
                [bob_wallet, alice_wallet].span(), [500, 1_000].span(), alice_identity,
            );
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: bob_wallet, to: Zero::zero(), value: 500,
                            },
                        ),
                    ),
                    (
                        setup.token.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: alice_wallet, to: Zero::zero(), value: 1_000,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_set_address_frozen {
    use factory::tests_common::setup_full_suite;
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use roles::{AgentRoles, agent::iagent_manager::IAgentManagerDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use token::{itoken::ITokenDispatcherTrait, token::Token};

    #[test]
    #[should_panic(expected: 'OID is not freezer')]
    fn test_should_revert_when_specified_identity_missing_freezer_role() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        setup.agent_manager.call_set_address_frozen(alice_wallet, true, alice_identity);
    }

    #[test]
    #[should_panic(expected: 'Caller is not management key')]
    fn test_should_revert_when_specified_identity_has_freezer_role_but_sender_not_authorized() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::FREEZER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_MANAGER'>(),
        );
        setup.agent_manager.call_set_address_frozen(alice_wallet, true, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);
    }

    #[test]
    fn test_should_perform_the_freeze_when_identity_has_role_and_sender_authorized() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::FREEZER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(setup.agent_manager.contract_address, alice_wallet);
        setup.agent_manager.call_set_address_frozen(alice_wallet, true, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        assert(setup.token.is_frozen(alice_wallet), 'Address not frozen');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        Token::Event::AddressFrozen(
                            Token::AddressFrozen {
                                user_address: alice_wallet,
                                is_frozen: true,
                                owner: setup.agent_manager.contract_address,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_batch_set_address_frozen {
    use factory::tests_common::setup_full_suite;
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use roles::{AgentRoles, agent::iagent_manager::IAgentManagerDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use token::{itoken::ITokenDispatcherTrait, token::Token};

    #[test]
    #[should_panic(expected: 'OID is not freezer')]
    fn test_should_revert_when_specified_identity_missing_freezer_role() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let bob_wallet = setup.accounts.bob.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        setup
            .agent_manager
            .call_batch_set_address_frozen(
                [alice_wallet, bob_wallet].span(), [true, false].span(), alice_identity,
            );
    }

    #[test]
    #[should_panic(expected: 'Caller is not management key')]
    fn test_should_revert_when_specified_identity_has_freezer_role_but_sender_not_authorized() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let bob_wallet = setup.accounts.bob.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::FREEZER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_MANAGER'>(),
        );
        setup
            .agent_manager
            .call_batch_set_address_frozen(
                [alice_wallet, bob_wallet].span(), [true, false].span(), alice_identity,
            );
        stop_cheat_caller_address(setup.agent_manager.contract_address);
    }

    #[test]
    fn test_should_perform_the_batch_pause_when_identity_has_role_and_sender_authorized() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let bob_wallet = setup.accounts.bob.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::FREEZER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(setup.agent_manager.contract_address, alice_wallet);
        setup
            .agent_manager
            .call_batch_set_address_frozen(
                [alice_wallet, bob_wallet].span(), [true, false].span(), alice_identity,
            );
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        assert(setup.token.is_frozen(alice_wallet), 'Address not frozen');
        assert(!setup.token.is_frozen(bob_wallet), 'Address is frozen');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        Token::Event::AddressFrozen(
                            Token::AddressFrozen {
                                user_address: alice_wallet,
                                is_frozen: true,
                                owner: setup.agent_manager.contract_address,
                            },
                        ),
                    ),
                    (
                        setup.token.contract_address,
                        Token::Event::AddressFrozen(
                            Token::AddressFrozen {
                                user_address: bob_wallet,
                                is_frozen: false,
                                owner: setup.agent_manager.contract_address,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_freeze_partial_tokens {
    use factory::tests_common::setup_full_suite;
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use roles::{AgentRoles, agent::iagent_manager::IAgentManagerDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use token::{itoken::ITokenDispatcherTrait, token::Token};

    #[test]
    #[should_panic(expected: 'OID is not freezer')]
    fn test_should_revert_when_specified_identity_missing_freezer_role() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        setup.agent_manager.call_freeze_partial_tokens(alice_wallet, 100, alice_identity);
    }

    #[test]
    #[should_panic(expected: 'Caller is not management key')]
    fn test_should_revert_when_specified_identity_has_freezer_role_but_sender_not_authorized() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::FREEZER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_MANAGER'>(),
        );
        setup.agent_manager.call_freeze_partial_tokens(alice_wallet, 100, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);
    }

    #[test]
    fn test_should_perform_freeze_of_partial_tokens_when_identity_has_role_and_sender_authorized() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;
        let amount = 100;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::FREEZER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(setup.agent_manager.contract_address, alice_wallet);
        setup.agent_manager.call_freeze_partial_tokens(alice_wallet, amount, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        assert(setup.token.get_frozen_tokens(alice_wallet) == amount, 'Tokens not frozen');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        Token::Event::TokensFrozen(
                            Token::TokensFrozen { user_address: alice_wallet, amount },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_batch_freeze_partial_tokens {
    use factory::tests_common::setup_full_suite;
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use roles::{AgentRoles, agent::iagent_manager::IAgentManagerDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use token::{itoken::ITokenDispatcherTrait, token::Token};

    #[test]
    #[should_panic(expected: 'OID is not freezer')]
    fn test_should_revert_when_specified_identity_missing_freezer_role() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let bob_wallet = setup.accounts.bob.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        setup
            .agent_manager
            .call_batch_freeze_partial_tokens(
                [alice_wallet, bob_wallet].span(), [100, 200].span(), alice_identity,
            );
    }

    #[test]
    #[should_panic(expected: 'Caller is not management key')]
    fn test_should_revert_when_specified_identity_has_freezer_role_but_sender_not_authorized() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let bob_wallet = setup.accounts.bob.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::FREEZER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_MANAGER'>(),
        );
        setup
            .agent_manager
            .call_batch_freeze_partial_tokens(
                [alice_wallet, bob_wallet].span(), [100, 200].span(), alice_identity,
            );
        stop_cheat_caller_address(setup.agent_manager.contract_address);
    }

    #[test]
    fn test_should_perform_batch_freeze_of_partial_tokens_when_identity_has_role_and_sender_authorized() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let bob_wallet = setup.accounts.bob.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::FREEZER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(setup.agent_manager.contract_address, alice_wallet);
        setup
            .agent_manager
            .call_batch_freeze_partial_tokens(
                [alice_wallet, bob_wallet].span(), [100, 200].span(), alice_identity,
            );
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        assert(setup.token.get_frozen_tokens(alice_wallet) == 100, 'Tokens not frozen');
        assert(setup.token.get_frozen_tokens(bob_wallet) == 200, 'Tokens not frozen');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        Token::Event::TokensFrozen(
                            Token::TokensFrozen { user_address: alice_wallet, amount: 100 },
                        ),
                    ),
                    (
                        setup.token.contract_address,
                        Token::Event::TokensFrozen(
                            Token::TokensFrozen { user_address: bob_wallet, amount: 200 },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_unfreeze_partial_tokens {
    use factory::tests_common::setup_full_suite;
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use roles::{AgentRoles, agent::iagent_manager::IAgentManagerDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use token::{itoken::ITokenDispatcherTrait, token::Token};

    #[test]
    #[should_panic(expected: 'OID is not freezer')]
    fn test_should_revert_when_specified_identity_missing_freezer_role() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        setup.agent_manager.call_unfreeze_partial_tokens(alice_wallet, 100, alice_identity);
    }

    #[test]
    #[should_panic(expected: 'Caller is not management key')]
    fn test_should_revert_when_specified_identity_has_freezer_role_but_sender_not_authorized() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::FREEZER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_MANAGER'>(),
        );
        setup.agent_manager.call_unfreeze_partial_tokens(alice_wallet, 100, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);
    }

    #[test]
    fn test_should_perform_unfreeze_of_partial_tokens_when_identity_has_role_and_sender_authorized() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;
        let amount = 100;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::FREEZER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        start_cheat_caller_address(setup.agent_manager.contract_address, alice_wallet);
        setup.agent_manager.call_freeze_partial_tokens(alice_wallet, amount, alice_identity);
        let mut spy = spy_events();
        setup.agent_manager.call_unfreeze_partial_tokens(alice_wallet, amount - 1, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        assert(setup.token.get_frozen_tokens(alice_wallet) == 1, 'Tokens not unfrozen');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        Token::Event::TokensUnfrozen(
                            Token::TokensUnfrozen {
                                user_address: alice_wallet, amount: amount - 1,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_batch_unfreeze_partial_tokens {
    use factory::tests_common::setup_full_suite;
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use roles::{AgentRoles, agent::iagent_manager::IAgentManagerDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use token::{itoken::ITokenDispatcherTrait, token::Token};

    #[test]
    #[should_panic(expected: 'OID is not freezer')]
    fn test_should_revert_when_specified_identity_missing_freezer_role() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let bob_wallet = setup.accounts.bob.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        setup
            .agent_manager
            .call_batch_unfreeze_partial_tokens(
                [alice_wallet, bob_wallet].span(), [100, 200].span(), alice_identity,
            );
    }

    #[test]
    #[should_panic(expected: 'Caller is not management key')]
    fn test_should_revert_when_specified_identity_has_freezer_role_but_sender_not_authorized() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let bob_wallet = setup.accounts.bob.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::FREEZER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_MANAGER'>(),
        );
        setup
            .agent_manager
            .call_batch_unfreeze_partial_tokens(
                [alice_wallet, bob_wallet].span(), [100, 200].span(), alice_identity,
            );
        stop_cheat_caller_address(setup.agent_manager.contract_address);
    }

    #[test]
    fn test_should_perform_batch_unfreeze_of_partial_tokens_when_identity_has_role_and_sender_authorized() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let bob_wallet = setup.accounts.bob.account.contract_address;
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::FREEZER, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        start_cheat_caller_address(setup.agent_manager.contract_address, alice_wallet);
        setup
            .agent_manager
            .call_batch_freeze_partial_tokens(
                [alice_wallet, bob_wallet].span(), [100, 200].span(), alice_identity,
            );

        let mut spy = spy_events();
        setup
            .agent_manager
            .call_batch_unfreeze_partial_tokens(
                [alice_wallet, bob_wallet].span(), [100, 200].span(), alice_identity,
            );
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        assert(setup.token.get_frozen_tokens(alice_wallet) == 0, 'Tokens not unfrozen');
        assert(setup.token.get_frozen_tokens(bob_wallet) == 0, 'Tokens not unfrozen');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        Token::Event::TokensUnfrozen(
                            Token::TokensUnfrozen { user_address: alice_wallet, amount: 100 },
                        ),
                    ),
                    (
                        setup.token.contract_address,
                        Token::Event::TokensUnfrozen(
                            Token::TokensUnfrozen { user_address: bob_wallet, amount: 200 },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_recovery_address {
    use core::poseidon::poseidon_hash_span;
    use factory::tests_common::setup_full_suite;
    use onchain_id_starknet::interface::iidentity::IdentityABIDispatcherTrait;
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use roles::{AgentRoles, agent::iagent_manager::IAgentManagerDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use token::token::Token;

    #[test]
    #[should_panic(expected: 'OID is not recovery agent')]
    fn test_should_revert_when_specified_identity_missing_recovery_agent_role() {
        let setup = setup_full_suite();

        setup
            .agent_manager
            .call_recovery_address(
                setup.accounts.bob.account.contract_address,
                starknet::contract_address_const::<'RECOVERY_WALLET'>(),
                setup.onchain_id.bob_identity.contract_address,
                setup.onchain_id.alice_identity.contract_address,
            );
    }

    #[test]
    #[should_panic(expected: 'Caller is not management key')]
    fn test_should_revert_when_specified_identity_has_recovery_agent_role_but_sender_not_authorized() {
        let setup = setup_full_suite();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::RECOVERY_AGENT, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_MANAGER'>(),
        );
        setup
            .agent_manager
            .call_recovery_address(
                setup.accounts.bob.account.contract_address,
                starknet::contract_address_const::<'RECOVERY_WALLET'>(),
                setup.onchain_id.bob_identity.contract_address,
                alice_identity,
            );
        stop_cheat_caller_address(setup.agent_manager.contract_address);
    }

    #[test]
    fn test_should_perform_recovery_of_address_when_identity_has_role_and_sender_authorized() {
        let setup = setup_full_suite();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;
        let bob_wallet = setup.accounts.bob.account.contract_address;
        let bob_identity = setup.onchain_id.bob_identity.contract_address;
        let recovery_wallet = starknet::contract_address_const::<'RECOVERY_WALLET'>();

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(AgentRoles::RECOVERY_AGENT, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        start_cheat_caller_address(bob_identity, bob_wallet);
        setup
            .onchain_id
            .bob_identity
            .add_key(poseidon_hash_span([recovery_wallet.into()].span()), 1, 1);
        stop_cheat_caller_address(bob_identity);

        let mut spy = spy_events();
        start_cheat_caller_address(
            setup.agent_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        setup
            .agent_manager
            .call_recovery_address(bob_wallet, recovery_wallet, bob_identity, alice_identity);
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        Token::Event::RecoverySuccess(
                            Token::RecoverySuccess {
                                lost_wallet: bob_wallet,
                                new_wallet: recovery_wallet,
                                investor_onchain_id: bob_identity,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_register_identity {
    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_missing_whitelist_manager_role() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_has_whitelist_manager_role_but_sender_not_authorized() {
        panic!("");
    }

    #[test]
    fn test_should_perform_registration_of_identity_when_identity_has_role_and_sender_authorized() {
        assert(true, '');
    }
}

pub mod call_update_identity {
    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_missing_whitelist_manager_role() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_has_whitelist_manager_role_but_sender_not_authorized() {
        panic!("");
    }

    #[test]
    fn test_should_perform_update_of_identity_when_identity_has_role_and_sender_authorized() {
        assert(true, '');
    }
}

pub mod call_update_country {
    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_missing_whitelist_manager_role() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_has_whitelist_manager_role_but_sender_not_authorized() {
        panic!("");
    }

    #[test]
    fn test_should_perform_update_of_country_when_identity_has_role_and_sender_authorized() {
        assert(true, '');
    }
}

pub mod call_delete_identity {
    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_missing_whitelist_manager_role() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_has_whitelist_manager_role_but_sender_not_authorized() {
        panic!("");
    }

    #[test]
    fn test_should_perform_deletion_of_identity_when_identity_has_role_and_sender_authorized() {
        assert(true, '');
    }
}
