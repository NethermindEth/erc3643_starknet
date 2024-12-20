use compliance::{
    imodular_compliance::IModularComplianceDispatcherTrait,
    modules::{
        conditional_transfer_module::IConditionalTransferModuleDispatcher,
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
    },
};
use crate::modular_compliance_test::{Setup as MCSetup, setup as mc_setup};
use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;

#[derive(Drop, Copy)]
struct Setup {
    mc_setup: MCSetup,
    module: IConditionalTransferModuleDispatcher,
    mock_contract: ContractAddress,
}

fn setup() -> Setup {
    let mc_setup = mc_setup();

    let compliance_module_contract = declare("ConditionalTransferModule").unwrap().contract_class();
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
        module: IConditionalTransferModuleDispatcher { contract_address: deployed_address },
        mock_contract,
    }
}

#[test]
fn test_should_return_the_name_of_the_module() {
    let setup = setup();
    let module_dispatcher = IModuleDispatcher { contract_address: setup.module.contract_address };
    assert(module_dispatcher.name() == "ConditionalTransferModule", 'Names does not match!');
}


#[test]
fn test_plug_and_play_should_return_true() {
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

pub mod approve_transfer {
    use compliance::modules::conditional_transfer_module::{
        ConditionalTransferModule, IConditionalTransferModuleDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_sender_is_not_the_compliance() {
        let setup = setup();

        setup.module.approve_transfer(setup.mc_setup.another_wallet, setup.mc_setup.alice, 10);
    }

    #[test]
    fn test_should_approve_transfer() {
        let setup = setup();

        let mut spy = spy_events();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.approve_transfer(setup.mc_setup.alice, setup.mc_setup.bob, 10);
        stop_cheat_caller_address(setup.module.contract_address);
        let transfer_id = setup
            .module
            .calculate_transfer_hash(
                setup.mc_setup.alice, setup.mc_setup.bob, 10, setup.mock_contract,
            );
        assert(
            setup
                .module
                .is_transfer_approved(setup.mc_setup.compliance.contract_address, transfer_id),
            'Transfer is not approved',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        ConditionalTransferModule::Event::TransferApproved(
                            ConditionalTransferModule::TransferApproved {
                                from: setup.mc_setup.alice,
                                to: setup.mc_setup.bob,
                                amount: 10,
                                token: setup.mock_contract,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod unapprove_transfer {
    use compliance::modules::conditional_transfer_module::{
        ConditionalTransferModule, IConditionalTransferModuleDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_sender_is_not_the_compliance() {
        let setup = setup();

        setup.module.unapprove_transfer(setup.mc_setup.another_wallet, setup.mc_setup.alice, 10);
    }

    #[test]
    #[should_panic(expected: 'Not Approved')]
    fn test_should_panic_when_not_approved() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.unapprove_transfer(setup.mc_setup.alice, setup.mc_setup.bob, 10);
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    fn test_should_unapprove_transfer() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.approve_transfer(setup.mc_setup.alice, setup.mc_setup.bob, 10);

        let mut spy = spy_events();

        setup.module.unapprove_transfer(setup.mc_setup.alice, setup.mc_setup.bob, 10);
        stop_cheat_caller_address(setup.module.contract_address);
        let transfer_id = setup
            .module
            .calculate_transfer_hash(
                setup.mc_setup.alice, setup.mc_setup.bob, 10, setup.mock_contract,
            );
        assert(
            !setup
                .module
                .is_transfer_approved(setup.mc_setup.compliance.contract_address, transfer_id),
            'Transfer is not unapproved',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        ConditionalTransferModule::Event::ApprovalRemoved(
                            ConditionalTransferModule::ApprovalRemoved {
                                from: setup.mc_setup.alice,
                                to: setup.mc_setup.bob,
                                amount: 10,
                                token: setup.mock_contract,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod batch_approve_transfers {
    use compliance::modules::conditional_transfer_module::{
        ConditionalTransferModule, IConditionalTransferModuleDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_sender_is_not_the_compliance() {
        let setup = setup();

        setup.module.batch_approve_transfers([].span(), [].span(), [].span());
    }


    #[test]
    fn test_should_approve_the_transfers_when_sender_is_the_compliance() {
        let setup = setup();

        let from_addresses = array![
            starknet::contract_address_const::<'FROM_FIRST'>(),
            starknet::contract_address_const::<'FROM_SECOND'>(),
        ];

        let to_addresses = array![
            starknet::contract_address_const::<'TO_FIRST'>(),
            starknet::contract_address_const::<'TO_SECOND'>(),
        ];

        let amounts = array![10, 20];

        let mut spy = spy_events();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup
            .module
            .batch_approve_transfers(from_addresses.span(), to_addresses.span(), amounts.span());
        stop_cheat_caller_address(setup.module.contract_address);

        for i in 0..from_addresses.len() {
            let transfer_id = setup
                .module
                .calculate_transfer_hash(
                    *from_addresses.at(i), *to_addresses.at(i), *amounts.at(i), setup.mock_contract,
                );
            assert(
                setup
                    .module
                    .is_transfer_approved(setup.mc_setup.compliance.contract_address, transfer_id),
                'Transfer is not approved',
            );

            spy
                .assert_emitted(
                    @array![
                        (
                            setup.module.contract_address,
                            ConditionalTransferModule::Event::TransferApproved(
                                ConditionalTransferModule::TransferApproved {
                                    from: *from_addresses.at(i),
                                    to: *to_addresses.at(i),
                                    amount: *amounts.at(i),
                                    token: setup.mock_contract,
                                },
                            ),
                        ),
                    ],
                );
        };
    }
}

pub mod batch_unapprove_transfers {
    use compliance::modules::conditional_transfer_module::{
        ConditionalTransferModule, IConditionalTransferModuleDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_sender_is_not_the_compliance() {
        let setup = setup();

        setup.module.batch_unapprove_transfers([].span(), [].span(), [].span());
    }

    #[test]
    #[should_panic(expected: 'Not Approved')]
    fn test_should_panic_when_transfer_is_not_approved() {
        let setup = setup();

        let from_addresses = array![
            starknet::contract_address_const::<'FROM_FIRST'>(),
            starknet::contract_address_const::<'FROM_SECOND'>(),
        ];

        let to_addresses = array![
            starknet::contract_address_const::<'TO_FIRST'>(),
            starknet::contract_address_const::<'TO_SECOND'>(),
        ];

        let amounts = array![10, 20];

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup
            .module
            .batch_unapprove_transfers(from_addresses.span(), to_addresses.span(), amounts.span());
        stop_cheat_caller_address(setup.module.contract_address);
    }


    #[test]
    fn test_should_unapprove_the_transfers() {
        let setup = setup();

        let from_addresses = array![
            starknet::contract_address_const::<'FROM_FIRST'>(),
            starknet::contract_address_const::<'FROM_SECOND'>(),
        ];

        let to_addresses = array![
            starknet::contract_address_const::<'TO_FIRST'>(),
            starknet::contract_address_const::<'TO_SECOND'>(),
        ];

        let amounts = array![10, 20];

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup
            .module
            .batch_approve_transfers(from_addresses.span(), to_addresses.span(), amounts.span());

        let mut spy = spy_events();
        setup
            .module
            .batch_unapprove_transfers(from_addresses.span(), to_addresses.span(), amounts.span());

        stop_cheat_caller_address(setup.module.contract_address);

        for i in 0..from_addresses.len() {
            let transfer_id = setup
                .module
                .calculate_transfer_hash(
                    *from_addresses.at(i), *to_addresses.at(i), *amounts.at(i), setup.mock_contract,
                );
            assert(
                !setup
                    .module
                    .is_transfer_approved(setup.mc_setup.compliance.contract_address, transfer_id),
                'Transfer is not approved',
            );

            spy
                .assert_emitted(
                    @array![
                        (
                            setup.module.contract_address,
                            ConditionalTransferModule::Event::ApprovalRemoved(
                                ConditionalTransferModule::ApprovalRemoved {
                                    from: *from_addresses.at(i),
                                    to: *to_addresses.at(i),
                                    amount: *amounts.at(i),
                                    token: setup.mock_contract,
                                },
                            ),
                        ),
                    ],
                );
        };
    }
}

pub mod module_check {
    use compliance::{
        modules::{
            conditional_transfer_module::IConditionalTransferModuleDispatcherTrait,
            imodule::{IModuleDispatcher, IModuleDispatcherTrait},
        },
    };
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;


    #[test]
    fn test_should_return_false_when_transfer_is_not_approved() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        let result = module_dispatcher
            .module_check(
                setup.mc_setup.alice,
                setup.mc_setup.bob,
                10,
                setup.mc_setup.compliance.contract_address,
            );
        assert(!result, 'Module check should fail');
    }


    #[test]
    fn test_should_return_true_when_transfer_is_approved() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.approve_transfer(setup.mc_setup.alice, setup.mc_setup.bob, 10);
        stop_cheat_caller_address(setup.module.contract_address);

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        let result = module_dispatcher
            .module_check(
                setup.mc_setup.alice,
                setup.mc_setup.bob,
                10,
                setup.mc_setup.compliance.contract_address,
            );
        assert(result, 'Module check should fail');
    }
}

pub mod module_burn_action {
    use compliance::modules::imodule::{IModuleDispatcher, IModuleDispatcherTrait};
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
    use compliance::modules::imodule::{IModuleDispatcher, IModuleDispatcherTrait};
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
    use compliance::{
        modules::{
            conditional_transfer_module::{
                ConditionalTransferModule, IConditionalTransferModuleDispatcherTrait,
            },
            imodule::{IModuleDispatcher, IModuleDispatcherTrait},
        },
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
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
    fn test_should_do_nothing_when_transfer_is_not_approved() {
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

    #[test]
    fn test_should_remove_the_transfer_approval() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        let transfer_id = setup
            .module
            .calculate_transfer_hash(
                setup.mc_setup.alice, setup.mc_setup.bob, 10, setup.mock_contract,
            );

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.approve_transfer(setup.mc_setup.alice, setup.mc_setup.bob, 10);
        let approval_pre = setup
            .module
            .get_transfer_approvals(setup.mc_setup.compliance.contract_address, transfer_id);

        let mut spy = spy_events();

        module_dispatcher.module_transfer_action(setup.mc_setup.alice, setup.mc_setup.bob, 10);
        stop_cheat_caller_address(setup.module.contract_address);

        let approval_after = setup
            .module
            .get_transfer_approvals(setup.mc_setup.compliance.contract_address, transfer_id);
        assert(approval_pre - 1 == approval_after, 'Tranfer approval not removed');

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        ConditionalTransferModule::Event::ApprovalRemoved(
                            ConditionalTransferModule::ApprovalRemoved {
                                from: setup.mc_setup.alice,
                                to: setup.mc_setup.bob,
                                amount: 10,
                                token: setup.mock_contract,
                            },
                        ),
                    ),
                ],
            );
    }
}
