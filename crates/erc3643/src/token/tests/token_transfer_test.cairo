pub mod approve {
    use openzeppelin_token::erc20::{
        ERC20Component, interface::{IERC20Dispatcher, IERC20DispatcherTrait},
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use test_commons::commons::setup_full_suite;

    #[test]
    fn test_should_approve_a_contract_to_spend_a_certain_amount_of_tokens() {
        let setup = setup_full_suite();
        let alice_wallet = setup.accounts.alice.account.contract_address;
        let spender = starknet::contract_address_const::<'SPENDER'>();
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };
        let allowance = 100;

        let mut spy = spy_events();
        start_cheat_caller_address(erc20_dispatcher.contract_address, alice_wallet);
        erc20_dispatcher.approve(spender, allowance);
        stop_cheat_caller_address(setup.token.contract_address);

        assert(
            erc20_dispatcher.allowance(alice_wallet, spender) == allowance,
            'Allowance does not match',
        );
        spy
            .assert_emitted(
                @array![
                    (
                        erc20_dispatcher.contract_address,
                        ERC20Component::Event::Approval(
                            ERC20Component::Approval {
                                owner: alice_wallet, spender, value: allowance,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod transfer {
    use crate::compliance::imodular_compliance::IModularComplianceDispatcherTrait;
    use crate::token::itoken::ITokenDispatcherTrait;
    use openzeppelin_token::erc20::{
        ERC20Component, interface::{IERC20Dispatcher, IERC20DispatcherTrait},
    };
    use snforge_std::{
        ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
        start_cheat_caller_address, stop_cheat_caller_address,
    };
    use test_commons::commons::setup_full_suite;

    #[test]
    #[should_panic(expected: 'Pausable: paused')]
    fn test_should_panic_when_token_is_paused() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let amount = 100;

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.pause();
        stop_cheat_caller_address(setup.token.contract_address);

        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };
        start_cheat_caller_address(erc20_dispatcher.contract_address, sender);
        erc20_dispatcher.transfer(recipient, amount);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Wallet is frozen')]
    fn test_should_panic_when_the_recipient_balance_is_frozen() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let amount = 100;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };

        start_cheat_caller_address(
            erc20_dispatcher.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.set_address_frozen(recipient, true);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);

        start_cheat_caller_address(erc20_dispatcher.contract_address, sender);
        erc20_dispatcher.transfer(recipient, amount);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Wallet is frozen')]
    fn test_should_panic_when_the_sender_balance_is_frozen() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let amount = 100;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };

        start_cheat_caller_address(
            erc20_dispatcher.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.set_address_frozen(sender, true);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);

        start_cheat_caller_address(erc20_dispatcher.contract_address, sender);
        erc20_dispatcher.transfer(recipient, amount);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Insufficient available balance')]
    fn test_should_panic_when_the_sender_has_not_enough_balance() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };
        let amount = erc20_dispatcher.balance_of(sender) + 1;

        start_cheat_caller_address(erc20_dispatcher.contract_address, sender);
        erc20_dispatcher.transfer(recipient, amount);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Insufficient available balance')]
    fn test_should_panic_when_the_sender_has_not_enough_balance_unfrozen() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };
        let balance = erc20_dispatcher.balance_of(sender);

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.freeze_partial_tokens(sender, 1);
        stop_cheat_caller_address(setup.token.contract_address);

        start_cheat_caller_address(erc20_dispatcher.contract_address, sender);
        erc20_dispatcher.transfer(recipient, balance);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Identity is not verified')]
    fn test_should_panic_when_the_recipient_identity_is_not_verified() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = starknet::contract_address_const::<'NOT_VERIFIED'>();
        let amount = 100;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };

        start_cheat_caller_address(erc20_dispatcher.contract_address, sender);
        erc20_dispatcher.transfer(recipient, amount);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Compliance check failed')]
    fn test_should_panic_when_the_transfer_breaks_compliance_rules() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let amount = 100;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };

        let compliance_module_contract = declare("CountryAllowModule").unwrap().contract_class();
        let (compliance_module_address, _) = compliance_module_contract
            .deploy(@array![starknet::get_contract_address().into()])
            .unwrap();
        setup.modular_compliance.add_module(compliance_module_address);

        start_cheat_caller_address(erc20_dispatcher.contract_address, sender);
        erc20_dispatcher.transfer(recipient, amount);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);
    }

    #[test]
    fn test_should_transfer_tokens_when_the_transfer_is_compliant() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let amount = 100;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };

        let sender_balance_prev = erc20_dispatcher.balance_of(sender);
        let recipient_balance_prev = erc20_dispatcher.balance_of(recipient);

        let mut spy = spy_events();
        start_cheat_caller_address(erc20_dispatcher.contract_address, sender);
        erc20_dispatcher.transfer(recipient, amount);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);

        let sender_balance_after = erc20_dispatcher.balance_of(sender);
        let recipient_balance_after = erc20_dispatcher.balance_of(recipient);
        assert(sender_balance_prev - amount == sender_balance_after, 'Sender balance mismatch');
        assert(
            recipient_balance_prev + amount == recipient_balance_after,
            'Recipient balance mismatch',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        erc20_dispatcher.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer { from: sender, to: recipient, value: amount },
                        ),
                    ),
                ],
            );
    }
}

