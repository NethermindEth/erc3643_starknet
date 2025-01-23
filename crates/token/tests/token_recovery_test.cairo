use core::poseidon::poseidon_hash_span;
use factory::tests_common::setup_full_suite;
use onchain_id_starknet::interface::iidentity::IdentityABIDispatcherTrait;
use openzeppelin_token::erc20::interface::{IERC20MixinDispatcher, IERC20MixinDispatcherTrait};
use snforge_std::{
    EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
};
use token::{itoken::ITokenDispatcherTrait, token::Token};

#[test]
#[should_panic(expected: 'Caller is not agent')]
fn test_should_panic_when_caller_is_not_agent() {
    let setup = setup_full_suite();
    let recovery_wallet = starknet::contract_address_const::<'RECOVERY_WALLET'>();
    let bob_wallet = setup.accounts.bob.account.contract_address;
    let bob_identity_address = setup.onchain_id.bob_identity.contract_address;

    start_cheat_caller_address(
        setup.token.contract_address, starknet::contract_address_const::<'NOT_AGENT'>(),
    );
    setup.token.recovery_address(bob_wallet, recovery_wallet, bob_identity_address);
    stop_cheat_caller_address(setup.token.contract_address);
}

#[test]
#[should_panic(expected: 'No tokens to recover')]
fn test_should_panic_when_wallet_to_recover_has_no_balance() {
    let setup = setup_full_suite();
    let recovery_wallet = starknet::contract_address_const::<'RECOVERY_WALLET'>();
    let erc20_dispatcher = IERC20MixinDispatcher { contract_address: setup.token.contract_address };
    let bob_wallet = setup.accounts.bob.account.contract_address;
    let bob_identity_address = setup.onchain_id.bob_identity.contract_address;
    let token_agent = setup.accounts.token_agent.account.contract_address;
    /// Empty bob balance
    start_cheat_caller_address(erc20_dispatcher.contract_address, bob_wallet);
    erc20_dispatcher
        .transfer(
            setup.accounts.alice.account.contract_address, erc20_dispatcher.balance_of(bob_wallet),
        );
    stop_cheat_caller_address(erc20_dispatcher.contract_address);

    start_cheat_caller_address(setup.token.contract_address, token_agent);
    setup.token.recovery_address(bob_wallet, recovery_wallet, bob_identity_address);
    stop_cheat_caller_address(setup.token.contract_address);
}

#[test]
#[should_panic]
fn test_should_panic_when_new_wallet_is_not_authorized_on_the_identity() {
    let setup = setup_full_suite();
    let recovery_wallet = starknet::contract_address_const::<'RECOVERY_WALLET'>();
    let bob_wallet = setup.accounts.bob.account.contract_address;
    let bob_identity_address = setup.onchain_id.bob_identity.contract_address;
    let token_agent = setup.accounts.token_agent.account.contract_address;

    start_cheat_caller_address(setup.token.contract_address, token_agent);
    setup.token.recovery_address(bob_wallet, recovery_wallet, bob_identity_address);
    stop_cheat_caller_address(setup.token.contract_address);
}

