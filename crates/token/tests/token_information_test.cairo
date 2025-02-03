pub mod set_name {
    use factory::tests_common::setup_full_suite;
    use openzeppelin_token::erc20::interface::{IERC20MixinDispatcher, IERC20MixinDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use token::{itoken::ITokenDispatcherTrait, token::Token};

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_the_owner() {
        let setup = setup_full_suite();

        start_cheat_caller_address(
            setup.token.contract_address, starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        setup.token.set_name("My Token");
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'ERC20-Name: Empty string')]
    fn test_should_panic_when_name_is_empty() {
        let setup = setup_full_suite();

        setup.token.set_name("");
    }

    #[test]
    fn test_should_set_the_name() {
        let setup = setup_full_suite();
        let new_name: ByteArray = "Updated Test Token";

        let mut spy = spy_events();
        setup.token.set_name(new_name.clone());

        let erc20_dispatcher = IERC20MixinDispatcher {
            contract_address: setup.token.contract_address,
        };
        assert(erc20_dispatcher.name() == new_name.clone(), 'Name not set');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        Token::Event::UpdatedTokenInformation(
                            Token::UpdatedTokenInformation {
                                new_name,
                                new_symbol: erc20_dispatcher.symbol(),
                                new_decimals: erc20_dispatcher.decimals(),
                                new_version: setup.token.version(),
                                new_onchain_id: setup.token.onchain_id(),
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod set_symbol {
    use factory::tests_common::setup_full_suite;
    use openzeppelin_token::erc20::interface::{IERC20MixinDispatcher, IERC20MixinDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use token::{itoken::ITokenDispatcherTrait, token::Token};

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_revert_when_caller_is_not_the_owner() {
        let setup = setup_full_suite();

        start_cheat_caller_address(
            setup.token.contract_address, starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        setup.token.set_symbol("UpdtTK");
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'ERC20-Symbol: Empty string')]
    fn test_should_revert_when_symbol_is_empty() {
        let setup = setup_full_suite();

        setup.token.set_symbol("");
    }

    #[test]
    fn test_should_set_the_symbol() {
        let setup = setup_full_suite();
        let new_symbol = "UpdtTK";

        let mut spy = spy_events();
        setup.token.set_symbol(new_symbol.clone());

        let erc20_dispatcher = IERC20MixinDispatcher {
            contract_address: setup.token.contract_address,
        };
        assert(erc20_dispatcher.symbol() == new_symbol.clone(), 'Symbol not set');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        Token::Event::UpdatedTokenInformation(
                            Token::UpdatedTokenInformation {
                                new_name: erc20_dispatcher.name(),
                                new_symbol,
                                new_decimals: erc20_dispatcher.decimals(),
                                new_version: setup.token.version(),
                                new_onchain_id: setup.token.onchain_id(),
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod set_onchain_id {
    use core::num::traits::Zero;
    use factory::tests_common::setup_full_suite;
    use openzeppelin_token::erc20::interface::{IERC20MixinDispatcher, IERC20MixinDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use token::{itoken::ITokenDispatcherTrait, token::Token};

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_revert_when_caller_is_not_the_owner() {
        let setup = setup_full_suite();

        start_cheat_caller_address(
            setup.token.contract_address, starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        setup.token.set_onchain_id(Zero::zero());
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    fn test_should_set_the_onchain_id() {
        let setup = setup_full_suite();
        let new_onchain_id = Zero::zero();

        let mut spy = spy_events();
        setup.token.set_onchain_id(new_onchain_id);

        assert(setup.token.onchain_id() == new_onchain_id, 'OnchainID not set');
        let erc20_dispatcher = IERC20MixinDispatcher {
            contract_address: setup.token.contract_address,
        };
        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        Token::Event::UpdatedTokenInformation(
                            Token::UpdatedTokenInformation {
                                new_name: erc20_dispatcher.name(),
                                new_symbol: erc20_dispatcher.symbol(),
                                new_decimals: erc20_dispatcher.decimals(),
                                new_version: setup.token.version(),
                                new_onchain_id,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod set_identity_registry {
    use core::num::traits::Zero;
    use factory::tests_common::setup_full_suite;
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use token::{itoken::ITokenDispatcherTrait, token::Token};

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_revert_when_caller_is_not_the_owner() {
        let setup = setup_full_suite();

        start_cheat_caller_address(
            setup.token.contract_address, starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        setup.token.set_identity_registry(Zero::zero());
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    fn test_should_set_identity_registry() {
        let setup = setup_full_suite();
        let new_identity_registry = starknet::contract_address_const::<'NEW_IDENTITY_REGISTRY'>();

        let mut spy = spy_events();
        setup.token.set_identity_registry(new_identity_registry);

        assert(
            setup.token.identity_registry().contract_address == new_identity_registry, 'IR not set',
        );
        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        Token::Event::IdentityRegistryAdded(
                            Token::IdentityRegistryAdded {
                                identity_registry: new_identity_registry,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod total_supply {
    use factory::tests_common::setup_full_suite;
    use openzeppelin_token::erc20::interface::{IERC20MixinDispatcher, IERC20MixinDispatcherTrait};

    #[test]
    fn test_should_return_the_total_supply() {
        let setup = setup_full_suite();
        let erc20_dispatcher = IERC20MixinDispatcher {
            contract_address: setup.token.contract_address,
        };
        let alice_balance = erc20_dispatcher
            .balance_of(setup.accounts.alice.account.contract_address);
        let bob_balance = erc20_dispatcher.balance_of(setup.accounts.bob.account.contract_address);
        let expected_total_supply = alice_balance + bob_balance;

        assert(erc20_dispatcher.total_supply() == expected_total_supply, 'Total supply mismatch!');
    }
}

pub mod set_compliance {
    use factory::tests_common::setup_full_suite;
    use snforge_std::{
        EventSpyAssertionsTrait, mock_call, spy_events, start_cheat_caller_address,
        stop_cheat_caller_address,
    };
    use token::{itoken::ITokenDispatcherTrait, token::Token};

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_revert_when_caller_is_not_the_owner() {
        let setup = setup_full_suite();
        let new_compliance = starknet::contract_address_const::<'NEW_COMPLIANCE'>();

        start_cheat_caller_address(
            setup.token.contract_address, starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        setup.token.set_compliance(new_compliance);
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    fn test_should_set_compliance() {
        let setup = setup_full_suite();
        let new_compliance = starknet::contract_address_const::<'NEW_COMPLIANCE'>();
        mock_call(new_compliance, selector!("bind_token"), (), 1);
        let mut spy = spy_events();
        setup.token.set_compliance(new_compliance);
        assert(setup.token.compliance().contract_address == new_compliance, 'Compliance not set');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        Token::Event::ComplianceAdded(
                            Token::ComplianceAdded { compliance: new_compliance },
                        ),
                    ),
                ],
            );
    }
}

pub mod compliance {
    use factory::tests_common::setup_full_suite;
    use token::itoken::ITokenDispatcherTrait;

    #[test]
    fn test_should_return_the_compliance_address() {
        let setup = setup_full_suite();

        assert(
            setup.token.compliance().contract_address == setup.modular_compliance.contract_address,
            'Compliance address mismatch',
        );
    }
}

pub mod pause {
    use factory::tests_common::setup_full_suite;
    use openzeppelin_security::{
        interface::{IPausableDispatcher, IPausableDispatcherTrait}, pausable::PausableComponent,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use token::itoken::ITokenDispatcherTrait;

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_revert_when_caller_is_not_an_agent() {
        let setup = setup_full_suite();

        start_cheat_caller_address(
            setup.token.contract_address, starknet::contract_address_const::<'NOT_AGENT'>(),
        );
        setup.token.pause();
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    fn test_should_pause_the_token_when_caller_is_an_agent_and_token_is_not_paused() {
        let setup = setup_full_suite();

        let mut spy = spy_events();
        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.pause();
        stop_cheat_caller_address(setup.token.contract_address);

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
                                account: setup.accounts.token_agent.account.contract_address,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic(expected: 'Pausable: paused')]
    fn test_should_revert_when_caller_is_agent_and_token_is_already_paused() {
        let setup = setup_full_suite();

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.pause();
        // Pausing when already paused should panic
        setup.token.pause();
        stop_cheat_caller_address(setup.token.contract_address);
    }
}

pub mod unpause {
    use factory::tests_common::setup_full_suite;
    use openzeppelin_security::{
        interface::{IPausableDispatcher, IPausableDispatcherTrait}, pausable::PausableComponent,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use token::itoken::ITokenDispatcherTrait;

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_revert_when_caller_is_not_an_agent() {
        let setup = setup_full_suite();

        start_cheat_caller_address(
            setup.token.contract_address, starknet::contract_address_const::<'NOT_AGENT'>(),
        );
        setup.token.unpause();
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Pausable: not paused')]
    fn test_should_revert_when_caller_is_an_agent_and_token_is_not_paused() {
        let setup = setup_full_suite();

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.unpause();
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    fn test_should_unpause_the_token_when_caller_is_an_agent_and_token_is_paused() {
        let setup = setup_full_suite();

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.pause();

        let mut spy = spy_events();
        setup.token.unpause();
        stop_cheat_caller_address(setup.token.contract_address);

        assert(
            !IPausableDispatcher { contract_address: setup.token.contract_address }.is_paused(),
            'Token is paused',
        );
        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        PausableComponent::Event::Unpaused(
                            PausableComponent::Unpaused {
                                account: setup.accounts.token_agent.account.contract_address,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod set_address_frozen {
    use factory::tests_common::setup_full_suite;
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use token::{itoken::ITokenDispatcherTrait, token::Token};

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_revert_when_sender_is_not_an_agent() {
        let setup = setup_full_suite();
        let user_address = starknet::contract_address_const::<'USER_ADDRESS'>();

        start_cheat_caller_address(
            setup.token.contract_address, starknet::contract_address_const::<'NOT_AGENT'>(),
        );
        setup.token.set_address_frozen(user_address, true);
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    fn test_should_set_address_frozen() {
        let setup = setup_full_suite();
        let user_address = starknet::contract_address_const::<'USER_ADDRESS'>();
        let token_agent = setup.accounts.token_agent.account.contract_address;

        let mut spy = spy_events();
        start_cheat_caller_address(setup.token.contract_address, token_agent);
        setup.token.set_address_frozen(user_address, true);
        assert(setup.token.is_frozen(user_address), 'Not frozen');

        setup.token.set_address_frozen(user_address, false);
        assert(!setup.token.is_frozen(user_address), 'Still frozen');
        stop_cheat_caller_address(setup.token.contract_address);

        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        Token::Event::AddressFrozen(
                            Token::AddressFrozen {
                                user_address, is_frozen: true, owner: token_agent,
                            },
                        ),
                    ),
                    (
                        setup.token.contract_address,
                        Token::Event::AddressFrozen(
                            Token::AddressFrozen {
                                user_address, is_frozen: false, owner: token_agent,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod freeze_partial_tokens {
    use factory::tests_common::setup_full_suite;
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use token::{itoken::ITokenDispatcherTrait, token::Token};

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_revert_when_sender_is_not_an_agent() {
        let setup = setup_full_suite();
        let user_address = starknet::contract_address_const::<'USER_ADDRESS'>();

        start_cheat_caller_address(
            setup.token.contract_address, starknet::contract_address_const::<'NOT_AGENT'>(),
        );
        setup.token.freeze_partial_tokens(user_address, 1);
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Amount exceeds available funds')]
    fn test_should_revert_when_amount_exceeds_current_balance() {
        let setup = setup_full_suite();
        let user_address = starknet::contract_address_const::<'USER_ADDRESS'>();
        let token_agent = setup.accounts.token_agent.account.contract_address;

        start_cheat_caller_address(setup.token.contract_address, token_agent);
        setup.token.freeze_partial_tokens(user_address, 1);
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    fn test_should_freeze_partial_tokens() {
        let setup = setup_full_suite();
        let user_address = setup.accounts.alice.account.contract_address;
        let token_agent = setup.accounts.token_agent.account.contract_address;

        let mut spy = spy_events();
        start_cheat_caller_address(setup.token.contract_address, token_agent);
        setup.token.freeze_partial_tokens(user_address, 1);
        stop_cheat_caller_address(setup.token.contract_address);

        assert(setup.token.get_frozen_tokens(user_address) == 1, 'Frozen amount mismatch');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        Token::Event::TokensFrozen(Token::TokensFrozen { user_address, amount: 1 }),
                    ),
                ],
            );
    }
}

pub mod batch_freeze_partial_tokens {
    use factory::tests_common::setup_full_suite;
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use token::{itoken::ITokenDispatcherTrait, token::Token};

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_revert_when_sender_is_not_an_agent() {
        let setup = setup_full_suite();
        let user_address = starknet::contract_address_const::<'USER_ADDRESS'>();

        start_cheat_caller_address(
            setup.token.contract_address, starknet::contract_address_const::<'NOT_AGENT'>(),
        );
        setup.token.batch_freeze_partial_tokens([user_address].span(), [1].span());
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Amount exceeds available funds')]
    fn test_should_revert_when_amount_exceeds_current_balance() {
        let setup = setup_full_suite();
        let user_address = starknet::contract_address_const::<'USER_ADDRESS'>();
        let token_agent = setup.accounts.token_agent.account.contract_address;

        start_cheat_caller_address(setup.token.contract_address, token_agent);
        setup.token.batch_freeze_partial_tokens([user_address].span(), [1].span());
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Array lengths not parallel')]
    fn test_should_revert_when_array_lengths_not_parallel() {
        let setup = setup_full_suite();
        let first_user_address = setup.accounts.alice.account.contract_address;
        let second_user_address = setup.accounts.bob.account.contract_address;
        let token_agent = setup.accounts.token_agent.account.contract_address;

        start_cheat_caller_address(setup.token.contract_address, token_agent);
        setup
            .token
            .batch_freeze_partial_tokens(
                [first_user_address, second_user_address].span(), [1].span(),
            );
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    fn test_should_batch_freeze_partial_tokens() {
        let setup = setup_full_suite();
        let first_user_address = setup.accounts.alice.account.contract_address;
        let second_user_address = setup.accounts.bob.account.contract_address;
        let token_agent = setup.accounts.token_agent.account.contract_address;

        let mut spy = spy_events();
        start_cheat_caller_address(setup.token.contract_address, token_agent);
        setup
            .token
            .batch_freeze_partial_tokens(
                [first_user_address, second_user_address].span(), [1, 2].span(),
            );
        stop_cheat_caller_address(setup.token.contract_address);

        assert(setup.token.get_frozen_tokens(first_user_address) == 1, 'Frozen amount mismatch');
        assert(setup.token.get_frozen_tokens(second_user_address) == 2, 'Frozen amount mismatch');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        Token::Event::TokensFrozen(
                            Token::TokensFrozen { user_address: first_user_address, amount: 1 },
                        ),
                    ),
                    (
                        setup.token.contract_address,
                        Token::Event::TokensFrozen(
                            Token::TokensFrozen { user_address: second_user_address, amount: 2 },
                        ),
                    ),
                ],
            );
    }
}

pub mod unfreeze_partial_tokens {
    use factory::tests_common::setup_full_suite;
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use token::{itoken::ITokenDispatcherTrait, token::Token};

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_revert_when_sender_is_not_an_agent() {
        let setup = setup_full_suite();
        let user_address = starknet::contract_address_const::<'USER_ADDRESS'>();

        start_cheat_caller_address(
            setup.token.contract_address, starknet::contract_address_const::<'NOT_AGENT'>(),
        );
        setup.token.unfreeze_partial_tokens(user_address, 1);
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Amount exceeds frozen tokens')]
    fn test_should_revert_when_amount_exceeds_current_frozen_balance() {
        let setup = setup_full_suite();
        let user_address = starknet::contract_address_const::<'USER_ADDRESS'>();
        let token_agent = setup.accounts.token_agent.account.contract_address;

        start_cheat_caller_address(setup.token.contract_address, token_agent);
        setup.token.unfreeze_partial_tokens(user_address, 1);
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    fn test_should_unfreeze_partial_tokens() {
        let setup = setup_full_suite();
        let user_address = setup.accounts.alice.account.contract_address;
        let token_agent = setup.accounts.token_agent.account.contract_address;

        start_cheat_caller_address(setup.token.contract_address, token_agent);
        setup.token.freeze_partial_tokens(user_address, 1);

        let mut spy = spy_events();
        setup.token.unfreeze_partial_tokens(user_address, 1);
        stop_cheat_caller_address(setup.token.contract_address);

        assert(setup.token.get_frozen_tokens(user_address) == 0, 'Frozen amount mismatch');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        Token::Event::TokensUnfrozen(
                            Token::TokensUnfrozen { user_address, amount: 1 },
                        ),
                    ),
                ],
            );
    }
}

pub mod batch_unfreeze_partial_tokens {
    use factory::tests_common::setup_full_suite;
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use token::{itoken::ITokenDispatcherTrait, token::Token};

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_revert_when_sender_is_not_an_agent() {
        let setup = setup_full_suite();
        let user_address = starknet::contract_address_const::<'USER_ADDRESS'>();

        start_cheat_caller_address(
            setup.token.contract_address, starknet::contract_address_const::<'NOT_AGENT'>(),
        );
        setup.token.batch_unfreeze_partial_tokens([user_address].span(), [1].span());
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Amount exceeds frozen tokens')]
    fn test_should_revert_when_amount_exceeds_current_frozen_balance() {
        let setup = setup_full_suite();
        let user_address = starknet::contract_address_const::<'USER_ADDRESS'>();
        let token_agent = setup.accounts.token_agent.account.contract_address;

        start_cheat_caller_address(setup.token.contract_address, token_agent);
        setup.token.batch_unfreeze_partial_tokens([user_address].span(), [1].span());
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Array lengths not parallel')]
    fn test_should_revert_when_array_lengths_not_parallel() {
        let setup = setup_full_suite();
        let first_user_address = setup.accounts.alice.account.contract_address;
        let second_user_address = setup.accounts.bob.account.contract_address;
        let token_agent = setup.accounts.token_agent.account.contract_address;

        start_cheat_caller_address(setup.token.contract_address, token_agent);
        setup
            .token
            .batch_unfreeze_partial_tokens(
                [first_user_address, second_user_address].span(), [1].span(),
            );
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    fn test_should_batch_unfreeze_partial_tokens() {
        let setup = setup_full_suite();
        let first_user_address = setup.accounts.alice.account.contract_address;
        let second_user_address = setup.accounts.bob.account.contract_address;
        let token_agent = setup.accounts.token_agent.account.contract_address;

        start_cheat_caller_address(setup.token.contract_address, token_agent);
        setup
            .token
            .batch_freeze_partial_tokens(
                [first_user_address, second_user_address].span(), [10, 20].span(),
            );

        let mut spy = spy_events();
        setup
            .token
            .batch_unfreeze_partial_tokens(
                [first_user_address, second_user_address].span(), [5, 10].span(),
            );
        stop_cheat_caller_address(setup.token.contract_address);

        assert(setup.token.get_frozen_tokens(first_user_address) == 5, 'Frozen amount mismatch');
        assert(setup.token.get_frozen_tokens(second_user_address) == 10, 'Frozen amount mismatch');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        Token::Event::TokensUnfrozen(
                            Token::TokensUnfrozen { user_address: first_user_address, amount: 5 },
                        ),
                    ),
                    (
                        setup.token.contract_address,
                        Token::Event::TokensUnfrozen(
                            Token::TokensUnfrozen { user_address: second_user_address, amount: 10 },
                        ),
                    ),
                ],
            );
    }
}