pub mod batch_transfer {
    use core::num::traits::Zero;
    use crate::compliance::imodular_compliance::IModularComplianceDispatcherTrait;
    use crate::token::itoken::ITokenDispatcherTrait;
    use openzeppelin_token::erc20::{
        ERC20Component, interface::{IERC20Dispatcher, IERC20DispatcherTrait},
    };
    use snforge_std::{
        ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
        start_cheat_caller_address, stop_cheat_caller_address,
    };
    use test_commons::commons::setup_full_suite;

    #[test]
    #[should_panic(expected: 'Pausable: paused')]
    fn test_should_panic_when_token_is_paused() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let amount = 100;

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.pause();
        stop_cheat_caller_address(setup.token.contract_address);

        start_cheat_caller_address(setup.token.contract_address, sender);
        setup.token.batch_transfer([recipient].span(), [amount].span());
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Wallet is frozen')]
    fn test_should_panic_when_the_recipient_balance_is_frozen() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let first_recipient = setup.accounts.david.account.contract_address;
        let second_recipient = setup.accounts.bob.account.contract_address;
        let amount = 100;

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.set_address_frozen(second_recipient, true);
        stop_cheat_caller_address(setup.token.contract_address);

        start_cheat_caller_address(setup.token.contract_address, sender);
        setup
            .token
            .batch_transfer([first_recipient, second_recipient].span(), [amount, amount].span());
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Wallet is frozen')]
    fn test_should_panic_when_the_sender_balance_is_frozen() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let amount = 100;

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.set_address_frozen(sender, true);
        stop_cheat_caller_address(setup.token.contract_address);

        start_cheat_caller_address(setup.token.contract_address, sender);
        setup.token.batch_transfer([recipient].span(), [amount].span());
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Insufficient available balance')]
    fn test_should_panic_when_the_sender_has_not_enough_balance() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };
        let amount = erc20_dispatcher.balance_of(sender) + 1;

        start_cheat_caller_address(setup.token.contract_address, sender);
        setup.token.batch_transfer([recipient].span(), [amount].span());
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Insufficient available balance')]
    fn test_should_panic_when_the_sender_has_not_enough_balance_unfrozen() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };
        let balance = erc20_dispatcher.balance_of(sender);

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.freeze_partial_tokens(sender, 1);
        stop_cheat_caller_address(setup.token.contract_address);

        start_cheat_caller_address(setup.token.contract_address, sender);
        setup.token.batch_transfer([recipient].span(), [balance].span());
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Identity is not verified')]
    fn test_should_panic_when_the_recipient_identity_is_not_verified() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let valid_recipient = setup.accounts.bob.account.contract_address;
        let non_verified_recipient = starknet::contract_address_const::<'NOT_VERIFIED'>();
        let amount = 100;

        start_cheat_caller_address(setup.token.contract_address, sender);
        setup
            .token
            .batch_transfer(
                [valid_recipient, non_verified_recipient].span(), [amount, amount].span(),
            );
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Compliance check failed')]
    fn test_should_panic_when_the_transfer_breaks_compliance_rules() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let amount = 100;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };

        let compliance_module_contract = declare("CountryAllowModule").unwrap().contract_class();
        let (compliance_module_address, _) = compliance_module_contract
            .deploy(@array![starknet::get_contract_address().into()])
            .unwrap();
        setup.modular_compliance.add_module(compliance_module_address);

        start_cheat_caller_address(setup.token.contract_address, sender);
        setup.token.batch_transfer([recipient].span(), [amount].span());
        stop_cheat_caller_address(erc20_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Array lengths not parallel')]
    fn test_should_panic_when_arrays_len_not_parallel() {
        let setup = setup_full_suite();

        setup.token.batch_transfer([Zero::zero(), Zero::zero()].span(), [100].span());
    }

    #[test]
    fn test_should_transfer_tokens() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };

        let sender_balance_prev = erc20_dispatcher.balance_of(sender);
        let recipient_balance_prev = erc20_dispatcher.balance_of(recipient);

        let mut spy = spy_events();
        start_cheat_caller_address(erc20_dispatcher.contract_address, sender);
        setup.token.batch_transfer([recipient, recipient].span(), [100, 200].span());
        stop_cheat_caller_address(erc20_dispatcher.contract_address);

        let sender_balance_after = erc20_dispatcher.balance_of(sender);
        let recipient_balance_after = erc20_dispatcher.balance_of(recipient);
        assert(sender_balance_prev - 300 == sender_balance_after, 'Sender balance mismatch');
        assert(
            recipient_balance_prev + 300 == recipient_balance_after, 'Recipient balance mismatch',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        erc20_dispatcher.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer { from: sender, to: recipient, value: 100 },
                        ),
                    ),
                    (
                        erc20_dispatcher.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer { from: sender, to: recipient, value: 200 },
                        ),
                    ),
                ],
            );
    }
}

