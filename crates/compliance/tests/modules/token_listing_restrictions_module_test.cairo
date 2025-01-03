use compliance::{
    imodular_compliance::IModularComplianceDispatcherTrait,
    modules::{
        imodule::{IModuleDispatcher, IModuleDispatcherTrait},
        token_listing_restrictions_module::ITokenListingRestrictionsModuleDispatcher,
    },
};
use crate::modular_compliance_test::{Setup as MCSetup, setup as mc_setup};
use mocks::mock_contract::{IMockContractDispatcher, IMockContractDispatcherTrait};
use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;

#[derive(Drop, Copy)]
struct Setup {
    mc_setup: MCSetup,
    module: ITokenListingRestrictionsModuleDispatcher,
    mock_contract: ContractAddress,
    alice_id: ContractAddress,
    bob_id: ContractAddress,
}

pub fn setup() -> Setup {
    let mc_setup = mc_setup();

    let compliance_module_contract = declare("TokenListingRestrictionsModule")
        .unwrap()
        .contract_class();
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

    let alice_id = starknet::contract_address_const::<'ALICE_IDENTITY'>();
    let bob_id = starknet::contract_address_const::<'BOB_IDENTITY'>();

    let mock_dispatcher = IMockContractDispatcher { contract_address: mock_contract };
    mock_dispatcher.set_identity(mc_setup.alice, alice_id);
    mock_dispatcher.set_identity(mc_setup.bob, bob_id);

    Setup {
        mc_setup,
        module: ITokenListingRestrictionsModuleDispatcher { contract_address: deployed_address },
        mock_contract,
        alice_id,
        bob_id,
    }
}

