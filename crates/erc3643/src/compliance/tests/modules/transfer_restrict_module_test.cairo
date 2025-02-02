use crate::compliance::tests::modular_compliance_test::{Setup as MCSetup, setup as mc_setup};
use crate::compliance::{
    imodular_compliance::IModularComplianceDispatcherTrait,
    modules::{
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
        transfer_restrict_module::ITransferRestrictModuleDispatcher,
    },
};
use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;

#[derive(Drop, Copy)]
struct Setup {
    mc_setup: MCSetup,
    module: ITransferRestrictModuleDispatcher,
    mock_contract: ContractAddress,
}

pub fn setup() -> Setup {
    let mc_setup = mc_setup();

    let compliance_module_contract = declare("TransferRestrictModule").unwrap().contract_class();
    let (deployed_address, _) = compliance_module_contract
        .deploy(@array![starknet::get_contract_address().into()])
        .unwrap();

    mc_setup.compliance.add_module(deployed_address);

    let (mock_contract, _) = declare("MockContract")
        .unwrap()
        .contract_class()
        .deploy(@array![])
        .unwrap();

    mc_setup.compliance.bind_token(mock_contract);

    Setup {
        mc_setup,
        module: ITransferRestrictModuleDispatcher { contract_address: deployed_address },
        mock_contract,
    }
}

#[test]
fn test_should_deploy_the_transfer_restrict_contract_and_bind_it_to_the_compliance() {
    let setup = setup();
    assert(
        setup.mc_setup.compliance.is_module_bound(setup.module.contract_address),
        'Compliance module not bound',
    );
}

#[test]
fn test_should_return_the_name_of_the_module() {
    let setup = setup();
    let module_dispatcher = IModuleDispatcher { contract_address: setup.module.contract_address };
    assert(module_dispatcher.name() == "TransferRestrictModule", 'Names does not match!');
}


#[test]
fn test_is_plug_and_play_should_return_true() {
    let setup = setup();
    let module_dispatcher = IModuleDispatcher { contract_address: setup.module.contract_address };
    assert(module_dispatcher.is_plug_and_play(), 'Is not plug and play');
}

#[test]
fn test_can_compliance_bind_should_return_true() {
    let setup = setup();
    let module_dispatcher = IModuleDispatcher { contract_address: setup.module.contract_address };
    assert(
        module_dispatcher.can_compliance_bind(setup.mc_setup.compliance.contract_address),
        'Compliance cannot bind',
    );
}

#[test]
fn test_should_return_owner() {
    let setup = setup();
    let ownable_dispatcher = IOwnableDispatcher { contract_address: setup.module.contract_address };
    assert(ownable_dispatcher.owner() == starknet::get_contract_address(), 'Owner does not match');
}

pub mod transfer_ownership {
    use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_not_called_by_owner() {
        let setup = setup();

        let ownable_dispatcher = IOwnableDispatcher {
            contract_address: setup.module.contract_address,
        };
        start_cheat_caller_address(ownable_dispatcher.contract_address, setup.mc_setup.bob);
        ownable_dispatcher.transfer_ownership(setup.mc_setup.alice);
        stop_cheat_caller_address(ownable_dispatcher.contract_address);
    }

    #[test]
    fn test_should_transfer_ownership_when_called_by_owner() {
        let setup = setup();

        let ownable_dispatcher = IOwnableDispatcher {
            contract_address: setup.module.contract_address,
        };
        ownable_dispatcher.transfer_ownership(setup.mc_setup.alice);
        assert(ownable_dispatcher.owner() == setup.mc_setup.alice, 'Ownership didnt transferred');
    }
}

