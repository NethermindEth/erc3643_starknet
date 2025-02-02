use crate::roles::owner::iowner_manager::IOwnerManagerDispatcher;
use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use test_commons::commons::{FullSuiteSetup, setup_full_suite};

fn setup() -> (FullSuiteSetup, IOwnerManagerDispatcher) {
    let setup = setup_full_suite();

    let owner_manager_contract = declare("OwnerManager").unwrap().contract_class();
    let (owner_manager_address, _) = owner_manager_contract
        .deploy(
            @array![setup.token.contract_address.into(), starknet::get_contract_address().into()],
        )
        .unwrap();
    IOwnableDispatcher { contract_address: setup.token.contract_address }
        .transfer_ownership(owner_manager_address);
    IOwnableDispatcher { contract_address: setup.claim_topics_registry.contract_address }
        .transfer_ownership(owner_manager_address);
    IOwnableDispatcher { contract_address: setup.trusted_issuers_registry.contract_address }
        .transfer_ownership(owner_manager_address);
    IOwnableDispatcher { contract_address: setup.identity_registry.contract_address }
        .transfer_ownership(owner_manager_address);
    IOwnableDispatcher { contract_address: setup.modular_compliance.contract_address }
        .transfer_ownership(owner_manager_address);

    (setup, IOwnerManagerDispatcher { contract_address: owner_manager_address })
}