#[test]
fn test_should_recover_and_freeze_the_new_wallet_when_wallet_is_frozen() {
    let setup = setup_full_suite();
    let recovery_wallet = starknet::contract_address_const::<'RECOVERY_WALLET'>();
    let erc20_dispatcher = IERC20MixinDispatcher { contract_address: setup.token.contract_address };
    let bob_wallet = setup.accounts.bob.account.contract_address;
    let bob_identity_address = setup.onchain_id.bob_identity.contract_address;
    let token_agent = setup.accounts.token_agent.account.contract_address;
    /// Register recovery wallet to bobs identity as management key
    start_cheat_caller_address(bob_identity_address, bob_wallet);
    setup
        .onchain_id
        .bob_identity
        .add_key(poseidon_hash_span([recovery_wallet.into()].span()), 1, 1);
    stop_cheat_caller_address(bob_identity_address);

    let bob_wallet_balance = erc20_dispatcher.balance_of(bob_wallet);
    start_cheat_caller_address(setup.token.contract_address, token_agent);
    // Set bob wallet frozen
    setup.token.set_address_frozen(bob_wallet, true);

    let mut spy = spy_events();
    setup.token.recovery_address(bob_wallet, recovery_wallet, bob_identity_address);
    stop_cheat_caller_address(setup.token.contract_address);

    assert(
        erc20_dispatcher.balance_of(recovery_wallet) == bob_wallet_balance, 'Balance not recovered',
    );
    assert(erc20_dispatcher.balance_of(bob_wallet) == 0, 'Balance not transfered');
    assert(setup.token.is_frozen(recovery_wallet), 'Address not frozen');

    spy
        .assert_emitted(
            @array![
                (
                    setup.token.contract_address,
                    Token::Event::RecoverySuccess(
                        Token::RecoverySuccess {
                            lost_wallet: bob_wallet,
                            new_wallet: recovery_wallet,
                            investor_onchain_id: bob_identity_address,
                        },
                    ),
                ),
                (
                    setup.token.contract_address,
                    Token::Event::AddressFrozen(
                        Token::AddressFrozen {
                            user_address: recovery_wallet, is_frozen: true, owner: token_agent,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_should_recover_and_freeze_tokens_on_new_wallet_when_wallet_has_frozen_tokens() {
    let setup = setup_full_suite();
    let recovery_wallet = starknet::contract_address_const::<'RECOVERY_WALLET'>();
    let erc20_dispatcher = IERC20MixinDispatcher { contract_address: setup.token.contract_address };
    let bob_wallet = setup.accounts.bob.account.contract_address;
    let bob_identity_address = setup.onchain_id.bob_identity.contract_address;
    let token_agent = setup.accounts.token_agent.account.contract_address;
    /// Register recovery wallet to bobs identity as management key
    start_cheat_caller_address(bob_identity_address, bob_wallet);
    setup
        .onchain_id
        .bob_identity
        .add_key(poseidon_hash_span([recovery_wallet.into()].span()), 1, 1);
    stop_cheat_caller_address(bob_identity_address);

    let bob_wallet_balance = erc20_dispatcher.balance_of(bob_wallet);
    start_cheat_caller_address(setup.token.contract_address, token_agent);
    // Froze partial tokens of Bob
    setup.token.freeze_partial_tokens(bob_wallet, 50);

    let mut spy = spy_events();
    setup.token.recovery_address(bob_wallet, recovery_wallet, bob_identity_address);
    stop_cheat_caller_address(setup.token.contract_address);

    assert(
        erc20_dispatcher.balance_of(recovery_wallet) == bob_wallet_balance, 'Balance not recovered',
    );
    assert(erc20_dispatcher.balance_of(bob_wallet) == 0, 'Balance not transfered');
    assert(setup.token.get_frozen_tokens(recovery_wallet) == 50, 'Tokens not frozen on new wallet');
    assert(setup.token.get_frozen_tokens(bob_wallet) == 0, 'Bob frozen token not zeroed');

    spy
        .assert_emitted(
            @array![
                (
                    setup.token.contract_address,
                    Token::Event::RecoverySuccess(
                        Token::RecoverySuccess {
                            lost_wallet: bob_wallet,
                            new_wallet: recovery_wallet,
                            investor_onchain_id: bob_identity_address,
                        },
                    ),
                ),
                (
                    setup.token.contract_address,
                    Token::Event::TokensFrozen(
                        Token::TokensFrozen { user_address: recovery_wallet, amount: 50 },
                    ),
                ),
            ],
        );
}

#[test]
fn test_should_recover_tokens() {
    let setup = setup_full_suite();
    let recovery_wallet = starknet::contract_address_const::<'RECOVERY_WALLET'>();
    let erc20_dispatcher = IERC20MixinDispatcher { contract_address: setup.token.contract_address };
    let bob_wallet = setup.accounts.bob.account.contract_address;
    let bob_identity_address = setup.onchain_id.bob_identity.contract_address;
    let token_agent = setup.accounts.token_agent.account.contract_address;
    /// Register recovery wallet to bobs identity as management key
    start_cheat_caller_address(bob_identity_address, bob_wallet);
    setup
        .onchain_id
        .bob_identity
        .add_key(poseidon_hash_span([recovery_wallet.into()].span()), 1, 1);
    stop_cheat_caller_address(bob_identity_address);

    let bob_wallet_balance = erc20_dispatcher.balance_of(bob_wallet);
    let mut spy = spy_events();
    start_cheat_caller_address(setup.token.contract_address, token_agent);
    setup.token.recovery_address(bob_wallet, recovery_wallet, bob_identity_address);
    stop_cheat_caller_address(setup.token.contract_address);

    assert(
        erc20_dispatcher.balance_of(recovery_wallet) == bob_wallet_balance, 'Balance not recovered',
    );
    assert(erc20_dispatcher.balance_of(bob_wallet) == 0, 'Balance not transfered');
    assert(setup.token.get_frozen_tokens(recovery_wallet) == 0, 'Tokens frozen on new wallet');
    assert(!setup.token.is_frozen(recovery_wallet), 'Address frozen');

    spy
        .assert_emitted(
            @array![
                (
                    setup.token.contract_address,
                    Token::Event::RecoverySuccess(
                        Token::RecoverySuccess {
                            lost_wallet: bob_wallet,
                            new_wallet: recovery_wallet,
                            investor_onchain_id: bob_identity_address,
                        },
                    ),
                ),
            ],
        );
}
