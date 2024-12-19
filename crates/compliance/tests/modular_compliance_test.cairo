use compliance::imodular_compliance::{
    IModularComplianceDispatcher, IModularComplianceDispatcherTrait,
};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, mock_call};
use starknet::ContractAddress;

#[derive(Drop, Copy)]
struct Setup {
    compliance: IModularComplianceDispatcher,
    alice: ContractAddress,
    bob: ContractAddress,
    another_wallet: ContractAddress,
}

fn setup() -> Setup {
    let modular_compliance_contract = declare("ModularCompliance").unwrap().contract_class();
    let (mc_address, _) = modular_compliance_contract
        .deploy(@array![starknet::get_contract_address().into()])
        .unwrap();

    Setup {
        compliance: IModularComplianceDispatcher { contract_address: mc_address },
        alice: starknet::contract_address_const::<'ALICE'>(),
        bob: starknet::contract_address_const::<'BOB'>(),
        another_wallet: starknet::contract_address_const::<'ANOTHER_WALLET'>(),
    }
}

fn bind_modules_and_token(setup: @Setup) -> (ContractAddress, ContractAddress) {
    let first_module = starknet::contract_address_const::<'FIRST_MODULE'>();
    let second_module = starknet::contract_address_const::<'SECOND_MODULE'>();
    mock_call(first_module, selector!("is_plug_and_play"), false, 1);
    mock_call(first_module, selector!("can_compliance_bind"), true, 1);
    mock_call(first_module, selector!("bind_compliance"), (), 1);
    (*setup.compliance).add_module(first_module);

    mock_call(second_module, selector!("is_plug_and_play"), false, 1);
    mock_call(second_module, selector!("can_compliance_bind"), true, 1);
    mock_call(second_module, selector!("bind_compliance"), (), 1);
    (*setup.compliance).add_module(second_module);

    (*setup.compliance).bind_token(starknet::get_contract_address());

    mock_call(
        first_module, selector!("module_transfer_action"), (), core::num::traits::Bounded::MAX,
    );
    mock_call(
        second_module, selector!("module_transfer_action"), (), core::num::traits::Bounded::MAX,
    );

    mock_call(first_module, selector!("module_mint_action"), (), core::num::traits::Bounded::MAX);
    mock_call(second_module, selector!("module_mint_action"), (), core::num::traits::Bounded::MAX);

    mock_call(first_module, selector!("module_burn_action"), (), core::num::traits::Bounded::MAX);
    mock_call(second_module, selector!("module_burn_action"), (), core::num::traits::Bounded::MAX);

    mock_call(first_module, selector!("module_check"), true, core::num::traits::Bounded::MAX);
    mock_call(second_module, selector!("module_check"), true, core::num::traits::Bounded::MAX);
    (first_module, second_module)
}

