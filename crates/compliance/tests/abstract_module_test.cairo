use compliance::modules::imodule::IModuleDispatcher;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};


fn setup() -> IModuleDispatcher {
    let mock_abstract_module_contract = declare("MockAbstractModule").unwrap().contract_class();
    let (deployed_address, _) = mock_abstract_module_contract.deploy(@array![]).unwrap();
    IModuleDispatcher { contract_address: deployed_address }
}

mod bind_compliance {
    use compliance::modules::{
        abstract_module::AbstractModuleComponent, imodule::IModuleDispatcherTrait,
    };
    use core::num::traits::Zero;
    use snforge_std::{EventSpyAssertionsTrait, spy_events};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Compliance address zero')]
    fn test_should_panic_when_compliance_address_is_zero() {
        let abstract_module = setup();

        abstract_module.bind_compliance(Zero::zero());
    }

    #[test]
    #[should_panic(expected: 'Only compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance() {
        let abstract_module = setup();

        abstract_module.bind_compliance(starknet::contract_address_const::<'SOME_MODULE'>());
    }

    #[test]
    fn test_should_bind_compliance() {
        let abstract_module = setup();

        let compliance = starknet::get_contract_address();

        let mut spy = spy_events();

        abstract_module.bind_compliance(compliance);

        assert(abstract_module.is_compliance_bound(compliance), 'Compliance is not bound');

        spy
            .assert_emitted(
                @array![
                    (
                        abstract_module.contract_address,
                        AbstractModuleComponent::Event::ComplianceBound(
                            AbstractModuleComponent::ComplianceBound { compliance },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic(expected: 'Compliance already bound')]
    fn test_should_panic_when_compliance_already_bound() {
        let abstract_module = setup();
        let compliance = starknet::get_contract_address();
        abstract_module.bind_compliance(compliance);
        /// Binding second time should panic
        abstract_module.bind_compliance(compliance);
    }
}

mod unbind_compliance {
    use compliance::modules::{
        abstract_module::AbstractModuleComponent, imodule::IModuleDispatcherTrait,
    };
    use core::num::traits::Zero;
    use snforge_std::{EventSpyAssertionsTrait, spy_events};
    use super::setup;

    #[test]
    #[should_panic(expected: 'Only bound compliance can call')]
    fn test_should_panic_when_caller_not_bound_compliance() {
        let abstract_module = setup();

        abstract_module.unbind_compliance(starknet::get_contract_address());
    }

    #[test]
    #[should_panic(expected: 'Compliance address zero')]
    fn test_should_panic_when_compliance_address_is_zero() {
        let abstract_module = setup();
        let compliance = starknet::get_contract_address();

        abstract_module.bind_compliance(compliance);
        abstract_module.unbind_compliance(Zero::zero());
    }

    #[test]
    #[should_panic(expected: 'Only compliance can call')]
    fn test_should_panic_when_caller_is_not_compliance() {
        let abstract_module = setup();

        let compliance = starknet::get_contract_address();

        abstract_module.bind_compliance(compliance);
        abstract_module
            .unbind_compliance(starknet::contract_address_const::<'SOME_OTHER_MODULE'>());
    }

    #[test]
    fn test_should_unbind_compliance() {
        let abstract_module = setup();

        let compliance = starknet::get_contract_address();
        abstract_module.bind_compliance(compliance);

        let mut spy = spy_events();
        abstract_module.unbind_compliance(compliance);
        assert(!abstract_module.is_compliance_bound(compliance), 'Compliance not unbound');

        spy
            .assert_emitted(
                @array![
                    (
                        abstract_module.contract_address,
                        AbstractModuleComponent::Event::ComplianceUnbound(
                            AbstractModuleComponent::ComplianceUnbound { compliance },
                        ),
                    ),
                ],
            );
    }
}

mod is_compliance_bound {
    use compliance::modules::imodule::IModuleDispatcherTrait;
    use super::setup;

    #[test]
    fn test_should_return_true_when_compliance_bound() {
        let abstract_module = setup();

        let compliance = starknet::get_contract_address();
        abstract_module.bind_compliance(compliance);
        assert(abstract_module.is_compliance_bound(compliance), 'Compliance not bound');
    }

    #[test]
    fn test_should_return_true_when_compliance_not_bound() {
        let abstract_module = setup();

        let compliance = starknet::get_contract_address();
        assert(!abstract_module.is_compliance_bound(compliance), 'Compliance is bound');
    }
}