pub mod transfer_from {
    use core::num::traits::Bounded;
    use crate::compliance::imodular_compliance::IModularComplianceDispatcherTrait;
    use crate::token::itoken::ITokenDispatcherTrait;
    use openzeppelin_token::erc20::{
        ERC20Component, interface::{IERC20Dispatcher, IERC20DispatcherTrait},
    };
    use snforge_std::{
        ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
        start_cheat_caller_address, stop_cheat_caller_address,
    };
    use test_commons::commons::setup_full_suite;

    #[test]
    #[should_panic(expected: 'Pausable: paused')]
    fn test_should_panic_when_the_token_is_paused() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let spender = starknet::contract_address_const::<'SPENDER'>();
        let amount = 100;

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.pause();
        stop_cheat_caller_address(setup.token.contract_address);

        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };
        start_cheat_caller_address(erc20_dispatcher.contract_address, spender);
        erc20_dispatcher.transfer_from(sender, recipient, amount);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Wallet is frozen')]
    fn test_should_panic_when_sender_address_is_frozen() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let spender = starknet::contract_address_const::<'SPENDER'>();
        let amount = 100;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };

        start_cheat_caller_address(
            erc20_dispatcher.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.set_address_frozen(sender, true);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);

        start_cheat_caller_address(erc20_dispatcher.contract_address, spender);
        erc20_dispatcher.transfer_from(sender, recipient, amount);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Wallet is frozen')]
    fn test_should_panic_when_recipient_address_is_frozen() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let spender = starknet::contract_address_const::<'SPENDER'>();
        let amount = 100;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };

        start_cheat_caller_address(
            erc20_dispatcher.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.set_address_frozen(recipient, true);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);

        start_cheat_caller_address(erc20_dispatcher.contract_address, spender);
        erc20_dispatcher.transfer_from(sender, recipient, amount);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Insufficient available balance')]
    fn test_should_panic_when_sender_has_not_enough_balance() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let spender = starknet::contract_address_const::<'SPENDER'>();
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };
        let amount = erc20_dispatcher.balance_of(sender) + 1;

        start_cheat_caller_address(erc20_dispatcher.contract_address, sender);
        erc20_dispatcher.approve(spender, Bounded::MAX);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);

        start_cheat_caller_address(erc20_dispatcher.contract_address, spender);
        erc20_dispatcher.transfer_from(sender, recipient, amount);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Insufficient available balance')]
    fn test_should_panic_when_sender_has_not_enough_balance_unfrozen() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let spender = starknet::contract_address_const::<'SPENDER'>();
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };
        let balance = erc20_dispatcher.balance_of(sender);

        start_cheat_caller_address(
            erc20_dispatcher.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.freeze_partial_tokens(sender, balance - 100);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);

        start_cheat_caller_address(erc20_dispatcher.contract_address, sender);
        erc20_dispatcher.approve(spender, Bounded::MAX);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);

        start_cheat_caller_address(erc20_dispatcher.contract_address, spender);
        erc20_dispatcher.transfer_from(sender, recipient, balance);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: 'ERC20: insufficient allowance')]
    fn test_should_panic_when_spender_does_not_have_enough_allowance() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let spender = starknet::contract_address_const::<'SPENDER'>();
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };
        let amount = 100;

        start_cheat_caller_address(erc20_dispatcher.contract_address, sender);
        erc20_dispatcher.approve(spender, amount - 1);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);

        start_cheat_caller_address(erc20_dispatcher.contract_address, spender);
        erc20_dispatcher.transfer_from(sender, recipient, amount);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Identity is not verified')]
    fn test_should_panic_when_the_recipient_identity_is_not_verified() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = starknet::contract_address_const::<'NOT_VERIFIED'>();
        let spender = starknet::contract_address_const::<'SPENDER'>();
        let amount = 100;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };

        start_cheat_caller_address(erc20_dispatcher.contract_address, sender);
        erc20_dispatcher.approve(spender, Bounded::MAX);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);

        start_cheat_caller_address(erc20_dispatcher.contract_address, spender);
        erc20_dispatcher.transfer_from(sender, recipient, amount);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Compliance check failed')]
    fn test_should_panic_when_the_transfer_breaks_compliance_rules() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let spender = starknet::contract_address_const::<'SPENDER'>();
        let amount = 100;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };

        let compliance_module_contract = declare("CountryAllowModule").unwrap().contract_class();
        let (compliance_module_address, _) = compliance_module_contract
            .deploy(@array![starknet::get_contract_address().into()])
            .unwrap();
        setup.modular_compliance.add_module(compliance_module_address);

        start_cheat_caller_address(erc20_dispatcher.contract_address, sender);
        erc20_dispatcher.approve(spender, Bounded::MAX);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);

        start_cheat_caller_address(erc20_dispatcher.contract_address, spender);
        erc20_dispatcher.transfer_from(sender, recipient, amount);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);
    }

    #[test]
    fn test_should_transfer_tokens_and_reduce_allowance_of_transferred_value_when_the_transfer_is_compliant() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let spender = starknet::contract_address_const::<'SPENDER'>();
        let amount = 100;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };

        let sender_balance_prev = erc20_dispatcher.balance_of(sender);
        let recipient_balance_prev = erc20_dispatcher.balance_of(recipient);

        start_cheat_caller_address(erc20_dispatcher.contract_address, sender);
        erc20_dispatcher.approve(spender, 100);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);

        let mut spy = spy_events();
        start_cheat_caller_address(erc20_dispatcher.contract_address, spender);
        erc20_dispatcher.transfer_from(sender, recipient, amount);
        stop_cheat_caller_address(erc20_dispatcher.contract_address);

        let sender_balance_after = erc20_dispatcher.balance_of(sender);
        let recipient_balance_after = erc20_dispatcher.balance_of(recipient);
        assert(sender_balance_prev - amount == sender_balance_after, 'Sender balance mismatch');
        assert(
            recipient_balance_prev + amount == recipient_balance_after,
            'Recipient balance mismatch',
        );
        assert(erc20_dispatcher.allowance(sender, spender) == 0, 'Allowance not reduced');

        spy
            .assert_emitted(
                @array![
                    (
                        erc20_dispatcher.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer { from: sender, to: recipient, value: amount },
                        ),
                    ),
                ],
            );
    }
}