pub mod bind_token {
    use compliance::{
        imodular_compliance::IModularComplianceDispatcherTrait,
        modular_compliance::ModularCompliance,
    };
    use core::num::traits::Zero;
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only owner or token can call')]
    fn test_should_panic_when_token_not_bind_when_caller_not_the_owner_nor_token() {
        let setup = setup();

        let token_address = starknet::contract_address_const::<'TOKEN'>();
        start_cheat_caller_address(setup.compliance.contract_address, setup.another_wallet);
        setup.compliance.bind_token(token_address);
        stop_cheat_caller_address(setup.compliance.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Token zero address')]
    fn test_should_panic_when_token_address_is_zero() {
        let setup = setup();
        setup.compliance.bind_token(Zero::zero());
    }

    #[test]
    fn test_should_bind_token_when_token_not_bind_when_caller_is_owner() {
        let setup = setup();
        let mut spy = spy_events();

        let token_address = starknet::contract_address_const::<'TOKEN'>();
        setup.compliance.bind_token(token_address);

        assert(setup.compliance.get_token_bound() == token_address, 'Token not bound');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.compliance.contract_address,
                        ModularCompliance::Event::TokenBound(
                            ModularCompliance::TokenBound { token: token_address },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_should_bind_token_when_token_not_bind_when_caller_is_token() {
        let setup = setup();
        let mut spy = spy_events();

        let token_address = starknet::contract_address_const::<'TOKEN'>();

        start_cheat_caller_address(setup.compliance.contract_address, token_address);
        setup.compliance.bind_token(token_address);
        stop_cheat_caller_address(setup.compliance.contract_address);

        assert(setup.compliance.get_token_bound() == token_address, 'Token not bound');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.compliance.contract_address,
                        ModularCompliance::Event::TokenBound(
                            ModularCompliance::TokenBound { token: token_address },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_should_bind_token_when_token_already_bound_when_caller_is_owner() {
        let setup = setup();

        let token_address = starknet::contract_address_const::<'TOKEN'>();
        setup.compliance.bind_token(token_address);

        let new_token_address = starknet::contract_address_const::<'NEW_TOKEN'>();
        let mut spy = spy_events();

        setup.compliance.bind_token(new_token_address);
        spy
            .assert_emitted(
                @array![
                    (
                        setup.compliance.contract_address,
                        ModularCompliance::Event::TokenBound(
                            ModularCompliance::TokenBound { token: new_token_address },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic(expected: 'Only owner or token can call')]
    fn test_should_panic_when_token_already_bound_when_caller_is_token() {
        let setup = setup();

        let token_address = starknet::contract_address_const::<'TOKEN'>();
        setup.compliance.bind_token(token_address);

        let new_token_address = starknet::contract_address_const::<'NEW_TOKEN'>();
        start_cheat_caller_address(setup.compliance.contract_address, new_token_address);
        setup.compliance.bind_token(new_token_address);
        stop_cheat_caller_address(setup.compliance.contract_address);
    }
}

pub mod unbind_token {
    use compliance::{
        imodular_compliance::IModularComplianceDispatcherTrait,
        modular_compliance::ModularCompliance,
    };
    use core::num::traits::Zero;
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only owner or token can call')]
    fn test_should_panic_when_token_not_bind_when_caller_not_the_owner_nor_token() {
        let setup = setup();

        let token_address = starknet::contract_address_const::<'TOKEN'>();
        start_cheat_caller_address(setup.compliance.contract_address, setup.another_wallet);
        setup.compliance.unbind_token(token_address);
        stop_cheat_caller_address(setup.compliance.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Token zero address')]
    fn test_should_panic_when_token_address_is_zero() {
        let setup = setup();
        setup.compliance.bind_token(Zero::zero());
    }

    #[test]
    fn test_should_unbind_token_when_caller_is_owner() {
        let setup = setup();

        let token_address = starknet::contract_address_const::<'TOKEN'>();
        setup.compliance.bind_token(token_address);

        let mut spy = spy_events();

        setup.compliance.unbind_token(token_address);
        assert(setup.compliance.get_token_bound() == Zero::zero(), 'Token not unbound');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.compliance.contract_address,
                        ModularCompliance::Event::TokenUnbound(
                            ModularCompliance::TokenUnbound { token: token_address },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_should_unbind_token_when_caller_is_token() {
        let setup = setup();

        let token_address = starknet::contract_address_const::<'TOKEN'>();
        setup.compliance.bind_token(token_address);

        let mut spy = spy_events();

        start_cheat_caller_address(setup.compliance.contract_address, token_address);
        setup.compliance.unbind_token(token_address);
        stop_cheat_caller_address(setup.compliance.contract_address);

        assert(setup.compliance.get_token_bound() == Zero::zero(), 'Token not unbound');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.compliance.contract_address,
                        ModularCompliance::Event::TokenUnbound(
                            ModularCompliance::TokenUnbound { token: token_address },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic(expected: 'This token is not bound')]
    fn test_should_panic_when_token_not_bound() {
        let setup = setup();

        let token_address = starknet::contract_address_const::<'TOKEN'>();
        setup.compliance.unbind_token(token_address);
    }
}

pub mod add_module {
    use compliance::{
        imodular_compliance::IModularComplianceDispatcherTrait,
        modular_compliance::ModularCompliance,
    };
    use core::num::traits::Zero;
    use snforge_std::{
        EventSpyAssertionsTrait, mock_call, spy_events, start_cheat_caller_address,
        stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_the_owner() {
        let setup = setup();

        start_cheat_caller_address(setup.compliance.contract_address, setup.another_wallet);
        setup.compliance.add_module(Zero::zero());
        stop_cheat_caller_address(setup.compliance.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Module address zero')]
    fn test_should_panic_when_module_is_zero_address() {
        let setup = setup();

        setup.compliance.add_module(Zero::zero());
    }

    #[test]
    #[should_panic(expected: 'Compliance cannot bind')]
    fn test_should_panic_when_module_is_not_plug_and_play_and_compliance_is_not_suitable_to_bind() {
        let setup = setup();
        let module_address = starknet::contract_address_const::<'MODULE'>();
        mock_call(module_address, selector!("is_plug_and_play"), false, 1);
        mock_call(module_address, selector!("can_compliance_bind"), false, 1);

        setup.compliance.add_module(module_address);
    }

    #[test]
    fn test_should_add_compliance_when_module_not_plug_and_play_but_compliance_can_bind() {
        let setup = setup();
        let module_address = starknet::contract_address_const::<'MODULE'>();
        mock_call(module_address, selector!("is_plug_and_play"), false, 1);
        mock_call(module_address, selector!("can_compliance_bind"), true, 1);
        mock_call(module_address, selector!("bind_compliance"), (), 1);

        let mut spy = spy_events();

        setup.compliance.add_module(module_address);

        assert(setup.compliance.is_module_bound(module_address), 'Module not bound');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.compliance.contract_address,
                        ModularCompliance::Event::ModuleAdded(
                            ModularCompliance::ModuleAdded { module: module_address },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_should_add_compliance_when_module_is_plug_and_play() {
        let setup = setup();
        let module_address = starknet::contract_address_const::<'MODULE'>();
        mock_call(module_address, selector!("is_plug_and_play"), true, 1);
        mock_call(module_address, selector!("can_compliance_bind"), false, 1);
        mock_call(module_address, selector!("bind_compliance"), (), 1);

        let mut spy = spy_events();

        setup.compliance.add_module(module_address);

        assert(setup.compliance.is_module_bound(module_address), 'Module not bound');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.compliance.contract_address,
                        ModularCompliance::Event::ModuleAdded(
                            ModularCompliance::ModuleAdded { module: module_address },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic(expected: 'Module already bound')]
    fn test_should_panic_when_module_already_bound() {
        let setup = setup();

        let module_address = starknet::contract_address_const::<'MODULE'>();
        mock_call(module_address, selector!("is_plug_and_play"), true, 2);
        mock_call(module_address, selector!("can_compliance_bind"), true, 2);
        mock_call(module_address, selector!("bind_compliance"), (), 2);

        setup.compliance.add_module(module_address);
        /// Binding second time should panic
        setup.compliance.add_module(module_address);
    }

    #[test]
    #[should_panic(expected: 'Cannot add more than 25 modules')]
    fn test_should_panic_when_max_modules_exceed() {
        let setup = setup();
        for i in 1..26_u8 {
            let module_address = Into::<u8, felt252>::into(i).try_into().unwrap();
            mock_call(module_address, selector!("is_plug_and_play"), true, 1);
            mock_call(module_address, selector!("can_compliance_bind"), true, 1);
            mock_call(module_address, selector!("bind_compliance"), (), 1);
            setup.compliance.add_module(module_address);
        };
        // adding 26-th element should fail, counting start from 1
        let last_module = starknet::contract_address_const::<26>();
        mock_call(last_module, selector!("is_plug_and_play"), true, 1);
        mock_call(last_module, selector!("can_compliance_bind"), true, 1);
        mock_call(last_module, selector!("bind_compliance"), (), 1);
        setup.compliance.add_module(last_module);
    }
}

pub mod remove_module {
    use compliance::{
        imodular_compliance::IModularComplianceDispatcherTrait,
        modular_compliance::ModularCompliance,
    };
    use core::num::traits::Zero;
    use snforge_std::{
        EventSpyAssertionsTrait, mock_call, spy_events, start_cheat_caller_address,
        stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_the_owner() {
        let setup = setup();

        start_cheat_caller_address(setup.compliance.contract_address, setup.another_wallet);
        setup.compliance.remove_module(Zero::zero());
        stop_cheat_caller_address(setup.compliance.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Module address zero')]
    fn test_should_panic_when_module_is_zero_address() {
        let setup = setup();

        setup.compliance.remove_module(Zero::zero());
    }


    #[test]
    #[should_panic(expected: 'Module not bound')]
    fn test_should_panic_when_module_not_bound() {
        let setup = setup();
        let module_address = starknet::contract_address_const::<'MODULE'>();
        setup.compliance.remove_module(module_address);
    }

    #[test]
    fn test_should_remove_module_when_module_is_bound() {
        let setup = setup();
        let module_address = starknet::contract_address_const::<'MODULE'>();
        mock_call(module_address, selector!("is_plug_and_play"), true, 1);
        mock_call(module_address, selector!("can_compliance_bind"), true, 1);
        mock_call(module_address, selector!("bind_compliance"), (), 1);

        setup.compliance.add_module(module_address);

        let mut spy = spy_events();

        mock_call(module_address, selector!("unbind_compliance"), (), 1);
        setup.compliance.remove_module(module_address);

        assert(!setup.compliance.is_module_bound(module_address), 'Module not removed');

        spy
            .assert_emitted(
                @array![
                    (
                        setup.compliance.contract_address,
                        ModularCompliance::Event::ModuleRemoved(
                            ModularCompliance::ModuleRemoved { module: module_address },
                        ),
                    ),
                ],
            );
    }
}

pub mod transferred {
    use compliance::imodular_compliance::IModularComplianceDispatcherTrait;
    use core::num::traits::Zero;
    use super::{bind_modules_and_token, setup};

    #[test]
    #[should_panic(expected: 'Only token bound can call')]
    fn test_should_panic_when_caller_is_not_bound_token() {
        let setup = setup();

        setup.compliance.transferred(Zero::zero(), Zero::zero(), Zero::zero());
    }

    #[test]
    #[should_panic(expected: 'Zero address')]
    fn test_should_panic_when_from_address_is_zero() {
        let setup = setup();
        bind_modules_and_token(@setup);
        setup.compliance.transferred(Zero::zero(), setup.bob, 10);
    }

    #[test]
    #[should_panic(expected: 'Zero address')]
    fn test_should_panic_when_to_address_is_zero() {
        let setup = setup();
        bind_modules_and_token(@setup);
        setup.compliance.transferred(setup.alice, Zero::zero(), 10);
    }

    #[test]
    #[should_panic(expected: 'No value transfer')]
    fn test_should_panic_when_amount_is_zero() {
        let setup = setup();
        bind_modules_and_token(@setup);
        setup.compliance.transferred(setup.alice, setup.bob, Zero::zero());
    }

    #[test]
    fn test_should_update_the_modules_when_amount_gt_zero() {
        let setup = setup();
        bind_modules_and_token(@setup);

        setup.compliance.transferred(setup.alice, setup.bob, 10);
    }
}

pub mod created {
    use compliance::imodular_compliance::IModularComplianceDispatcherTrait;
    use core::num::traits::Zero;
    use super::{bind_modules_and_token, setup};

    #[test]
    #[should_panic(expected: 'Only token bound can call')]
    fn test_should_panic_when_caller_is_not_bound_token() {
        let setup = setup();

        setup.compliance.created(Zero::zero(), Zero::zero());
    }

    #[test]
    #[should_panic(expected: 'Zero address')]
    fn test_should_panic_when_to_address_is_zero() {
        let setup = setup();
        bind_modules_and_token(@setup);
        setup.compliance.created(Zero::zero(), 10);
    }

    #[test]
    #[should_panic(expected: 'No value transfer')]
    fn test_should_panic_when_amount_is_zero() {
        let setup = setup();
        bind_modules_and_token(@setup);
        setup.compliance.created(setup.bob, Zero::zero());
    }

    #[test]
    fn test_should_update_the_modules_when_amount_gt_zero() {
        let setup = setup();
        bind_modules_and_token(@setup);
        setup.compliance.created(setup.bob, 10);
    }
}

pub mod destroyed {
    use compliance::imodular_compliance::IModularComplianceDispatcherTrait;
    use core::num::traits::Zero;
    use super::{bind_modules_and_token, setup};

    #[test]
    #[should_panic(expected: 'Only token bound can call')]
    fn test_should_panic_when_caller_is_not_bound_token() {
        let setup = setup();

        setup.compliance.destroyed(Zero::zero(), Zero::zero());
    }

    #[test]
    #[should_panic(expected: 'Zero address')]
    fn test_should_panic_when_from_address_is_zero() {
        let setup = setup();
        bind_modules_and_token(@setup);
        setup.compliance.destroyed(Zero::zero(), 10);
    }

    #[test]
    #[should_panic(expected: 'No value transfer')]
    fn test_should_panic_when_amount_is_zero() {
        let setup = setup();
        bind_modules_and_token(@setup);
        setup.compliance.destroyed(setup.alice, Zero::zero());
    }

    #[test]
    fn test_should_update_the_modules_when_amount_gt_zero() {
        let setup = setup();
        bind_modules_and_token(@setup);
        setup.compliance.destroyed(setup.alice, 10);
    }
}

pub mod call_module_function {
    use compliance::{
        imodular_compliance::IModularComplianceDispatcherTrait,
        modular_compliance::ModularCompliance,
    };
    use core::num::traits::Zero;
    use snforge_std::{
        EventSpyAssertionsTrait, mock_call, spy_events, start_cheat_caller_address,
        stop_cheat_caller_address,
    };
    use super::{bind_modules_and_token, setup};

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_caller_is_not_owner() {
        let setup = setup();

        start_cheat_caller_address(setup.compliance.contract_address, setup.another_wallet);
        setup.compliance.call_module_function(Zero::zero(), [].span(), Zero::zero());
        stop_cheat_caller_address(setup.compliance.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Only bound module can call')]
    fn test_should_panic_when_module_is_not_bound() {
        let setup = setup();

        setup.compliance.call_module_function(Zero::zero(), [].span(), Zero::zero());
    }

    #[test]
    fn test_should_call_module_function() {
        let setup = setup();
        let (module, _) = bind_modules_and_token(@setup);
        let mut spy = spy_events();

        let selector = selector!("dummy_selector");
        mock_call(module, selector, (), 1);
        setup.compliance.call_module_function(selector, [].span(), module);

        spy
            .assert_emitted(
                @array![
                    (
                        setup.compliance.contract_address,
                        ModularCompliance::Event::ModuleInteraction(
                            ModularCompliance::ModuleInteraction { target: module, selector },
                        ),
                    ),
                ],
            );
    }
}

pub mod can_transfer {
    use compliance::imodular_compliance::IModularComplianceDispatcherTrait;
    use snforge_std::mock_call;
    use super::{bind_modules_and_token, setup};

    #[test]
    fn test_should_return_true_if_all_modules_return_true() {
        let setup = setup();
        bind_modules_and_token(@setup);
        let can_tranfer = setup
            .compliance
            .can_transfer(
                starknet::contract_address_const::<'ANY_FROM'>(),
                starknet::contract_address_const::<'ANY_TO'>(),
                10,
            );
        assert(can_tranfer, 'Cannot transfer!');
    }

    #[test]
    fn test_should_return_false_if_single_module_return_false() {
        let setup = setup();
        let (first_module, _) = bind_modules_and_token(@setup);
        mock_call(first_module, selector!("module_check"), false, 1);

        let can_tranfer = setup
            .compliance
            .can_transfer(
                starknet::contract_address_const::<'ANY_FROM'>(),
                starknet::contract_address_const::<'ANY_TO'>(),
                10,
            );
        assert(!can_tranfer, 'Can transfer!');
    }
}