pub mod call_set_identity_registry {
    use crate::roles::{OwnerRoles, owner::iowner_manager::IOwnerManagerDispatcherTrait};
    use crate::token::{Token, itoken::ITokenDispatcherTrait};
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'OID not registry address setter')]
    fn test_should_panic_when_caller_is_not_registry_address_setter() {
        let (setup, owner_manager) = setup();
        let new_identity_registry = starknet::contract_address_const::<'NEW_IDENTITY_REGISTRY'>();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        owner_manager.call_set_identity_registry(new_identity_registry, alice_identity);
    }

    #[test]
    #[should_panic(expected: 'Caller is not action key')]
    fn test_should_panic_when_sender_does_not_have_action_key_on_onchain_id() {
        let (setup, owner_manager) = setup();
        let new_identity_registry = starknet::contract_address_const::<'NEW_IDENTITY_REGISTRY'>();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::REGISTRY_ADDRESS_SETTER, alice_identity);

        start_cheat_caller_address(
            owner_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_KEY'>(),
        );
        owner_manager.call_set_identity_registry(new_identity_registry, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);
    }

    #[test]
    fn test_should_set_identity_registry() {
        let (setup, owner_manager) = setup();
        let new_identity_registry = starknet::contract_address_const::<'NEW_IDENTITY_REGISTRY'>();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::REGISTRY_ADDRESS_SETTER, alice_identity);

        let mut spy = spy_events();
        start_cheat_caller_address(
            owner_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        owner_manager.call_set_identity_registry(new_identity_registry, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);

        assert(
            setup.token.identity_registry().contract_address == new_identity_registry,
            'IR not updated',
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

pub mod call_set_compliance {
    use crate::roles::{OwnerRoles, owner::iowner_manager::IOwnerManagerDispatcherTrait};
    use crate::token::{Token, itoken::ITokenDispatcherTrait};
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, mock_call, spy_events, start_cheat_caller_address,
        stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'OID is not compliance setter')]
    fn test_should_panic_when_caller_is_not_compliance_setter() {
        let (setup, owner_manager) = setup();
        let new_compliance = starknet::contract_address_const::<'NEW_COMPLIANCE'>();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        owner_manager.call_set_compliance(new_compliance, alice_identity);
    }

    #[test]
    #[should_panic(expected: 'Caller is not action key')]
    fn test_should_panic_when_sender_does_not_have_management_key_on_onchain_id() {
        let (setup, owner_manager) = setup();
        let new_compliance = starknet::contract_address_const::<'NEW_COMPLIANCE'>();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::COMPLIANCE_SETTER, alice_identity);

        start_cheat_caller_address(
            owner_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_KEY'>(),
        );
        owner_manager.call_set_compliance(new_compliance, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);
    }

    #[test]
    fn test_should_set_compliance() {
        let (setup, owner_manager) = setup();
        let new_compliance = starknet::contract_address_const::<'NEW_COMPLIANCE'>();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::COMPLIANCE_SETTER, alice_identity);
        mock_call(new_compliance, selector!("bind_token"), (), 1);

        let mut spy = spy_events();
        start_cheat_caller_address(
            owner_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        owner_manager.call_set_compliance(new_compliance, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);

        assert(
            setup.token.compliance().contract_address == new_compliance, 'Compliance not updated',
        );
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

pub mod call_compliance_function {
    use crate::compliance::{
        imodular_compliance::IModularComplianceDispatcherTrait,
        modular_compliance::ModularCompliance,
    };
    use crate::roles::{OwnerRoles, owner::iowner_manager::IOwnerManagerDispatcherTrait};
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use snforge_std::{
        ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
        start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'OID is not compliance manager')]
    fn test_should_panic_when_caller_is_not_compliance_manager() {
        let (setup, owner_manager) = setup();
        let selector = 'SOME_SELECTOR';
        let calldata: Span<felt252> = array!['CALLDATA'].span();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        owner_manager.call_compliance_function(selector, calldata, alice_identity);
    }

    #[test]
    #[should_panic(expected: 'Caller is not action key')]
    fn test_should_panic_when_sender_does_not_have_action_key_on_onchain_id() {
        let (setup, owner_manager) = setup();
        let selector = 'SOME_SELECTOR';
        let calldata: Span<felt252> = array!['CALLDATA'].span();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::COMPLIANCE_MANAGER, alice_identity);

        start_cheat_caller_address(
            owner_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_KEY'>(),
        );
        owner_manager.call_compliance_function(selector, calldata, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);
    }

    #[test]
    fn test_should_call_compliance_function() {
        let (setup, owner_manager) = setup();
        let compliance_module_contract = declare("CountryAllowModule").unwrap().contract_class();
        let (compliance_module_address, _) = compliance_module_contract
            .deploy(@array![starknet::get_contract_address().into()])
            .unwrap();
        let selector = selector!("add_module");
        let calldata: Span<felt252> = array![compliance_module_address.into()].span();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::COMPLIANCE_MANAGER, alice_identity);

        let mut spy = spy_events();
        start_cheat_caller_address(
            owner_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        owner_manager.call_compliance_function(selector, calldata, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);

        assert(
            setup.modular_compliance.is_module_bound(compliance_module_address),
            'Should have been bound',
        );
        spy
            .assert_emitted(
                @array![
                    (
                        setup.modular_compliance.contract_address,
                        ModularCompliance::Event::ModuleAdded(
                            ModularCompliance::ModuleAdded { module: compliance_module_address },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_set_token_name {
    use crate::roles::{OwnerRoles, owner::iowner_manager::IOwnerManagerDispatcherTrait};
    use crate::token::{Token, itoken::ITokenDispatcherTrait};
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use openzeppelin_token::erc20::interface::{IERC20MixinDispatcher, IERC20MixinDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'OID not token info manager')]
    fn test_should_panic_when_caller_is_not_token_info_manager() {
        let (setup, owner_manager) = setup();
        let new_name = "New Token Name";
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        owner_manager.call_set_token_name(new_name, alice_identity);
    }

    #[test]
    #[should_panic(expected: 'Caller is not action key')]
    fn test_should_panic_when_sender_does_not_have_action_key_on_onchain_id() {
        let (setup, owner_manager) = setup();
        let new_name = "New Token Name";
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::TOKEN_INFO_MANAGER, alice_identity);

        start_cheat_caller_address(
            owner_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_KEY'>(),
        );
        owner_manager.call_set_token_name(new_name, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);
    }

    #[test]
    fn test_should_set_token_name() {
        let (setup, owner_manager) = setup();
        let new_name = "New Token Name";
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::TOKEN_INFO_MANAGER, alice_identity);

        let mut spy = spy_events();
        start_cheat_caller_address(
            owner_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        owner_manager.call_set_token_name(new_name.clone(), alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);

        let erc20_dispatcher = IERC20MixinDispatcher {
            contract_address: setup.token.contract_address,
        };
        assert(erc20_dispatcher.name() == new_name.clone(), 'Token Name not updated');
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

pub mod call_set_token_symbol {
    use crate::roles::{OwnerRoles, owner::iowner_manager::IOwnerManagerDispatcherTrait};
    use crate::token::{Token, itoken::ITokenDispatcherTrait};
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use openzeppelin_token::erc20::interface::{IERC20MixinDispatcher, IERC20MixinDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'OID not token info manager')]
    fn test_should_panic_when_caller_is_not_token_info_manager() {
        let (setup, owner_manager) = setup();
        let new_symbol = "NewSYM";
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        owner_manager.call_set_token_symbol(new_symbol, alice_identity);
    }

    #[test]
    #[should_panic(expected: 'Caller is not action key')]
    fn test_should_panic_when_sender_does_not_have_action_key_on_onchain_id() {
        let (setup, owner_manager) = setup();
        let new_symbol = "NewSYM";
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::TOKEN_INFO_MANAGER, alice_identity);

        start_cheat_caller_address(
            owner_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_KEY'>(),
        );
        owner_manager.call_set_token_symbol(new_symbol, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);
    }

    #[test]
    fn test_should_set_token_symbol() {
        let (setup, owner_manager) = setup();
        let new_symbol = "NewSYM";
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::TOKEN_INFO_MANAGER, alice_identity);

        let mut spy = spy_events();
        start_cheat_caller_address(
            owner_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        owner_manager.call_set_token_symbol(new_symbol.clone(), alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);

        let erc20_dispatcher = IERC20MixinDispatcher {
            contract_address: setup.token.contract_address,
        };
        assert(erc20_dispatcher.symbol() == new_symbol.clone(), 'Token Symbol not updated');
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

pub mod call_set_token_onchain_id {
    use crate::roles::{OwnerRoles, owner::iowner_manager::IOwnerManagerDispatcherTrait};
    use crate::token::{Token, itoken::ITokenDispatcherTrait};
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use openzeppelin_token::erc20::interface::{IERC20MixinDispatcher, IERC20MixinDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'OID not token info manager')]
    fn test_should_panic_when_caller_is_not_token_info_manager() {
        let (setup, owner_manager) = setup();
        let new_onchain_id = starknet::contract_address_const::<'NEW_ONCHAIN_ID'>();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        owner_manager.call_set_token_onchain_id(new_onchain_id, alice_identity);
    }

    #[test]
    #[should_panic(expected: 'Caller is not action key')]
    fn test_should_panic_when_sender_does_not_have_action_key_on_onchain_id() {
        let (setup, owner_manager) = setup();
        let new_onchain_id = starknet::contract_address_const::<'NEW_ONCHAIN_ID'>();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::TOKEN_INFO_MANAGER, alice_identity);

        start_cheat_caller_address(
            owner_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_KEY'>(),
        );
        owner_manager.call_set_token_onchain_id(new_onchain_id, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);
    }

    #[test]
    fn test_should_set_token_onchain_id() {
        let (setup, owner_manager) = setup();
        let new_onchain_id = starknet::contract_address_const::<'NEW_ONCHAIN_ID'>();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::TOKEN_INFO_MANAGER, alice_identity);

        let mut spy = spy_events();
        start_cheat_caller_address(
            owner_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        owner_manager.call_set_token_onchain_id(new_onchain_id, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);

        assert(setup.token.onchain_id() == new_onchain_id, 'Token Identity not updated');
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

pub mod call_set_claim_topics_registry {
    use crate::registry::{
        identity_registry::IdentityRegistry,
        interface::iidentity_registry::IIdentityRegistryDispatcherTrait,
    };
    use crate::roles::{OwnerRoles, owner::iowner_manager::IOwnerManagerDispatcherTrait};
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'OID not registry address setter')]
    fn test_should_panic_when_caller_is_not_registry_address_setter() {
        let (setup, owner_manager) = setup();
        let new_claim_topics_registry = starknet::contract_address_const::<
            'NEW_CLAIM_TOPICS_REGISTRY',
        >();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        owner_manager.call_set_claim_topics_registry(new_claim_topics_registry, alice_identity);
    }

    #[test]
    #[should_panic(expected: 'Caller is not action key')]
    fn test_should_panic_when_sender_does_not_have_action_key_on_onchain_id() {
        let (setup, owner_manager) = setup();
        let new_claim_topics_registry = starknet::contract_address_const::<
            'NEW_CLAIM_TOPICS_REGISTRY',
        >();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::REGISTRY_ADDRESS_SETTER, alice_identity);

        start_cheat_caller_address(
            owner_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_KEY'>(),
        );
        owner_manager.call_set_claim_topics_registry(new_claim_topics_registry, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);
    }

    #[test]
    fn test_should_set_claim_topics_registry() {
        let (setup, owner_manager) = setup();
        let new_claim_topics_registry = starknet::contract_address_const::<
            'NEW_CLAIM_TOPICS_REGISTRY',
        >();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::REGISTRY_ADDRESS_SETTER, alice_identity);

        let mut spy = spy_events();
        start_cheat_caller_address(
            owner_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        owner_manager.call_set_claim_topics_registry(new_claim_topics_registry, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);

        assert(
            setup.identity_registry.topics_registry().contract_address == new_claim_topics_registry,
            'CTR not updated',
        );
        spy
            .assert_emitted(
                @array![
                    (
                        setup.identity_registry.contract_address,
                        IdentityRegistry::Event::ClaimTopicsRegistrySet(
                            IdentityRegistry::ClaimTopicsRegistrySet {
                                claim_topics_registry: new_claim_topics_registry,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_set_trusted_issuers_registry {
    use crate::registry::{
        identity_registry::IdentityRegistry,
        interface::iidentity_registry::IIdentityRegistryDispatcherTrait,
    };
    use crate::roles::{OwnerRoles, owner::iowner_manager::IOwnerManagerDispatcherTrait};
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'OID not registry address setter')]
    fn test_should_panic_when_caller_is_not_registry_address_setter() {
        let (setup, owner_manager) = setup();
        let new_trusted_issuers_registry = starknet::contract_address_const::<
            'NEW_TRUSTED_ISSUERS_REGISTRY',
        >();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        owner_manager
            .call_set_trusted_issuers_registry(new_trusted_issuers_registry, alice_identity);
    }

    #[test]
    #[should_panic(expected: 'Caller is not action key')]
    fn test_should_panic_when_sender_does_not_have_action_key_on_onchain_id() {
        let (setup, owner_manager) = setup();
        let new_trusted_issuers_registry = starknet::contract_address_const::<
            'NEW_TRUSTED_ISSUERS_REGISTRY',
        >();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::REGISTRY_ADDRESS_SETTER, alice_identity);

        start_cheat_caller_address(
            owner_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_KEY'>(),
        );
        owner_manager
            .call_set_trusted_issuers_registry(new_trusted_issuers_registry, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);
    }

    #[test]
    fn test_should_set_trusted_issuers_registry() {
        let (setup, owner_manager) = setup();
        let new_trusted_issuers_registry = starknet::contract_address_const::<
            'NEW_TRUSTED_ISSUERS_REGISTRY',
        >();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::REGISTRY_ADDRESS_SETTER, alice_identity);

        let mut spy = spy_events();
        start_cheat_caller_address(
            owner_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        owner_manager
            .call_set_trusted_issuers_registry(new_trusted_issuers_registry, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);

        assert(
            setup
                .identity_registry
                .issuers_registry()
                .contract_address == new_trusted_issuers_registry,
            'TIR not updated',
        );
        spy
            .assert_emitted(
                @array![
                    (
                        setup.identity_registry.contract_address,
                        IdentityRegistry::Event::TrustedIssuersRegistrySet(
                            IdentityRegistry::TrustedIssuersRegistrySet {
                                trusted_issuers_registry: new_trusted_issuers_registry,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_add_trusted_issuer {
    use crate::registry::{
        interface::itrusted_issuers_registry::ITrustedIssuersRegistryDispatcherTrait,
        trusted_issuers_registry::TrustedIssuersRegistry,
    };
    use crate::roles::{OwnerRoles, owner::iowner_manager::IOwnerManagerDispatcherTrait};
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'OID not issuer registry manager')]
    fn test_should_panic_when_caller_is_not_issuers_registry_manager() {
        let (setup, owner_manager) = setup();
        let issuer = starknet::contract_address_const::<'NEW_ISSUER'>();
        let issuer_claim_topics = ['NEW_CLAIM_TOPIC'].span();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        owner_manager.call_add_trusted_issuer(issuer, issuer_claim_topics, alice_identity);
    }

    #[test]
    #[should_panic(expected: 'Caller is not action key')]
    fn test_should_panic_when_sender_does_not_have_action_key_on_onchain_id() {
        let (setup, owner_manager) = setup();
        let issuer = starknet::contract_address_const::<'NEW_ISSUER'>();
        let issuer_claim_topics = ['NEW_CLAIM_TOPIC'].span();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::ISSUERS_REGISTRY_MANAGER, alice_identity);

        start_cheat_caller_address(
            owner_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_KEY'>(),
        );
        owner_manager.call_add_trusted_issuer(issuer, issuer_claim_topics, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);
    }

    #[test]
    fn test_should_add_trusted_issuer() {
        let (setup, owner_manager) = setup();
        let issuer = starknet::contract_address_const::<'NEW_ISSUER'>();
        let issuer_claim_topics = ['NEW_CLAIM_TOPIC'].span();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::ISSUERS_REGISTRY_MANAGER, alice_identity);

        let mut spy = spy_events();
        start_cheat_caller_address(
            owner_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        owner_manager.call_add_trusted_issuer(issuer, issuer_claim_topics, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);

        assert(setup.trusted_issuers_registry.is_trusted_issuer(issuer), 'Issuer not registered');
        assert!(
            setup
                .trusted_issuers_registry
                .get_trusted_issuers_for_claim_topic(*issuer_claim_topics.at(0)) == [issuer]
                .span(),
            "Issuer for claim topic does not match",
        );
        assert(
            setup
                .trusted_issuers_registry
                .get_trusted_issuer_claim_topics(issuer) == issuer_claim_topics,
            'Issuer claim topics mismatch',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        setup.trusted_issuers_registry.contract_address,
                        TrustedIssuersRegistry::Event::TrustedIssuerAdded(
                            TrustedIssuersRegistry::TrustedIssuerAdded {
                                trusted_issuer: issuer, claim_topics: issuer_claim_topics,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_remove_trusted_issuer {
    use crate::registry::{
        interface::itrusted_issuers_registry::{
            ITrustedIssuersRegistryDispatcherTrait, ITrustedIssuersRegistrySafeDispatcher,
            ITrustedIssuersRegistrySafeDispatcherTrait,
        },
        trusted_issuers_registry::TrustedIssuersRegistry,
    };
    use crate::roles::{OwnerRoles, owner::iowner_manager::IOwnerManagerDispatcherTrait};
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'OID not issuer registry manager')]
    fn test_should_panic_when_caller_is_not_issuers_registry_manager() {
        let (setup, owner_manager) = setup();
        let issuer = starknet::contract_address_const::<'NEW_ISSUER'>();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        owner_manager.call_remove_trusted_issuer(issuer, alice_identity);
    }

    #[test]
    #[should_panic(expected: 'Caller is not action key')]
    fn test_should_panic_when_sender_does_not_have_action_key_on_onchain_id() {
        let (setup, owner_manager) = setup();
        let issuer = starknet::contract_address_const::<'NEW_ISSUER'>();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::ISSUERS_REGISTRY_MANAGER, alice_identity);

        start_cheat_caller_address(
            owner_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_KEY'>(),
        );
        owner_manager.call_remove_trusted_issuer(issuer, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);
    }

    #[test]
    #[feature("safe_dispatcher")]
    fn test_should_remove_trusted_issuer() {
        let (setup, owner_manager) = setup();
        let issuer = starknet::contract_address_const::<'NEW_ISSUER'>();
        let issuer_claim_topics = ['NEW_CLAIM_TOPIC'].span();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::ISSUERS_REGISTRY_MANAGER, alice_identity);

        start_cheat_caller_address(
            owner_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        owner_manager.call_add_trusted_issuer(issuer, issuer_claim_topics, alice_identity);
        assert(setup.trusted_issuers_registry.is_trusted_issuer(issuer), 'Issuer not registered');
        assert!(
            setup
                .trusted_issuers_registry
                .get_trusted_issuers_for_claim_topic(*issuer_claim_topics.at(0)) == [issuer]
                .span(),
            "Issuer for claim topic does not match",
        );
        assert(
            setup
                .trusted_issuers_registry
                .get_trusted_issuer_claim_topics(issuer) == issuer_claim_topics,
            'Issuer claim topics mismatch',
        );

        let mut spy = spy_events();
        owner_manager.call_remove_trusted_issuer(issuer, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);

        assert(!setup.trusted_issuers_registry.is_trusted_issuer(issuer), 'Issuer not removed');
        assert!(
            setup
                .trusted_issuers_registry
                .get_trusted_issuers_for_claim_topic(*issuer_claim_topics.at(0)) == []
                .span(),
            "Issuer for claim topic does not cleared",
        );
        let safe_dispatcher = ITrustedIssuersRegistrySafeDispatcher {
            contract_address: setup.trusted_issuers_registry.contract_address,
        };

        match safe_dispatcher.get_trusted_issuer_claim_topics(issuer) {
            Result::Ok(_) => panic!("Should have been panicked"),
            Result::Err(panic_data) => assert(
                *panic_data.at(0) == 'Trusted Issuer not exists', 'Unexpected panic message',
            ),
        }

        spy
            .assert_emitted(
                @array![
                    (
                        setup.trusted_issuers_registry.contract_address,
                        TrustedIssuersRegistry::Event::TrustedIssuerRemoved(
                            TrustedIssuersRegistry::TrustedIssuerRemoved { trusted_issuer: issuer },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_update_issuer_claim_topics {
    use crate::registry::{
        interface::itrusted_issuers_registry::ITrustedIssuersRegistryDispatcherTrait,
        trusted_issuers_registry::TrustedIssuersRegistry,
    };
    use crate::roles::{OwnerRoles, owner::iowner_manager::IOwnerManagerDispatcherTrait};
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'OID not issuer registry manager')]
    fn test_should_panic_when_caller_is_not_issuers_registry_manager() {
        let (setup, owner_manager) = setup();
        let issuer = *setup.trusted_issuers_registry.get_trusted_issuers().at(0);
        let issuer_claim_topics = ['FIRST_CLAIM_TOPIC', 'SECOND_CLAIM_TOPIC'].span();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        owner_manager.call_update_issuer_claim_topics(issuer, issuer_claim_topics, alice_identity);
    }

    #[test]
    #[should_panic(expected: 'Caller is not action key')]
    fn test_should_panic_when_sender_does_not_have_action_key_on_onchain_id() {
        let (setup, owner_manager) = setup();
        let issuer = *setup.trusted_issuers_registry.get_trusted_issuers().at(0);
        let issuer_claim_topics = ['FIRST_CLAIM_TOPIC', 'SECOND_CLAIM_TOPIC'].span();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::ISSUERS_REGISTRY_MANAGER, alice_identity);

        start_cheat_caller_address(
            owner_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_KEY'>(),
        );
        owner_manager.call_update_issuer_claim_topics(issuer, issuer_claim_topics, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);
    }

    #[test]
    fn test_should_update_issuer_claim_topics() {
        let (setup, owner_manager) = setup();
        let issuer = *setup.trusted_issuers_registry.get_trusted_issuers().at(0);
        let issuer_claim_topics = ['FIRST_CLAIM_TOPIC', 'SECOND_CLAIM_TOPIC'].span();
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::ISSUERS_REGISTRY_MANAGER, alice_identity);

        let mut spy = spy_events();
        start_cheat_caller_address(
            owner_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        owner_manager.call_update_issuer_claim_topics(issuer, issuer_claim_topics, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);

        assert(setup.trusted_issuers_registry.is_trusted_issuer(issuer), 'Issuer not registered');
        assert!(
            setup
                .trusted_issuers_registry
                .get_trusted_issuers_for_claim_topic(*issuer_claim_topics.at(0)) == [issuer]
                .span(),
            "Issuer for claim topic does not match",
        );
        assert!(
            setup
                .trusted_issuers_registry
                .get_trusted_issuers_for_claim_topic(*issuer_claim_topics.at(1)) == [issuer]
                .span(),
            "Issuer for claim topic does not match",
        );
        assert(
            setup
                .trusted_issuers_registry
                .get_trusted_issuer_claim_topics(issuer) == issuer_claim_topics,
            'Issuer claim topics mismatch',
        );

        spy
            .assert_emitted(
                @array![
                    (
                        setup.trusted_issuers_registry.contract_address,
                        TrustedIssuersRegistry::Event::ClaimTopicsUpdated(
                            TrustedIssuersRegistry::ClaimTopicsUpdated {
                                trusted_issuer: issuer, claim_topics: issuer_claim_topics,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_add_claim_topic {
    use crate::registry::{
        claim_topics_registry::ClaimTopicsRegistry,
        interface::iclaim_topics_registry::IClaimTopicsRegistryDispatcherTrait,
    };
    use crate::roles::{OwnerRoles, owner::iowner_manager::IOwnerManagerDispatcherTrait};
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'OID not claim registry manager')]
    fn test_should_panic_when_caller_is_not_claim_registry_manager() {
        let (setup, owner_manager) = setup();
        let new_claim_topic = 'NEW_CLAIM_TOPIC';
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        owner_manager.call_add_claim_topic(new_claim_topic, alice_identity);
    }

    #[test]
    #[should_panic(expected: 'Caller is not action key')]
    fn test_should_panic_when_sender_does_not_have_action_key_on_onchain_id() {
        let (setup, owner_manager) = setup();
        let new_claim_topic = 'NEW_CLAIM_TOPIC';
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::CLAIM_REGISTRY_MANAGER, alice_identity);

        start_cheat_caller_address(
            owner_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_KEY'>(),
        );
        owner_manager.call_add_claim_topic(new_claim_topic, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);
    }

    #[test]
    fn test_should_add_claim_topic() {
        let (setup, owner_manager) = setup();
        let new_claim_topic = 'NEW_CLAIM_TOPIC';
        let alice_identity = setup.onchain_id.alice_identity.contract_address;
        let previous_claim_topics = setup.claim_topics_registry.get_claim_topics();
        let mut expected_claim_topics = array![];
        for topic in previous_claim_topics {
            expected_claim_topics.append(*topic);
        };
        expected_claim_topics.append(new_claim_topic);

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::CLAIM_REGISTRY_MANAGER, alice_identity);

        let mut spy = spy_events();
        start_cheat_caller_address(
            owner_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        owner_manager.call_add_claim_topic(new_claim_topic, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);

        assert(
            setup.claim_topics_registry.get_claim_topics() == expected_claim_topics.span(),
            'Claim topics mismatch',
        );
        spy
            .assert_emitted(
                @array![
                    (
                        setup.claim_topics_registry.contract_address,
                        ClaimTopicsRegistry::Event::ClaimTopicAdded(
                            ClaimTopicsRegistry::ClaimTopicAdded { claim_topic: new_claim_topic },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_remove_claim_topic {
    use crate::registry::{
        claim_topics_registry::ClaimTopicsRegistry,
        interface::iclaim_topics_registry::IClaimTopicsRegistryDispatcherTrait,
    };
    use crate::roles::{OwnerRoles, owner::iowner_manager::IOwnerManagerDispatcherTrait};
    use openzeppelin_access::accesscontrol::interface::{
        IAccessControlDispatcher, IAccessControlDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'OID not claim registry manager')]
    fn test_should_panic_when_caller_is_not_claim_registry_manager() {
        let (setup, owner_manager) = setup();
        let new_claim_topic = 'NEW_CLAIM_TOPIC';
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        owner_manager.call_remove_claim_topic(new_claim_topic, alice_identity);
    }

    #[test]
    #[should_panic(expected: 'Caller is not action key')]
    fn test_should_panic_when_sender_does_not_have_action_key_on_onchain_id() {
        let (setup, owner_manager) = setup();
        let new_claim_topic = 'NEW_CLAIM_TOPIC';
        let alice_identity = setup.onchain_id.alice_identity.contract_address;

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::CLAIM_REGISTRY_MANAGER, alice_identity);

        start_cheat_caller_address(
            owner_manager.contract_address,
            starknet::contract_address_const::<'NOT_ALICE_ID_KEY'>(),
        );
        owner_manager.call_remove_claim_topic(new_claim_topic, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);
    }

    #[test]
    fn test_should_remove_claim_topic() {
        let (setup, owner_manager) = setup();
        let new_claim_topic = 'NEW_CLAIM_TOPIC';
        let alice_identity = setup.onchain_id.alice_identity.contract_address;
        let previous_claim_topics = setup.claim_topics_registry.get_claim_topics();
        let mut expected_claim_topics = array![];
        for topic in previous_claim_topics {
            expected_claim_topics.append(*topic);
        };
        expected_claim_topics.append(new_claim_topic);

        IAccessControlDispatcher { contract_address: owner_manager.contract_address }
            .grant_role(OwnerRoles::CLAIM_REGISTRY_MANAGER, alice_identity);

        start_cheat_caller_address(
            owner_manager.contract_address, setup.accounts.alice.account.contract_address,
        );
        owner_manager.call_add_claim_topic(new_claim_topic, alice_identity);
        assert(
            setup.claim_topics_registry.get_claim_topics() == expected_claim_topics.span(),
            'Claim topics mismatch',
        );

        let mut spy = spy_events();
        owner_manager.call_remove_claim_topic(new_claim_topic, alice_identity);
        stop_cheat_caller_address(owner_manager.contract_address);

        assert(
            setup.claim_topics_registry.get_claim_topics() == previous_claim_topics,
            'Claim topics mismatch',
        );
        spy
            .assert_emitted(
                @array![
                    (
                        setup.claim_topics_registry.contract_address,
                        ClaimTopicsRegistry::Event::ClaimTopicRemoved(
                            ClaimTopicsRegistry::ClaimTopicRemoved { claim_topic: new_claim_topic },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_transfer_ownership_on_token_contract {
    use crate::roles::owner::iowner_manager::IOwnerManagerDispatcherTrait;
    use openzeppelin_access::ownable::{
        OwnableComponent, interface::{IOwnableDispatcher, IOwnableDispatcherTrait},
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not owner nor admin')]
    fn test_should_panic_when_caller_is_not_admin() {
        let (_, owner_manager) = setup();
        let new_owner = starknet::contract_address_const::<'NEW_OWNER'>();

        start_cheat_caller_address(
            owner_manager.contract_address, starknet::contract_address_const::<'NOT_ADMIN'>(),
        );
        owner_manager.call_transfer_ownership_on_token_contract(new_owner);
        stop_cheat_caller_address(owner_manager.contract_address);
    }

    #[test]
    fn test_should_transfer_ownership_on_token_contract() {
        let (setup, owner_manager) = setup();
        let new_owner = starknet::contract_address_const::<'NEW_OWNER'>();

        let mut spy = spy_events();
        owner_manager.call_transfer_ownership_on_token_contract(new_owner);

        let ownable_dispatcher = IOwnableDispatcher {
            contract_address: setup.token.contract_address,
        };
        assert(ownable_dispatcher.owner() == new_owner, 'Ownership not transferred');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        OwnableComponent::Event::OwnershipTransferred(
                            OwnableComponent::OwnershipTransferred {
                                previous_owner: owner_manager.contract_address, new_owner,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_transfer_ownership_on_identity_registry_contract {
    use crate::roles::owner::iowner_manager::IOwnerManagerDispatcherTrait;
    use openzeppelin_access::ownable::{
        OwnableComponent, interface::{IOwnableDispatcher, IOwnableDispatcherTrait},
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not owner nor admin')]
    fn test_should_panic_when_caller_is_not_admin() {
        let (_, owner_manager) = setup();
        let new_owner = starknet::contract_address_const::<'NEW_OWNER'>();

        start_cheat_caller_address(
            owner_manager.contract_address, starknet::contract_address_const::<'NOT_ADMIN'>(),
        );
        owner_manager.call_transfer_ownership_on_identity_registry_contract(new_owner);
        stop_cheat_caller_address(owner_manager.contract_address);
    }

    #[test]
    fn test_should_transfer_ownership_on_identity_registry_contract() {
        let (setup, owner_manager) = setup();
        let new_owner = starknet::contract_address_const::<'NEW_OWNER'>();

        let mut spy = spy_events();
        owner_manager.call_transfer_ownership_on_identity_registry_contract(new_owner);

        let ownable_dispatcher = IOwnableDispatcher {
            contract_address: setup.identity_registry.contract_address,
        };
        assert(ownable_dispatcher.owner() == new_owner, 'Ownership not transferred');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.identity_registry.contract_address,
                        OwnableComponent::Event::OwnershipTransferred(
                            OwnableComponent::OwnershipTransferred {
                                previous_owner: owner_manager.contract_address, new_owner,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_transfer_ownership_on_compliance_contract {
    use crate::roles::owner::iowner_manager::IOwnerManagerDispatcherTrait;
    use openzeppelin_access::ownable::{
        OwnableComponent, interface::{IOwnableDispatcher, IOwnableDispatcherTrait},
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not owner nor admin')]
    fn test_should_panic_when_caller_is_not_admin() {
        let (_, owner_manager) = setup();
        let new_owner = starknet::contract_address_const::<'NEW_OWNER'>();

        start_cheat_caller_address(
            owner_manager.contract_address, starknet::contract_address_const::<'NOT_ADMIN'>(),
        );
        owner_manager.call_transfer_ownership_on_compliance_contract(new_owner);
        stop_cheat_caller_address(owner_manager.contract_address);
    }

    #[test]
    fn test_should_transfer_ownership_on_compliance_contract() {
        let (setup, owner_manager) = setup();
        let new_owner = starknet::contract_address_const::<'NEW_OWNER'>();

        let mut spy = spy_events();
        owner_manager.call_transfer_ownership_on_compliance_contract(new_owner);

        let ownable_dispatcher = IOwnableDispatcher {
            contract_address: setup.modular_compliance.contract_address,
        };
        assert(ownable_dispatcher.owner() == new_owner, 'Ownership not transferred');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.modular_compliance.contract_address,
                        OwnableComponent::Event::OwnershipTransferred(
                            OwnableComponent::OwnershipTransferred {
                                previous_owner: owner_manager.contract_address, new_owner,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_transfer_ownership_on_claim_topics_registry_contract {
    use crate::roles::owner::iowner_manager::IOwnerManagerDispatcherTrait;
    use openzeppelin_access::ownable::{
        OwnableComponent, interface::{IOwnableDispatcher, IOwnableDispatcherTrait},
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not owner nor admin')]
    fn test_should_panic_when_caller_is_not_admin() {
        let (_, owner_manager) = setup();
        let new_owner = starknet::contract_address_const::<'NEW_OWNER'>();

        start_cheat_caller_address(
            owner_manager.contract_address, starknet::contract_address_const::<'NOT_ADMIN'>(),
        );
        owner_manager.call_transfer_ownership_on_claim_topics_registry_contract(new_owner);
        stop_cheat_caller_address(owner_manager.contract_address);
    }

    #[test]
    fn test_should_transfer_ownership_on_claim_topics_registry_contract() {
        let (setup, owner_manager) = setup();
        let new_owner = starknet::contract_address_const::<'NEW_OWNER'>();

        let mut spy = spy_events();
        owner_manager.call_transfer_ownership_on_claim_topics_registry_contract(new_owner);

        let ownable_dispatcher = IOwnableDispatcher {
            contract_address: setup.claim_topics_registry.contract_address,
        };
        assert(ownable_dispatcher.owner() == new_owner, 'Ownership not transferred');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.claim_topics_registry.contract_address,
                        OwnableComponent::Event::OwnershipTransferred(
                            OwnableComponent::OwnershipTransferred {
                                previous_owner: owner_manager.contract_address, new_owner,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_transfer_ownership_on_issuers_registry_contract {
    use crate::roles::owner::iowner_manager::IOwnerManagerDispatcherTrait;
    use openzeppelin_access::ownable::{
        OwnableComponent, interface::{IOwnableDispatcher, IOwnableDispatcherTrait},
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not owner nor admin')]
    fn test_should_panic_when_caller_is_not_admin() {
        let (_, owner_manager) = setup();
        let new_owner = starknet::contract_address_const::<'NEW_OWNER'>();

        start_cheat_caller_address(
            owner_manager.contract_address, starknet::contract_address_const::<'NOT_ADMIN'>(),
        );
        owner_manager.call_transfer_ownership_on_issuers_registry_contract(new_owner);
        stop_cheat_caller_address(owner_manager.contract_address);
    }

    #[test]
    fn test_should_transfer_ownership_on_issuers_registry_contract() {
        let (setup, owner_manager) = setup();
        let new_owner = starknet::contract_address_const::<'NEW_OWNER'>();

        let mut spy = spy_events();
        owner_manager.call_transfer_ownership_on_issuers_registry_contract(new_owner);

        let ownable_dispatcher = IOwnableDispatcher {
            contract_address: setup.trusted_issuers_registry.contract_address,
        };
        assert(ownable_dispatcher.owner() == new_owner, 'Ownership not transferred');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.trusted_issuers_registry.contract_address,
                        OwnableComponent::Event::OwnershipTransferred(
                            OwnableComponent::OwnershipTransferred {
                                previous_owner: owner_manager.contract_address, new_owner,
                            },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_add_agent_on_token_contract {
    use crate::roles::{
        agent_role::{AgentRoleComponent, IAgentRoleDispatcher, IAgentRoleDispatcherTrait},
        owner::iowner_manager::IOwnerManagerDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not owner nor admin')]
    fn test_should_panic_when_caller_is_not_admin() {
        let (_, owner_manager) = setup();
        let new_agent = starknet::contract_address_const::<'NEW_AGENT'>();

        start_cheat_caller_address(
            owner_manager.contract_address, starknet::contract_address_const::<'NOT_ADMIN'>(),
        );
        owner_manager.call_add_agent_on_token_contract(new_agent);
        stop_cheat_caller_address(owner_manager.contract_address);
    }

    #[test]
    fn test_should_add_agent_on_token_contract() {
        let (setup, owner_manager) = setup();
        let new_agent = starknet::contract_address_const::<'NEW_AGENT'>();

        let mut spy = spy_events();
        owner_manager.call_add_agent_on_token_contract(new_agent);

        let agent_role_dispatcher = IAgentRoleDispatcher {
            contract_address: setup.token.contract_address,
        };
        assert(agent_role_dispatcher.is_agent(new_agent), 'Agent not registered');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        AgentRoleComponent::Event::AgentAdded(
                            AgentRoleComponent::AgentAdded { agent: new_agent },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_remove_agent_on_token_contract {
    use crate::roles::{
        agent_role::{AgentRoleComponent, IAgentRoleDispatcher, IAgentRoleDispatcherTrait},
        owner::iowner_manager::IOwnerManagerDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not owner nor admin')]
    fn test_should_panic_when_caller_is_not_admin() {
        let (_, owner_manager) = setup();
        let new_agent = starknet::contract_address_const::<'NEW_AGENT'>();

        start_cheat_caller_address(
            owner_manager.contract_address, starknet::contract_address_const::<'NOT_ADMIN'>(),
        );
        owner_manager.call_remove_agent_on_token_contract(new_agent);
        stop_cheat_caller_address(owner_manager.contract_address);
    }

    #[test]
    fn test_should_remove_agent_on_token_contract() {
        let (setup, owner_manager) = setup();
        let new_agent = starknet::contract_address_const::<'NEW_AGENT'>();

        owner_manager.call_add_agent_on_token_contract(new_agent);
        let agent_role_dispatcher = IAgentRoleDispatcher {
            contract_address: setup.token.contract_address,
        };
        assert(agent_role_dispatcher.is_agent(new_agent), 'Agent not registered');

        let mut spy = spy_events();
        owner_manager.call_remove_agent_on_token_contract(new_agent);
        assert(!agent_role_dispatcher.is_agent(new_agent), 'Agent not removed');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.token.contract_address,
                        AgentRoleComponent::Event::AgentRemoved(
                            AgentRoleComponent::AgentRemoved { agent: new_agent },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_add_agent_on_identity_registry_contract {
    use crate::roles::{
        agent_role::{AgentRoleComponent, IAgentRoleDispatcher, IAgentRoleDispatcherTrait},
        owner::iowner_manager::IOwnerManagerDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not owner nor admin')]
    fn test_should_panic_when_caller_is_not_admin() {
        let (_, owner_manager) = setup();
        let new_agent = starknet::contract_address_const::<'NEW_AGENT'>();

        start_cheat_caller_address(
            owner_manager.contract_address, starknet::contract_address_const::<'NOT_ADMIN'>(),
        );
        owner_manager.call_add_agent_on_identity_registry_contract(new_agent);
        stop_cheat_caller_address(owner_manager.contract_address);
    }

    #[test]
    fn test_should_add_agent_on_identity_registry_contract() {
        let (setup, owner_manager) = setup();
        let new_agent = starknet::contract_address_const::<'NEW_AGENT'>();

        let mut spy = spy_events();
        owner_manager.call_add_agent_on_identity_registry_contract(new_agent);

        let agent_role_dispatcher = IAgentRoleDispatcher {
            contract_address: setup.identity_registry.contract_address,
        };
        assert(agent_role_dispatcher.is_agent(new_agent), 'Agent not registered');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.identity_registry.contract_address,
                        AgentRoleComponent::Event::AgentAdded(
                            AgentRoleComponent::AgentAdded { agent: new_agent },
                        ),
                    ),
                ],
            );
    }
}

pub mod call_remove_agent_on_identity_registry_contract {
    use crate::roles::{
        agent_role::{AgentRoleComponent, IAgentRoleDispatcher, IAgentRoleDispatcherTrait},
        owner::iowner_manager::IOwnerManagerDispatcherTrait,
    };
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not owner nor admin')]
    fn test_should_panic_when_caller_is_not_admin() {
        let (_, owner_manager) = setup();
        let new_agent = starknet::contract_address_const::<'NEW_AGENT'>();

        start_cheat_caller_address(
            owner_manager.contract_address, starknet::contract_address_const::<'NOT_ADMIN'>(),
        );
        owner_manager.call_remove_agent_on_identity_registry_contract(new_agent);
        stop_cheat_caller_address(owner_manager.contract_address);
    }

    #[test]
    fn test_should_remove_agent_on_identity_registry_contract() {
        let (setup, owner_manager) = setup();
        let new_agent = starknet::contract_address_const::<'NEW_AGENT'>();

        owner_manager.call_add_agent_on_identity_registry_contract(new_agent);
        let agent_role_dispatcher = IAgentRoleDispatcher {
            contract_address: setup.identity_registry.contract_address,
        };
        assert(agent_role_dispatcher.is_agent(new_agent), 'Agent not registered');

        let mut spy = spy_events();
        owner_manager.call_remove_agent_on_identity_registry_contract(new_agent);
        assert(!agent_role_dispatcher.is_agent(new_agent), 'Agent not removed');
        spy
            .assert_emitted(
                @array![
                    (
                        setup.identity_registry.contract_address,
                        AgentRoleComponent::Event::AgentRemoved(
                            AgentRoleComponent::AgentRemoved { agent: new_agent },
                        ),
                    ),
                ],
            );
    }
}
