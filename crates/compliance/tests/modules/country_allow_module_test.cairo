use compliance::{
    imodular_compliance::IModularComplianceDispatcherTrait,
    modules::{
        country_allow_module::ICountryAllowModuleDispatcher,
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
    module: ICountryAllowModuleDispatcher,
    mock_contract: ContractAddress,
}

pub fn setup() -> Setup {
    let mc_setup = mc_setup();

    let compliance_module_contract = declare("CountryAllowModule").unwrap().contract_class();
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
        module: ICountryAllowModuleDispatcher { contract_address: deployed_address },
        mock_contract,
    }
}

#[test]
fn test_should_return_the_name_of_the_module() {
    let setup = setup();
    let module_dispatcher = IModuleDispatcher { contract_address: setup.module.contract_address };
    assert(module_dispatcher.name() == "CountryAllowModule", 'Names does not match!');
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

pub mod add_allowed_country {
    use compliance::modules::country_allow_module::{
        CountryAllowModule, ICountryAllowModuleDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        let setup = setup();

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.another_wallet);
        setup.module.add_allowed_country(42);
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_calling_as_the_owner() {
        let setup = setup();

        setup.module.add_allowed_country(42);
    }

    #[test]
    fn test_should_allow_given_country_when_country_not_allowed() {
        let setup = setup();

        let mut spy = spy_events();

        let compliance = setup.mc_setup.compliance.contract_address;
        let country = 42;

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.add_allowed_country(country);
        stop_cheat_caller_address(setup.module.contract_address);

        assert(setup.module.is_country_allowed(compliance, country), 'Country is not allowed');

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        CountryAllowModule::Event::CountryAllowed(
                            CountryAllowModule::CountryAllowed { compliance, country },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic(expected: 'Country already allowed')]
    fn test_should_panic_when_country_already_allowed() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.add_allowed_country(42);
        /// Adding same country second time should panic
        setup.module.add_allowed_country(42);
        stop_cheat_caller_address(setup.module.contract_address);
    }
}

pub mod remove_allowed_country {
    use compliance::modules::country_allow_module::{
        CountryAllowModule, ICountryAllowModuleDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        let setup = setup();

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.another_wallet);
        setup.module.remove_allowed_country(42);
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_calling_as_the_owner() {
        let setup = setup();

        setup.module.remove_allowed_country(42);
    }

    #[test]
    #[should_panic(expected: 'Country is not allowed')]
    fn test_should_panic_when_country_not_allowed() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.remove_allowed_country(42);
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    fn test_should_disallow_given_country_when_country_is_allowed() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        let country = 42;

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.add_allowed_country(country);

        let mut spy = spy_events();

        setup.module.remove_allowed_country(country);
        stop_cheat_caller_address(setup.module.contract_address);
        assert(!setup.module.is_country_allowed(compliance, country), 'Country is allowed');

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        CountryAllowModule::Event::CountryUnallowed(
                            CountryAllowModule::CountryUnallowed { compliance, country },
                        ),
                    ),
                ],
            );
    }
}

pub mod batch_allow_countries {
    use compliance::modules::country_allow_module::{
        CountryAllowModule, ICountryAllowModuleDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_not_compliance_contract() {
        let setup = setup();

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.another_wallet);
        setup.module.batch_allow_countries(array![42, 66].span());
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_calling_as_the_owner() {
        let setup = setup();

        setup.module.batch_allow_countries(array![42, 66].span());
    }

    #[test]
    #[should_panic(expected: 'Max 195 country in one batch')]
    fn test_should_panic_when_max_batch_size_exceeds() {
        let setup = setup();

        let mut batch: Array<u16> = array![];
        for i in 0..196_u16 {
            batch.append(i);
        };

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.batch_allow_countries(batch.span());
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Country already allowed')]
    fn test_should_panic_when_country_is_already_allowed() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.add_allowed_country(42);
        /// Adding '42' again should panic
        setup.module.batch_allow_countries(array![66, 42].span());
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    fn test_should_allow_given_countries() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;
        let mut spy = spy_events();

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.batch_allow_countries(array![66, 42].span());
        stop_cheat_caller_address(setup.module.contract_address);

        assert(setup.module.is_country_allowed(compliance, 66), 'Country is not allowed');
        assert(setup.module.is_country_allowed(compliance, 42), 'Country is not allowed');

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        CountryAllowModule::Event::CountryAllowed(
                            CountryAllowModule::CountryAllowed { compliance, country: 66 },
                        ),
                    ),
                    (
                        setup.module.contract_address,
                        CountryAllowModule::Event::CountryAllowed(
                            CountryAllowModule::CountryAllowed { compliance, country: 42 },
                        ),
                    ),
                ],
            );
    }
}