pub mod upgrade {
    use openzeppelin_upgrades::interface::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};
    use snforge_std::{get_class_hash, start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_panic_when_not_called_by_owner() {
        let setup = setup();
        let upgradeable_dispatcher = IUpgradeableDispatcher {
            contract_address: setup.module.contract_address,
        };
        let new_class_hash = get_class_hash(setup.mock_contract);

        start_cheat_caller_address(upgradeable_dispatcher.contract_address, setup.mc_setup.bob);
        upgradeable_dispatcher.upgrade(new_class_hash);
        stop_cheat_caller_address(upgradeable_dispatcher.contract_address);
    }

    #[test]
    fn test_should_upgrade() {
        let setup = setup();
        let upgradeable_dispatcher = IUpgradeableDispatcher {
            contract_address: setup.module.contract_address,
        };
        let new_class_hash = get_class_hash(setup.mock_contract);

        upgradeable_dispatcher.upgrade(new_class_hash);
        assert(
            get_class_hash(upgradeable_dispatcher.contract_address) == new_class_hash,
            'Contract not upgraded',
        );
    }
}

pub mod allow_user {
    use crate::compliance::modules::transfer_restrict_module::{
        ITransferRestrictModuleDispatcherTrait, TransferRestrictModule,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        let setup = setup();

        setup.module.allow_user(setup.mc_setup.alice);
    }

    #[test]
    fn test_should_allow_user() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;
        let user = setup.mc_setup.alice;

        let mut spy = spy_events();

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.allow_user(user);
        stop_cheat_caller_address(setup.module.contract_address);

        assert(setup.module.is_user_allowed(compliance, user), 'User not allowed');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TransferRestrictModule::Event::UserAllowed(
                            TransferRestrictModule::UserAllowed { compliance, user_address: user },
                        ),
                    ),
                ],
            );
    }
}

pub mod batch_allow_users {
    use crate::compliance::modules::transfer_restrict_module::{
        ITransferRestrictModuleDispatcherTrait, TransferRestrictModule,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        let setup = setup();

        setup.module.batch_allow_users([setup.mc_setup.alice].span());
    }

    #[test]
    fn test_should_allow_users() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;

        let mut spy = spy_events();

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.batch_allow_users([setup.mc_setup.alice, setup.mc_setup.bob].span());
        stop_cheat_caller_address(setup.module.contract_address);

