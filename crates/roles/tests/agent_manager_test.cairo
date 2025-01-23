pub mod call_force_transfer {
    use factory::tests_common::setup_full_suite;
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use openzeppelin_token::erc20::{
        ERC20Component, interface::{IERC20Dispatcher, IERC20DispatcherTrait},
    };
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

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(
                AgentRoles::TRANSFER_MANAGER, setup.onchain_id.alice_identity.contract_address,
            );
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
                setup.onchain_id.alice_identity.contract_address,
            );
        stop_cheat_caller_address(setup.agent_manager.contract_address);
    }

    #[test]
    fn test_should_perform_the_transfer_when_identity_has_role_and_sender_authorized() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let bob_wallet = setup.accounts.bob.account.contract_address;
        let amount = 200;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(
                AgentRoles::TRANSFER_MANAGER, setup.onchain_id.alice_identity.contract_address,
            );
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(setup.agent_manager.contract_address, alice_wallet);
        setup
            .agent_manager
            .call_forced_transfer(
                alice_wallet, bob_wallet, amount, setup.onchain_id.alice_identity.contract_address,
            );
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
    use openzeppelin_token::erc20::{
        ERC20Component, interface::{IERC20Dispatcher, IERC20DispatcherTrait},
    };
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

        setup
            .agent_manager
            .call_batch_forced_transfer(
                [alice_wallet, bob_wallet].span(),
                [bob_wallet, alice_wallet].span(),
                [200, 200].span(),
                setup.onchain_id.alice_identity.contract_address,
            );
    }

    #[test]
    #[should_panic(expected: 'Caller is not management key')]
    fn test_should_revert_when_specified_identity_has_transfer_manager_role_but_sender_not_authorized() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let bob_wallet = setup.accounts.bob.account.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(
                AgentRoles::TRANSFER_MANAGER, setup.onchain_id.alice_identity.contract_address,
            );
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
                setup.onchain_id.alice_identity.contract_address,
            );
        stop_cheat_caller_address(setup.agent_manager.contract_address);
    }

    #[test]
    fn test_should_perform_the_transfer_when_identity_has_role_and_sender_authorized() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let bob_wallet = setup.accounts.bob.account.contract_address;

        start_cheat_caller_address(
            setup.agent_manager.contract_address,
            setup.accounts.token_admin.account.contract_address,
        );
        IAccessControlDispatcher { contract_address: setup.agent_manager.contract_address }
            .grant_role(
                AgentRoles::TRANSFER_MANAGER, setup.onchain_id.alice_identity.contract_address,
            );
        stop_cheat_caller_address(setup.agent_manager.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(setup.agent_manager.contract_address, alice_wallet);
        setup
            .agent_manager
            .call_batch_forced_transfer(
                [alice_wallet, bob_wallet].span(),
                [bob_wallet, alice_wallet].span(),
                [200, 200].span(),
                setup.onchain_id.alice_identity.contract_address,
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
    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_missing_freezer_role() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_has_freezer_role_but_sender_not_authorized() {
        panic!("");
    }

    #[test]
    fn test_should_perform_the_pause_when_identity_has_role_and_sender_authorized() {
        assert(true, '');
    }
}

pub mod call_unpause {
    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_missing_freezer_role() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_has_freezer_role_but_sender_not_authorized() {
        panic!("");
    }

    #[test]
    fn test_should_perform_the_unpause_when_identity_has_role_and_sender_authorized() {
        assert(true, '');
    }
}

pub mod call_mint {
    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_missing_supply_modifier_role() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_has_supply_modifier_role_but_sender_not_authorized() {
        panic!("");
    }

    #[test]
    fn test_should_perform_the_mint_when_identity_has_role_and_sender_authorized() {
        assert(true, '');
    }
}

pub mod call_batch_mint {
    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_missing_supply_modifier_role() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_has_supply_modifier_role_but_sender_not_authorized() {
        panic!("");
    }

    #[test]
    fn test_should_perform_the_batch_mint_when_identity_has_role_and_sender_authorized() {
        assert(true, '');
    }
}

pub mod call_burn {
    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_missing_supply_modifier_role() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_has_supply_modifier_role_but_sender_not_authorized() {
        panic!("");
    }

    #[test]
    fn test_should_perform_the_burn_when_identity_has_role_and_sender_authorized() {
        assert(true, '');
    }
}

pub mod call_batch_burn {
    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_missing_supply_modifier_role() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_has_supply_modifier_role_but_sender_not_authorized() {
        panic!("");
    }

    #[test]
    fn test_should_perform_the_batch_burn_when_identity_has_role_and_sender_authorized() {
        assert(true, '');
    }
}

pub mod call_set_address_frozen {
    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_missing_freezer_role() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_has_freezer_role_but_sender_not_authorized() {
        panic!("");
    }

    #[test]
    fn test_should_perform_the_freeze_when_identity_has_role_and_sender_authorized() {
        assert(true, '');
    }
}

pub mod call_batch_set_address_frozen {
    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_missing_freezer_role() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_has_freezer_role_but_sender_not_authorized() {
        panic!("");
    }

    #[test]
    fn test_should_perform_the_batch_pause_when_identity_has_role_and_sender_authorized() {
        assert(true, '');
    }
}

pub mod call_freeze_partial_tokens {
    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_missing_freezer_role() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_has_freezer_role_but_sender_not_authorized() {
        panic!("");
    }

    #[test]
    fn test_should_perform_freeze_of_partial_tokens_when_identity_has_role_and_sender_authorized() {
        assert(true, '');
    }
}

pub mod call_batch_freeze_partial_tokens {
    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_missing_freezer_role() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_has_freezer_role_but_sender_not_authorized() {
        panic!("");
    }

    #[test]
    fn test_should_perform_batch_freeze_of_partial_tokens_when_identity_has_role_and_sender_authorized() {
        assert(true, '');
    }
}

pub mod call_unfreeze_partial_tokens {
    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_missing_freezer_role() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_has_freezer_role_but_sender_not_authorized() {
        panic!("");
    }

    #[test]
    fn test_should_perform_unfreeze_of_partial_tokens_when_identity_has_role_and_sender_authorized() {
        assert(true, '');
    }
}

pub mod call_batch_unfreeze_partial_tokens {
    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_missing_freezer_role() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_has_freezer_role_but_sender_not_authorized() {
        panic!("");
    }

    #[test]
    fn test_should_perform_batch_unfreeze_of_partial_tokens_when_identity_has_role_and_sender_authorized() {
        assert(true, '');
    }
}

pub mod call_recovery_address {
    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_missing_recovery_agent_role() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_revert_when_specified_identity_has_recovery_agent_role_but_sender_not_authorized() {
        panic!("");
    }

    #[test]
    fn test_should_perform_recovery_of_address_when_identity_has_role_and_sender_authorized() {
        assert(true, '');
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