pub mod forced_transfer {
    use crate::compliance::imodular_compliance::IModularComplianceDispatcherTrait;
    use crate::token::{Token, itoken::ITokenDispatcherTrait};
    use openzeppelin_token::erc20::{
        ERC20Component, interface::{IERC20Dispatcher, IERC20DispatcherTrait},
    };
    use snforge_std::{
        ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
        start_cheat_caller_address, stop_cheat_caller_address,
    };
    use test_commons::commons::setup_full_suite;

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_panic_when_sender_is_not_an_agent() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let amount = 100;

        start_cheat_caller_address(
            setup.token.contract_address, starknet::contract_address_const::<'NOT_AGENT'>(),
        );
        setup.token.forced_transfer(sender, recipient, amount);
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'ERC20: insufficient balance')]
    fn test_should_panic_when_source_wallet_has_not_enough_balance() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };
        let amount = erc20_dispatcher.balance_of(sender) + 1;

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.forced_transfer(sender, recipient, amount);
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Identity is not verified')]
    fn test_should_panic_when_recipient_identity_is_not_verified() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = starknet::contract_address_const::<'NOT_VERIFIED'>();
        let amount = 100;

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.forced_transfer(sender, recipient, amount);
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    fn test_should_still_transfer_tokens_when_the_transfer_breaks_compliance_rules() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let amount = 100;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };

        let compliance_module_contract = declare("CountryAllowModule").unwrap().contract_class();
        let (compliance_module_address, _) = compliance_module_contract
            .deploy(@array![starknet::get_contract_address().into()])
            .unwrap();
        setup.modular_compliance.add_module(compliance_module_address);

        let sender_balance_prev = erc20_dispatcher.balance_of(sender);
        let recipient_balance_prev = erc20_dispatcher.balance_of(recipient);

        let mut spy = spy_events();
        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.forced_transfer(sender, recipient, amount);
        stop_cheat_caller_address(setup.token.contract_address);

        let sender_balance_after = erc20_dispatcher.balance_of(sender);
        let recipient_balance_after = erc20_dispatcher.balance_of(recipient);
        assert(sender_balance_prev - amount == sender_balance_after, 'Sender balance mismatch');
        assert(
            recipient_balance_prev + amount == recipient_balance_after,
            'Recipient balance mismatch',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        erc20_dispatcher.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer { from: sender, to: recipient, value: amount },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_should_unfreeze_tokens_when_amount_is_greater_than_unfrozen_balance() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };

        let sender_balance_prev = erc20_dispatcher.balance_of(sender);
        let recipient_balance_prev = erc20_dispatcher.balance_of(recipient);

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.freeze_partial_tokens(sender, sender_balance_prev - 100);

        let mut spy = spy_events();
        setup.token.forced_transfer(sender, recipient, sender_balance_prev - 50);
        stop_cheat_caller_address(setup.token.contract_address);

        let sender_balance_after = erc20_dispatcher.balance_of(sender);
        let recipient_balance_after = erc20_dispatcher.balance_of(recipient);
        assert(sender_balance_after == 50, 'Sender balance mismatch');
        assert(
            recipient_balance_prev + sender_balance_prev - 50 == recipient_balance_after,
            'Recipient balance mismatch',
        );
        assert(setup.token.get_frozen_tokens(sender) == 50, 'Frozen token mismatch');

        spy
            .assert_emitted(
                @array![
                    (
                        erc20_dispatcher.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: sender, to: recipient, value: sender_balance_prev - 50,
                            },
                        ),
                    ),
                ],
            );

        spy
            .assert_emitted(
                @array![
                    (
                        erc20_dispatcher.contract_address,
                        Token::Event::TokensUnfrozen(
                            Token::TokensUnfrozen {
                                user_address: sender, amount: sender_balance_prev - 150,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod batch_forced_transfer {
    use core::num::traits::Zero;
    use crate::compliance::imodular_compliance::IModularComplianceDispatcherTrait;
    use crate::token::{Token, itoken::ITokenDispatcherTrait};
    use openzeppelin_token::erc20::{
        ERC20Component, interface::{IERC20Dispatcher, IERC20DispatcherTrait},
    };
    use snforge_std::{
        ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
        start_cheat_caller_address, stop_cheat_caller_address,
    };
    use test_commons::commons::setup_full_suite;

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_panic_when_sender_is_not_an_agent() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let amount = 100;

        start_cheat_caller_address(
            setup.token.contract_address, starknet::contract_address_const::<'NOT_AGENT'>(),
        );
        setup.token.batch_forced_transfer([sender].span(), [recipient].span(), [amount].span());
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Array lengths not parallel')]
    fn test_should_panic_when_arrays_len_not_parallel() {
        let setup = setup_full_suite();

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup
            .token
            .batch_forced_transfer(
                [Zero::zero(), Zero::zero(), Zero::zero()].span(),
                [Zero::zero(), Zero::zero()].span(),
                [100].span(),
            );
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'ERC20: insufficient balance')]
    fn test_should_panic_when_source_wallet_has_not_enough_balance() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };
        let amount = erc20_dispatcher.balance_of(sender) + 1;

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.batch_forced_transfer([sender].span(), [recipient].span(), [amount].span());
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Identity is not verified')]
    fn test_should_panic_when_recipient_identity_is_not_verified() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let valid_recipient = setup.accounts.bob.account.contract_address;
        let non_verified_recipient = starknet::contract_address_const::<'NOT_VERIFIED'>();
        let amount = 100;

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup
            .token
            .batch_forced_transfer(
                [sender, sender].span(),
                [valid_recipient, non_verified_recipient].span(),
                [amount, amount].span(),
            );
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    fn test_should_still_transfer_tokens_when_the_transfer_breaks_compliance_rules() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let amount = 100;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };

        let compliance_module_contract = declare("CountryAllowModule").unwrap().contract_class();
        let (compliance_module_address, _) = compliance_module_contract
            .deploy(@array![starknet::get_contract_address().into()])
            .unwrap();
        setup.modular_compliance.add_module(compliance_module_address);

        let sender_balance_prev = erc20_dispatcher.balance_of(sender);
        let recipient_balance_prev = erc20_dispatcher.balance_of(recipient);

        let mut spy = spy_events();
        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.batch_forced_transfer([sender].span(), [recipient].span(), [amount].span());
        stop_cheat_caller_address(setup.token.contract_address);

        let sender_balance_after = erc20_dispatcher.balance_of(sender);
        let recipient_balance_after = erc20_dispatcher.balance_of(recipient);
        assert(sender_balance_prev - amount == sender_balance_after, 'Sender balance mismatch');
        assert(
            recipient_balance_prev + amount == recipient_balance_after,
            'Recipient balance mismatch',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        erc20_dispatcher.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer { from: sender, to: recipient, value: amount },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_should_unfreeze_tokens_when_amount_is_greater_than_unfrozen_balance() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let recipient = setup.accounts.bob.account.contract_address;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };

        let sender_balance_prev = erc20_dispatcher.balance_of(sender);
        let recipient_balance_prev = erc20_dispatcher.balance_of(recipient);

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.freeze_partial_tokens(sender, sender_balance_prev - 100);

        let mut spy = spy_events();
        setup
            .token
            .batch_forced_transfer(
                [sender].span(), [recipient].span(), [sender_balance_prev - 50].span(),
            );
        stop_cheat_caller_address(setup.token.contract_address);

        let sender_balance_after = erc20_dispatcher.balance_of(sender);
        let recipient_balance_after = erc20_dispatcher.balance_of(recipient);
        assert(sender_balance_after == 50, 'Sender balance mismatch');
        assert(
            recipient_balance_prev + sender_balance_prev - 50 == recipient_balance_after,
            'Recipient balance mismatch',
        );
        assert(setup.token.get_frozen_tokens(sender) == 50, 'Frozen token mismatch');

        spy
            .assert_emitted(
                @array![
                    (
                        erc20_dispatcher.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: sender, to: recipient, value: sender_balance_prev - 50,
                            },
                        ),
                    ),
                ],
            );

        spy
            .assert_emitted(
                @array![
                    (
                        erc20_dispatcher.contract_address,
                        Token::Event::TokensUnfrozen(
                            Token::TokensUnfrozen {
                                user_address: sender, amount: sender_balance_prev - 150,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod mint {
    use core::num::traits::Zero;
    use crate::compliance::imodular_compliance::IModularComplianceDispatcherTrait;
    use crate::token::itoken::ITokenDispatcherTrait;
    use openzeppelin_token::erc20::{
        ERC20Component, interface::{IERC20Dispatcher, IERC20DispatcherTrait},
    };
    use snforge_std::{
        ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
        start_cheat_caller_address, stop_cheat_caller_address,
    };
    use test_commons::commons::setup_full_suite;

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_panic_when_caller_is_not_an_agent() {
        let setup = setup_full_suite();
        let recipient = setup.accounts.alice.account.contract_address;
        let amount = 100;

        start_cheat_caller_address(
            setup.token.contract_address, starknet::contract_address_const::<'NOT_AGENT'>(),
        );
        setup.token.mint(recipient, amount);
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Identity is not verified')]
    fn test_should_panic_when_recipient_identity_is_not_verified() {
        let setup = setup_full_suite();
        let recipient = starknet::contract_address_const::<'NOT_VERIFIED'>();
        let amount = 100;

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.mint(recipient, amount);
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Compliance check failed')]
    fn test_should_panic_when_the_mint_breaks_compliance_rules() {
        let setup = setup_full_suite();
        let recipient = setup.accounts.alice.account.contract_address;
        let amount = 100;

        let compliance_module_contract = declare("CountryAllowModule").unwrap().contract_class();
        let (compliance_module_address, _) = compliance_module_contract
            .deploy(@array![starknet::get_contract_address().into()])
            .unwrap();
        setup.modular_compliance.add_module(compliance_module_address);

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.mint(recipient, amount);
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    fn test_should_mint_tokens() {
        let setup = setup_full_suite();
        let recipient = setup.accounts.alice.account.contract_address;
        let amount = 100;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };
        let recipient_balance_prev = erc20_dispatcher.balance_of(recipient);

        let mut spy = spy_events();
        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.mint(recipient, amount);
        stop_cheat_caller_address(setup.token.contract_address);
        let recipient_balance_after = erc20_dispatcher.balance_of(recipient);
        assert(recipient_balance_prev + amount == recipient_balance_after, 'Tokens not minted');
        spy
            .assert_emitted(
                @array![
                    (
                        erc20_dispatcher.contract_address,
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

pub mod batch_mint {
    use core::num::traits::Zero;
    use crate::compliance::imodular_compliance::IModularComplianceDispatcherTrait;
    use crate::token::itoken::ITokenDispatcherTrait;
    use openzeppelin_token::erc20::{
        ERC20Component, interface::{IERC20Dispatcher, IERC20DispatcherTrait},
    };
    use snforge_std::{
        ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
        start_cheat_caller_address, stop_cheat_caller_address,
    };
    use test_commons::commons::setup_full_suite;

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_panic_when_caller_is_not_an_agent() {
        let setup = setup_full_suite();
        let recipient = setup.accounts.alice.account.contract_address;
        let amount = 100;

        start_cheat_caller_address(
            setup.token.contract_address, starknet::contract_address_const::<'NOT_AGENT'>(),
        );
        setup.token.batch_mint([recipient].span(), [amount].span());
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Array lengths not parallel')]
    fn test_should_panic_when_arrays_len_not_parallel() {
        let setup = setup_full_suite();

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.batch_mint([Zero::zero(), Zero::zero()].span(), [100].span());
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Identity is not verified')]
    fn test_should_panic_when_recipient_identity_is_not_verified() {
        let setup = setup_full_suite();
        let recipient = starknet::contract_address_const::<'NOT_VERIFIED'>();
        let amount = 100;

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.batch_mint([recipient].span(), [amount].span());
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Compliance check failed')]
    fn test_should_panic_when_the_mint_breaks_compliance_rules() {
        let setup = setup_full_suite();
        let recipient = setup.accounts.alice.account.contract_address;
        let amount = 100;

        let compliance_module_contract = declare("CountryAllowModule").unwrap().contract_class();
        let (compliance_module_address, _) = compliance_module_contract
            .deploy(@array![starknet::get_contract_address().into()])
            .unwrap();
        setup.modular_compliance.add_module(compliance_module_address);

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.batch_mint([recipient].span(), [amount].span());
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    fn test_should_mint_tokens() {
        let setup = setup_full_suite();
        let recipient = setup.accounts.alice.account.contract_address;
        let amount = 100;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };
        let recipient_balance_prev = erc20_dispatcher.balance_of(recipient);

        let mut spy = spy_events();
        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.batch_mint([recipient].span(), [amount].span());
        stop_cheat_caller_address(setup.token.contract_address);
        let recipient_balance_after = erc20_dispatcher.balance_of(recipient);
        assert(recipient_balance_prev + amount == recipient_balance_after, 'Tokens not minted');
        spy
            .assert_emitted(
                @array![
                    (
                        erc20_dispatcher.contract_address,
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

pub mod burn {
    use core::num::traits::Zero;
    use crate::token::{Token, itoken::ITokenDispatcherTrait};
    use openzeppelin_token::erc20::{
        ERC20Component, interface::{IERC20Dispatcher, IERC20DispatcherTrait},
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use test_commons::commons::setup_full_suite;

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_panic_when_caller_is_not_an_agent() {
        let setup = setup_full_suite();
        let burner = setup.accounts.alice.account.contract_address;
        let amount = 100;

        start_cheat_caller_address(
            setup.token.contract_address, starknet::contract_address_const::<'NOT_AGENT'>(),
        );
        setup.token.burn(burner, amount);
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Burn amount exceeds balance')]
    fn test_should_panic_when_source_wallet_has_not_enough_balance() {
        let setup = setup_full_suite();
        let burner = setup.accounts.alice.account.contract_address;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };
        let amount = erc20_dispatcher.balance_of(burner) + 1;

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.burn(burner, amount);
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    fn test_should_burn_and_decrease_frozen_balance_when_amount_to_burn_is_greater_than_unfrozen_balance() {
        let setup = setup_full_suite();
        let burner = setup.accounts.alice.account.contract_address;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };
        let balance_prev = erc20_dispatcher.balance_of(burner);

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.freeze_partial_tokens(burner, balance_prev - 100);

        let mut spy = spy_events();
        setup.token.burn(burner, balance_prev - 50);
        stop_cheat_caller_address(setup.token.contract_address);

        let balance_after = erc20_dispatcher.balance_of(burner);
        assert(balance_after == 50, 'Tokens not burned');
        assert(setup.token.get_frozen_tokens(burner) == 50, 'Frozen balance mismatch');
        spy
            .assert_emitted(
                @array![
                    (
                        erc20_dispatcher.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: burner, to: Zero::zero(), value: balance_prev - 50,
                            },
                        ),
                    ),
                ],
            );

        spy
            .assert_emitted(
                @array![
                    (
                        erc20_dispatcher.contract_address,
                        Token::Event::TokensUnfrozen(
                            Token::TokensUnfrozen {
                                user_address: burner, amount: balance_prev - 150,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod batch_burn {
    use core::num::traits::Zero;
    use crate::token::{Token, itoken::ITokenDispatcherTrait};
    use openzeppelin_token::erc20::{
        ERC20Component, interface::{IERC20Dispatcher, IERC20DispatcherTrait},
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use test_commons::commons::setup_full_suite;

    #[test]
    #[should_panic(expected: 'Caller is not agent')]
    fn test_should_panic_when_caller_is_not_an_agent() {
        let setup = setup_full_suite();
        let burner = setup.accounts.alice.account.contract_address;
        let amount = 100;

        start_cheat_caller_address(
            setup.token.contract_address, starknet::contract_address_const::<'NOT_AGENT'>(),
        );
        setup.token.batch_burn([burner].span(), [amount].span());
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Array lengths not parallel')]
    fn test_should_panic_when_arrays_len_not_parallel() {
        let setup = setup_full_suite();

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.batch_burn([Zero::zero(), Zero::zero()].span(), [100].span());
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Burn amount exceeds balance')]
    fn test_should_panic_when_source_wallet_has_not_enough_balance() {
        let setup = setup_full_suite();
        let burner = setup.accounts.alice.account.contract_address;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };
        let amount = erc20_dispatcher.balance_of(burner) + 1;

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.batch_burn([burner].span(), [amount].span());
        stop_cheat_caller_address(setup.token.contract_address);
    }

    #[test]
    fn test_should_burn_and_decrease_frozen_balance_when_amount_to_burn_is_greater_than_unfrozen_balance() {
        let setup = setup_full_suite();
        let burner = setup.accounts.alice.account.contract_address;
        let erc20_dispatcher = IERC20Dispatcher { contract_address: setup.token.contract_address };
        let balance_prev = erc20_dispatcher.balance_of(burner);

        start_cheat_caller_address(
            setup.token.contract_address, setup.accounts.token_agent.account.contract_address,
        );
        setup.token.freeze_partial_tokens(burner, balance_prev - 100);

        let mut spy = spy_events();
        setup.token.batch_burn([burner].span(), [balance_prev - 50].span());
        stop_cheat_caller_address(setup.token.contract_address);

        let balance_after = erc20_dispatcher.balance_of(burner);
        assert(balance_after == 50, 'Tokens not burned');
        assert(setup.token.get_frozen_tokens(burner) == 50, 'Frozen balance mismatch');
        spy
            .assert_emitted(
                @array![
                    (
                        erc20_dispatcher.contract_address,
                        ERC20Component::Event::Transfer(
                            ERC20Component::Transfer {
                                from: burner, to: Zero::zero(), value: balance_prev - 50,
                            },
                        ),
                    ),
                ],
            );

        spy
            .assert_emitted(
                @array![
                    (
                        erc20_dispatcher.contract_address,
                        Token::Event::TokensUnfrozen(
                            Token::TokensUnfrozen {
                                user_address: burner, amount: balance_prev - 150,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod permit {
    use crate::token::Token::SNIP12MetadataImpl;
    use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin_token::erc20::snip12_utils::permit::Permit;
    use openzeppelin_utils::cryptography::{
        interface::{INoncesDispatcher, INoncesDispatcherTrait}, snip12::OffchainMessageHash,
    };
    use snforge_std::{
        signature::{SignerTrait, stark_curve::StarkCurveSignerImpl}, start_cheat_caller_address,
        stop_cheat_caller_address,
    };
    use test_commons::commons::setup_full_suite;


    #[test]
    fn test_should_approve_via_permit_then_transfer_tokens_via_transfer_from() {
        let setup = setup_full_suite();
        let sender = setup.accounts.alice.account.contract_address;
        let spender = starknet::contract_address_const::<'SPENDER'>();
        let recipient = setup.accounts.bob.account.contract_address;
        let token = setup.token.contract_address;
        let amount = 100;
        /// Current time + DAY
        let deadline = starknet::get_block_timestamp() + 60 * 60 * 24;

        /// Construct and Sign Permit Data
        let nonces_dispatcher = INoncesDispatcher { contract_address: token };
        let nonce = nonces_dispatcher.nonces(sender);
        let permit = Permit { token, spender, amount, nonce, deadline };
        let permit_hash = permit.get_message_hash(sender);
        let (r, s) = setup.accounts.alice.key_pair.sign(permit_hash).unwrap();
        let permit_sig = array![r, s].span();

        let erc20_dispatcher = ERC20ABIDispatcher { contract_address: token };
        let sender_balance_prev = erc20_dispatcher.balance_of(sender);
        let recipient_balance_prev = erc20_dispatcher.balance_of(recipient);

        start_cheat_caller_address(token, spender);
        erc20_dispatcher.permit(sender, spender, amount, deadline, permit_sig);
        assert(erc20_dispatcher.allowance(sender, spender) == amount, 'Not approved via permit');
        erc20_dispatcher.transfer_from(sender, recipient, amount);
        stop_cheat_caller_address(token);

        assert(erc20_dispatcher.allowance(sender, spender) == 0, 'Allowance not reduced');
        assert(
            erc20_dispatcher.balance_of(sender) == sender_balance_prev - amount,
            'Balance mismatch!',
        );
        assert(
            erc20_dispatcher.balance_of(recipient) == recipient_balance_prev + amount,
            'Balance mismatch!',
        );
    }
}