#[test]
fn test_should_deploy_the_token_listing_restrictions_contract_and_bind_it_to_the_compliance() {
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
    assert(module_dispatcher.name() == "TokenListingRestrictionsModule", 'Names does not match!');
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

pub mod configure_token {
    use compliance::modules::token_listing_restrictions_module::{
        ITokenListingRestrictionsModuleDispatcherTrait, ListingType, TokenListingRestrictionsModule,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        let setup = setup();

        setup.module.configure_token(ListingType::WHITELISTING);
    }

    #[test]
    #[should_panic(expected: 'Invalid listing config params')]
    fn test_should_panic_when_given_listing_type_is_not_configured() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.configure_token(ListingType::NOT_CONFIGURED);
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    fn test_should_configure_the_token_when_token_is_not_configured_before() {
        let setup = setup();

        let mut spy = spy_events();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.configure_token(ListingType::WHITELISTING);
        stop_cheat_caller_address(setup.module.contract_address);

        match setup.module.get_token_listing_type(setup.mock_contract) {
            ListingType::WHITELISTING => {},
            _ => panic!("Listing type didnt set"),
        }

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TokenListingRestrictionsModule::Event::TokenListingConfigured(
                            TokenListingRestrictionsModule::TokenListingConfigured {
                                token_address: setup.mock_contract,
                                listing_type: ListingType::WHITELISTING,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic(expected: 'Token already configured')]
    fn test_should_panic_when_token_already_configured() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.configure_token(ListingType::WHITELISTING);
        /// Configuring second time should panic
        setup.module.configure_token(ListingType::WHITELISTING);
        stop_cheat_caller_address(setup.module.contract_address);
    }
}

pub mod list_token {
    use compliance::modules::token_listing_restrictions_module::{
        ITokenListingRestrictionsModuleDispatcherTrait, InvestorAddressType, ListingType,
        TokenListingRestrictionsModule,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Token is not configured')]
    fn test_should_panic_when_token_is_not_configured() {
        let setup = setup();

        setup.module.list_token(setup.mock_contract, InvestorAddressType::ONCHAINID);
    }

    #[test]
    #[should_panic(expected: 'Identity not found')]
    fn test_should_panic_when_identity_does_not_exist() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.configure_token(ListingType::WHITELISTING);
        stop_cheat_caller_address(setup.module.contract_address);

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.another_wallet);
        setup.module.list_token(setup.mock_contract, InvestorAddressType::ONCHAINID);
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    fn test_should_list_the_token_when_investor_address_type_is_wallet() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.configure_token(ListingType::WHITELISTING);
        stop_cheat_caller_address(setup.module.contract_address);

        let mut spy = spy_events();

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.alice);
        setup.module.list_token(setup.mock_contract, InvestorAddressType::WALLET);
        stop_cheat_caller_address(setup.module.contract_address);

        assert(
            setup.module.get_investor_listing_status(setup.mock_contract, setup.mc_setup.alice),
            'Token not listed',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TokenListingRestrictionsModule::Event::TokenListed(
                            TokenListingRestrictionsModule::TokenListed {
                                token_address: setup.mock_contract,
                                investor_address: setup.mc_setup.alice,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_should_list_the_token_when_identity_exists() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.configure_token(ListingType::WHITELISTING);
        stop_cheat_caller_address(setup.module.contract_address);

        let mut spy = spy_events();

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.alice);
        setup.module.list_token(setup.mock_contract, InvestorAddressType::ONCHAINID);
        stop_cheat_caller_address(setup.module.contract_address);

        assert(
            setup.module.get_investor_listing_status(setup.mock_contract, setup.alice_id),
            'Token not listed',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TokenListingRestrictionsModule::Event::TokenListed(
                            TokenListingRestrictionsModule::TokenListed {
                                token_address: setup.mock_contract,
                                investor_address: setup.alice_id,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic(expected: 'Token already listed')]
    fn test_should_panic_when_token_is_listed_before() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.configure_token(ListingType::WHITELISTING);
        stop_cheat_caller_address(setup.module.contract_address);

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.alice);
        setup.module.list_token(setup.mock_contract, InvestorAddressType::ONCHAINID);
        /// Listing second time should panic
        setup.module.list_token(setup.mock_contract, InvestorAddressType::ONCHAINID);
        stop_cheat_caller_address(setup.module.contract_address);
    }
}

pub mod batch_list_tokens {
    use compliance::modules::token_listing_restrictions_module::{
        ITokenListingRestrictionsModuleDispatcherTrait, InvestorAddressType, ListingType,
        TokenListingRestrictionsModule,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Token is not configured')]
    fn test_should_panic_when_token_is_not_configured() {
        let setup = setup();

        setup
            .module
            .batch_list_tokens([setup.mock_contract].span(), InvestorAddressType::ONCHAINID);
    }

    #[test]
    #[should_panic(expected: 'Token already listed')]
    fn test_should_panic_when_token_is_listed_before() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.configure_token(ListingType::WHITELISTING);
        stop_cheat_caller_address(setup.module.contract_address);

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.alice);
        setup.module.list_token(setup.mock_contract, InvestorAddressType::ONCHAINID);

        setup
            .module
            .batch_list_tokens([setup.mock_contract].span(), InvestorAddressType::ONCHAINID);
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    fn test_should_list_tokens_when_investor_address_type_is_wallet() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.configure_token(ListingType::WHITELISTING);
        stop_cheat_caller_address(setup.module.contract_address);

        let mut spy = spy_events();

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.alice);
        setup.module.batch_list_tokens([setup.mock_contract].span(), InvestorAddressType::WALLET);
        stop_cheat_caller_address(setup.module.contract_address);

        assert(
            setup.module.get_investor_listing_status(setup.mock_contract, setup.mc_setup.alice),
            'Token not listed',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TokenListingRestrictionsModule::Event::TokenListed(
                            TokenListingRestrictionsModule::TokenListed {
                                token_address: setup.mock_contract,
                                investor_address: setup.mc_setup.alice,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_should_list_tokens_when_investor_address_type_is_onchainid() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.configure_token(ListingType::WHITELISTING);
        stop_cheat_caller_address(setup.module.contract_address);

        let mut spy = spy_events();

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.alice);
        setup
            .module
            .batch_list_tokens([setup.mock_contract].span(), InvestorAddressType::ONCHAINID);
        stop_cheat_caller_address(setup.module.contract_address);

        assert(
            setup.module.get_investor_listing_status(setup.mock_contract, setup.alice_id),
            'Token not listed',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TokenListingRestrictionsModule::Event::TokenListed(
                            TokenListingRestrictionsModule::TokenListed {
                                token_address: setup.mock_contract,
                                investor_address: setup.alice_id,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod unlist_token {
    use compliance::modules::token_listing_restrictions_module::{
        ITokenListingRestrictionsModuleDispatcherTrait, InvestorAddressType, ListingType,
        TokenListingRestrictionsModule,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Token is not listed')]
    fn test_should_panic_when_token_is_not_listed() {
        let setup = setup();

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.alice);
        setup.module.unlist_token(setup.mock_contract, InvestorAddressType::ONCHAINID);
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    fn test_should_unlist_the_token_when_investor_address_type_is_wallet() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.configure_token(ListingType::WHITELISTING);
        stop_cheat_caller_address(setup.module.contract_address);

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.alice);
        setup.module.list_token(setup.mock_contract, InvestorAddressType::WALLET);

        let mut spy = spy_events();
        setup.module.unlist_token(setup.mock_contract, InvestorAddressType::WALLET);
        stop_cheat_caller_address(setup.module.contract_address);

        assert(
            !setup.module.get_investor_listing_status(setup.mock_contract, setup.mc_setup.alice),
            'Token not delisted',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TokenListingRestrictionsModule::Event::TokenUnlisted(
                            TokenListingRestrictionsModule::TokenUnlisted {
                                token_address: setup.mock_contract,
                                investor_address: setup.mc_setup.alice,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_should_unlist_the_token_when_investor_address_type_is_onchainid() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.configure_token(ListingType::WHITELISTING);
        stop_cheat_caller_address(setup.module.contract_address);

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.alice);
        setup.module.list_token(setup.mock_contract, InvestorAddressType::ONCHAINID);

        let mut spy = spy_events();
        setup.module.unlist_token(setup.mock_contract, InvestorAddressType::ONCHAINID);
        stop_cheat_caller_address(setup.module.contract_address);

        assert(
            !setup.module.get_investor_listing_status(setup.mock_contract, setup.alice_id),
            'Token not delisted',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TokenListingRestrictionsModule::Event::TokenUnlisted(
                            TokenListingRestrictionsModule::TokenUnlisted {
                                token_address: setup.mock_contract,
                                investor_address: setup.alice_id,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod batch_unlist_tokens {
    use compliance::modules::token_listing_restrictions_module::{
        ITokenListingRestrictionsModuleDispatcherTrait, InvestorAddressType, ListingType,
        TokenListingRestrictionsModule,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Token is not listed')]
    fn test_should_panic_when_token_is_not_listed() {
        let setup = setup();

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.alice);
        setup
            .module
            .batch_unlist_tokens([setup.mock_contract].span(), InvestorAddressType::ONCHAINID);
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    fn test_should_unlist_tokens_when_investor_address_type_is_wallet() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.configure_token(ListingType::WHITELISTING);
        stop_cheat_caller_address(setup.module.contract_address);

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.alice);
        setup.module.list_token(setup.mock_contract, InvestorAddressType::WALLET);

        let mut spy = spy_events();
        setup.module.batch_unlist_tokens([setup.mock_contract].span(), InvestorAddressType::WALLET);
        stop_cheat_caller_address(setup.module.contract_address);

        assert(
            !setup.module.get_investor_listing_status(setup.mock_contract, setup.mc_setup.alice),
            'Token not delisted',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TokenListingRestrictionsModule::Event::TokenUnlisted(
                            TokenListingRestrictionsModule::TokenUnlisted {
                                token_address: setup.mock_contract,
                                investor_address: setup.mc_setup.alice,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_should_unlist_tokens_when_investor_address_type_is_onchainid() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.configure_token(ListingType::WHITELISTING);
        stop_cheat_caller_address(setup.module.contract_address);

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.alice);
        setup.module.list_token(setup.mock_contract, InvestorAddressType::ONCHAINID);

        let mut spy = spy_events();
        setup
            .module
            .batch_unlist_tokens([setup.mock_contract].span(), InvestorAddressType::ONCHAINID);
        stop_cheat_caller_address(setup.module.contract_address);

        assert(
            !setup.module.get_investor_listing_status(setup.mock_contract, setup.alice_id),
            'Token not delisted',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        TokenListingRestrictionsModule::Event::TokenUnlisted(
                            TokenListingRestrictionsModule::TokenUnlisted {
                                token_address: setup.mock_contract,
                                investor_address: setup.alice_id,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod get_token_listing_type {
    use compliance::modules::token_listing_restrictions_module::{
        ITokenListingRestrictionsModuleDispatcherTrait, ListingType,
    };
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    fn test_should_return_not_configured_when_token_is_not_configured() {
        let setup = setup();

        let listing_type = setup.module.get_token_listing_type(setup.mock_contract);
        match listing_type {
            ListingType::NOT_CONFIGURED => {},
            _ => panic!("Wrong listing status"),
        }
    }

    #[test]
    fn test_should_return_token_listing_type_when_token_is_configured() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.configure_token(ListingType::WHITELISTING);
        stop_cheat_caller_address(setup.module.contract_address);

        let listing_type = setup.module.get_token_listing_type(setup.mock_contract);
        match listing_type {
            ListingType::WHITELISTING => {},
            _ => panic!("Wrong listing status"),
        }
    }
}

pub mod get_investor_listing_status {
    use compliance::modules::token_listing_restrictions_module::{
        ITokenListingRestrictionsModuleDispatcherTrait, InvestorAddressType, ListingType,
    };
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    fn test_should_return_false_when_token_is_not_listed() {
        let setup = setup();

        let listing_status = setup
            .module
            .get_investor_listing_status(setup.mock_contract, setup.mc_setup.alice);
        assert(!listing_status, 'Should return false');
    }

    #[test]
    fn test_should_return_true_when_token_is_listed() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.configure_token(ListingType::WHITELISTING);
        stop_cheat_caller_address(setup.module.contract_address);

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.alice);
        setup.module.list_token(setup.mock_contract, InvestorAddressType::WALLET);
        stop_cheat_caller_address(setup.module.contract_address);

        let listing_status = setup
            .module
            .get_investor_listing_status(setup.mock_contract, setup.mc_setup.alice);
        assert(listing_status, 'Should return true');
    }
}

pub mod module_check {
    use compliance::modules::imodule::{IModuleDispatcher, IModuleDispatcherTrait};
    use compliance::modules::token_listing_restrictions_module::{
        ITokenListingRestrictionsModuleDispatcherTrait, InvestorAddressType, ListingType,
    };
    use core::num::traits::Zero;
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    fn test_should_return_true_when_receiver_is_zero_address() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let from = setup.mc_setup.alice;
        let compliance = setup.mc_setup.compliance.contract_address;

        let check_result = module_dispatcher.module_check(from, Zero::zero(), 10, compliance);
        assert(check_result, 'Should return true');
    }

    #[test]
    fn test_should_return_true_when_token_is_not_configured() {
        let setup = setup();

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let from = setup.mc_setup.bob;
        let to = setup.mc_setup.alice;
        let compliance = setup.mc_setup.compliance.contract_address;

        let check_result = module_dispatcher.module_check(from, to, 10, compliance);
        assert(check_result, 'Should return true');
    }

    #[test]
    fn test_should_return_false_when_listing_type_is_whitelisting_and_token_not_listed() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.configure_token(ListingType::WHITELISTING);
        stop_cheat_caller_address(setup.module.contract_address);

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let from = setup.mc_setup.bob;
        let to = setup.mc_setup.alice;
        let compliance = setup.mc_setup.compliance.contract_address;

        let check_result = module_dispatcher.module_check(from, to, 10, compliance);
        assert(!check_result, 'Should return false');
    }

    #[test]
    fn test_should_return_true_when_listing_type_is_whitelisting_and_token_listed_for_wallet() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.configure_token(ListingType::WHITELISTING);
        stop_cheat_caller_address(setup.module.contract_address);

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.alice);
        setup.module.list_token(setup.mock_contract, InvestorAddressType::WALLET);
        stop_cheat_caller_address(setup.module.contract_address);

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        let from = setup.mc_setup.bob;
        let to = setup.mc_setup.alice;

        let compliance = setup.mc_setup.compliance.contract_address;

        let check_result = module_dispatcher.module_check(from, to, 10, compliance);
        assert(check_result, 'Should return true');
    }

    #[test]
    fn test_should_return_true_when_listing_type_is_whitelisting_and_token_listed_for_oid() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.configure_token(ListingType::WHITELISTING);
        stop_cheat_caller_address(setup.module.contract_address);

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.alice);
        setup.module.list_token(setup.mock_contract, InvestorAddressType::ONCHAINID);
        stop_cheat_caller_address(setup.module.contract_address);

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        let from = setup.mc_setup.bob;
        let to = setup.mc_setup.alice;
        let compliance = setup.mc_setup.compliance.contract_address;

        let check_result = module_dispatcher.module_check(from, to, 10, compliance);
        assert(check_result, 'Should return true');
    }

    #[test]
    fn test_should_return_true_when_listing_type_is_blacklisting_and_token_not_listed() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.configure_token(ListingType::BLACKLISTING);
        stop_cheat_caller_address(setup.module.contract_address);

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };

        let from = setup.mc_setup.bob;
        let to = setup.mc_setup.alice;
        let compliance = setup.mc_setup.compliance.contract_address;

        let check_result = module_dispatcher.module_check(from, to, 10, compliance);
        assert(check_result, 'Should return true');
    }

    #[test]
    fn test_should_return_false_when_listing_type_is_blacklisting_and_token_listed_for_wallet() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.configure_token(ListingType::BLACKLISTING);
        stop_cheat_caller_address(setup.module.contract_address);

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.alice);
        setup.module.list_token(setup.mock_contract, InvestorAddressType::WALLET);
        stop_cheat_caller_address(setup.module.contract_address);

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        let from = setup.mc_setup.bob;
        let to = setup.mc_setup.alice;
        let compliance = setup.mc_setup.compliance.contract_address;

        let check_result = module_dispatcher.module_check(from, to, 10, compliance);
        assert(!check_result, 'Should return false');
    }

    #[test]
    fn test_should_return_false_when_listing_type_is_blacklisting_and_token_listed_for_oid() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.configure_token(ListingType::BLACKLISTING);
        stop_cheat_caller_address(setup.module.contract_address);

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.alice);
        setup.module.list_token(setup.mock_contract, InvestorAddressType::ONCHAINID);
        stop_cheat_caller_address(setup.module.contract_address);

        let module_dispatcher = IModuleDispatcher {
            contract_address: setup.module.contract_address,
        };
        let from = setup.mc_setup.bob;
        let to = setup.mc_setup.alice;
        let compliance = setup.mc_setup.compliance.contract_address;

        let check_result = module_dispatcher.module_check(from, to, 10, compliance);
        assert(!check_result, 'Should return false');
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