pub mod batch_disallow_countries {
    use compliance::modules::country_allow_module::{
        CountryAllowModule, ICountryAllowModuleDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        let setup = setup();

        start_cheat_caller_address(setup.module.contract_address, setup.mc_setup.another_wallet);
        setup.module.batch_disallow_countries(array![42, 66].span());
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_calling_as_the_owner() {
        let setup = setup();

        setup.module.batch_disallow_countries(array![42, 66].span());
    }

    #[test]
    #[should_panic(expected: 'Max 195 country in one batch')]
    fn test_should_panic_when_max_batch_size_exceeds() {
        let setup = setup();

        let mut batch: Array<u16> = array![];
        for i in 0..196_u16 {
            batch.append(i);
        };

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.batch_disallow_countries(batch.span());
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Country is not allowed')]
    fn test_should_panic_when_country_is_not_allowed() {
        let setup = setup();

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.batch_disallow_countries(array![66, 42].span());
        stop_cheat_caller_address(setup.module.contract_address);
    }

    #[test]
    fn test_should_disallow_given_countries_when_caller_is_compliance_contract() {
        let setup = setup();

        let compliance = setup.mc_setup.compliance.contract_address;

        start_cheat_caller_address(setup.module.contract_address, compliance);
        setup.module.batch_allow_countries(array![66, 42].span());

        let mut spy = spy_events();

        setup.module.batch_disallow_countries(array![66, 42].span());
        stop_cheat_caller_address(setup.module.contract_address);

        assert(!setup.module.is_country_allowed(compliance, 66), 'Country is allowed');
        assert(!setup.module.is_country_allowed(compliance, 42), 'Country is allowed');

        spy
            .assert_emitted(
                @array![
                    (
                        setup.module.contract_address,
                        CountryAllowModule::Event::CountryUnallowed(
                            CountryAllowModule::CountryUnallowed { compliance, country: 66 },
                        ),
                    ),
                    (
                        setup.module.contract_address,
                        CountryAllowModule::Event::CountryUnallowed(
                            CountryAllowModule::CountryUnallowed { compliance, country: 42 },
                        ),
                    ),
                ],
            );
    }
}

pub mod module_check {
    use compliance::{
        imodular_compliance::IModularComplianceDispatcherTrait,
        modules::{
            country_allow_module::ICountryAllowModuleDispatcherTrait,
            imodule::{IModuleDispatcher, IModuleDispatcherTrait},
        },
    };
    use mocks::mock_contract::{IMockContractDispatcher, IMockContractDispatcherTrait};
    use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
    use super::setup;

    #[test]
    fn test_should_return_true_when_identity_country_is_allowed() {
        let setup = setup();
        IMockContractDispatcher { contract_address: setup.mock_contract }.set_investor_country(42);

        start_cheat_caller_address(
            setup.module.contract_address, setup.mc_setup.compliance.contract_address,
        );
        setup.module.add_allowed_country(42);
        stop_cheat_caller_address(setup.module.contract_address);
        let check_result = IModuleDispatcher { contract_address: setup.module.contract_address }
            .module_check(
                setup.mc_setup.alice,
                setup.mc_setup.bob,
                10,
                setup.mc_setup.compliance.contract_address,
            );
        assert(check_result, 'Module check returned false');
        assert(
            setup.mc_setup.compliance.can_transfer(setup.mc_setup.alice, setup.mc_setup.bob, 10),
            'Should return true',
        );
    }

    #[test]
    fn test_should_return_false_when_identity_country_not_allowed() {
        let setup = setup();
        IMockContractDispatcher { contract_address: setup.mock_contract }.set_investor_country(42);
        let check_result = IModuleDispatcher { contract_address: setup.module.contract_address }
            .module_check(
                setup.mc_setup.alice,
                setup.mc_setup.bob,
                10,
                setup.mc_setup.compliance.contract_address,
            );
        assert(!check_result, 'Module check returned true');
        assert(
            !setup.mc_setup.compliance.can_transfer(setup.mc_setup.alice, setup.mc_setup.bob, 10),
            'Should return false',
        );
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