        assert(setup.module.is_user_allowed(compliance, setup.mc_setup.alice), 'Alice not allowed');
        assert(setup.module.is_user_allowed(compliance, setup.mc_setup.bob), 'Bob not allowed');

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TransferRestrictModule::Event::UserAllowed(
                            TransferRestrictModule::UserAllowed {
                                compliance, user_address: setup.mc_setup.alice,
                            },
                        ),
                    ),
                    (
                        setup.module.contract_address,
                        TransferRestrictModule::Event::UserAllowed(
                            TransferRestrictModule::UserAllowed {
                                compliance, user_address: setup.mc_setup.bob,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod disallow_user {
    use crate::compliance::modules::transfer_restrict_module::{
        ITransferRestrictModuleDispatcherTrait, TransferRestrictModule,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        let setup = setup();

        setup.module.disallow_user(setup.mc_setup.alice);
    }

    #[test]
    fn test_should_disallow_user() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;
        let user = setup.mc_setup.alice;

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.allow_user(user);

        let mut spy = spy_events();
        setup.module.disallow_user(user);
        stop_cheat_caller_address(setup.module.contract_address);

        assert(!setup.module.is_user_allowed(compliance, user), 'User still allowed');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TransferRestrictModule::Event::UserDisallowed(
                            TransferRestrictModule::UserDisallowed {
                                compliance, user_address: user,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod batch_disallow_users {
    use crate::compliance::modules::transfer_restrict_module::{
        ITransferRestrictModuleDispatcherTrait, TransferRestrictModule,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        let setup = setup();

        setup.module.batch_disallow_users([setup.mc_setup.alice].span());
    }

    #[test]
    fn test_should_disallow_users() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.batch_allow_users([setup.mc_setup.alice, setup.mc_setup.bob].span());

        let mut spy = spy_events();
        setup.module.batch_disallow_users([setup.mc_setup.alice, setup.mc_setup.bob].span());
        stop_cheat_caller_address(setup.module.contract_address);

        assert(
            !setup.module.is_user_allowed(compliance, setup.mc_setup.alice), 'Alice still allowed',
        );
        assert(!setup.module.is_user_allowed(compliance, setup.mc_setup.bob), 'Bob still allowed');

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TransferRestrictModule::Event::UserDisallowed(
                            TransferRestrictModule::UserDisallowed {
                                compliance, user_address: setup.mc_setup.alice,
                            },
                        ),
                    ),
                    (
                        setup.module.contract_address,
                        TransferRestrictModule::Event::UserDisallowed(
                            TransferRestrictModule::UserDisallowed {
                                compliance, user_address: setup.mc_setup.bob,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod is_user_allowed {
    use crate::compliance::modules::transfer_restrict_module::ITransferRestrictModuleDispatcherTrait;
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    fn test_should_return_true_when_user_is_allowed() {
        let setup = setup();
        let compliance = setup.mc_setup.compliance.contract_address;
        let user = setup.mc_setup.alice;

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.allow_user(user);
        stop_cheat_caller_address(setup.module.contract_address);

        assert(setup.module.is_user_allowed(compliance, user), 'User not allowed');
    }

    #[test]
    fn test_should_return_false_when_user_is_not_allowed() {
        let setup = setup();

        assert(
            !setup
                .module
                .is_user_allowed(setup.mc_setup.compliance.contract_address, setup.mc_setup.alice),
            'User shouldnt be allowed',
        );
    }
}

pub mod module_check {
    use core::num::traits::Zero;
    use crate::compliance::modules::{
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
        transfer_restrict_module::ITransferRestrictModuleDispatcherTrait,
    };
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    fn test_should_return_false_when_sender_and_receiver_are_not_allowed() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let check_result = module_dispatcher.module_check(from, to, 10, compliance);
        assert(!check_result, 'Should return false');
    }

    #[test]
    fn test_should_return_true_when_sender_is_allowed() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.allow_user(from);
        stop_cheat_caller_address(setup.module.contract_address);

        let check_result = module_dispatcher.module_check(from, to, 10, compliance);
        assert(check_result, 'Should return true');
    }

    #[test]
    fn test_should_return_true_when_receiver_is_allowed() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = setup.mc_setup.bob;

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.allow_user(to);
        stop_cheat_caller_address(setup.module.contract_address);

        let check_result = module_dispatcher.module_check(from, to, 10, compliance);
        assert(check_result, 'Should return true');
    }

    #[test]
    fn test_should_return_true_when_sender_is_null_address() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        let from = Zero::zero();
        let to = setup.mc_setup.bob;

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let check_result = module_dispatcher.module_check(from, to, 10, compliance);
        assert(check_result, 'Should return true');
    }

    #[test]
    fn test_should_return_true_when_receiver_is_null_address() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        let from = setup.mc_setup.alice;
        let to = Zero::zero();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let check_result = module_dispatcher.module_check(from, to, 10, compliance);
        assert(check_result, 'Should return true');
    }
}

pub mod module_burn_action {
    use crate::compliance::modules::imodule::{IModuleDispatcher, IModuleDispatcherTrait};
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        module_dispatcher.module_burn_action(setup.mc_setup.another_wallet, 10);
    }

    #[test]
    fn test_should_do_nothing() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        module_dispatcher.module_burn_action(setup.mc_setup.another_wallet, 10);
        stop_cheat_caller_address(setup.module.contract_address);
    }
}

pub mod module_mint_action {
    use crate::compliance::modules::imodule::{IModuleDispatcher, IModuleDispatcherTrait};
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        module_dispatcher.module_mint_action(setup.mc_setup.another_wallet, 10);
    }

    #[test]
    fn test_should_do_nothing() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        module_dispatcher.module_mint_action(setup.mc_setup.another_wallet, 10);
        stop_cheat_caller_address(setup.module.contract_address);
    }
}

pub mod module_transfer_action {
    use crate::compliance::modules::imodule::{IModuleDispatcher, IModuleDispatcherTrait};
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        module_dispatcher.module_transfer_action(setup.mc_setup.alice, setup.mc_setup.bob, 10);
    }

    #[test]
    fn test_should_do_nothing() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        module_dispatcher.module_transfer_action(setup.mc_setup.alice, setup.mc_setup.bob, 10);
        stop_cheat_caller_address(setup.module.contract_address);
    }
}
