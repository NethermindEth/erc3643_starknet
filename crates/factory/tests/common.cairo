use compliance::imodular_compliance::IModularComplianceDispatcher;
use core::num::traits::Zero;
use core::poseidon::poseidon_hash_span;
#[allow(unused_imports)]
use factory::{
    iimplementation_authority::{
        IImplementationAuthorityDispatcher, IImplementationAuthorityDispatcherTrait,
        TREXImplementations, Version,
    },
    itrex_factory::{
        ClaimDetails, ComplianceSetting, ITREXFactoryDispatcher, ITREXFactoryDispatcherTrait,
        TokenDetails,
    },
};
use onchain_id_starknet::{
    factory::iid_factory::{IIdFactoryDispatcher, IIdFactoryDispatcherTrait},
    interface::{
        iclaim_issuer::{ClaimIssuerABIDispatcher, ClaimIssuerABIDispatcherTrait},
        iidentity::{IdentityABIDispatcher, IdentityABIDispatcherTrait},
        //iimplementation_authority::IImplementationAuthorityDispatcher,
    },
    storage::structs::{Signature, StarkSignature},
};
use openzeppelin_access::accesscontrol::interface::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use registry::interface::{
    iclaim_topics_registry::IClaimTopicsRegistryDispatcher,
    iidentity_registry::{IIdentityRegistryDispatcher, IIdentityRegistryDispatcherTrait},
    iidentity_registry_storage::IIdentityRegistryStorageDispatcher,
    itrusted_issuers_registry::ITrustedIssuersRegistryDispatcher,
};
use roles::{
    AgentRoles, agent::iagent_manager::IAgentManagerDispatcher,
    agent_role::{IAgentRoleDispatcher, IAgentRoleDispatcherTrait},
    owner::iowner_manager::IOwnerManagerDispatcher,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, mock_call,
    signature::{
        KeyPair, KeyPairTrait, SignerTrait,
        stark_curve::{StarkCurveKeyPairImpl, StarkCurveSignerImpl, StarkCurveVerifierImpl},
    },
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;
use starknet::account::AccountContractDispatcher;
use token::itoken::{ITokenDispatcher, ITokenDispatcherTrait};

#[derive(Drop)]
pub struct FullSuiteSetup {
    pub accounts: TestAccounts,
    pub onchain_id: OnchainIdentitySetup,
    pub trex_factory: ITREXFactoryDispatcher,
    pub agent_manager: IAgentManagerDispatcher,
    pub owner_manager: IOwnerManagerDispatcher,
    pub token: ITokenDispatcher,
    pub token_identity: IdentityABIDispatcher,
    pub trusted_issuers_registry: ITrustedIssuersRegistryDispatcher,
    pub claim_topics_registry: IClaimTopicsRegistryDispatcher,
    pub identity_registry: IIdentityRegistryDispatcher,
    pub identity_registry_storage: IIdentityRegistryStorageDispatcher,
    pub modular_compliance: IModularComplianceDispatcher,
}

#[derive(Drop, Copy)]
pub struct Account {
    pub account: AccountContractDispatcher,
    pub key_pair: KeyPair<felt252, felt252>,
}

#[derive(Drop, Copy)]
pub struct TestAccounts {
    pub alice: Account,
    pub bob: Account,
    pub charlie: Account,
    pub claim_issuer: Account,
    pub token_issuer: Account,
    pub token_agent: Account,
    pub token_admin: Account,
}

#[derive(Drop)]
pub struct OnchainIdentitySetup {
    pub identity_factory: IIdFactoryDispatcher,
    pub implementation_authority: IImplementationAuthorityDispatcher,
    pub claim_issuer: ClaimIssuerABIDispatcher,
    pub alice_identity: IdentityABIDispatcher,
    pub bob_identity: IdentityABIDispatcher,
    pub claim_for_alice: TestClaim,
    pub claim_for_bob: TestClaim,
}

#[derive(Drop)]
pub struct TestClaim {
    pub claim_id: felt252,
    pub topic: felt252,
    pub scheme: felt252,
    pub identity: ContractAddress,
    pub issuer: ContractAddress,
    pub signature: Signature,
    pub data: ByteArray,
    pub uri: ByteArray,
}

fn setup_full_suite() -> FullSuiteSetup {
    let accounts = setup_accounts();
    /// Declare Claim Topics Registry
    let claim_topics_registry_contract = declare("ClaimTopicsRegistry").unwrap().contract_class();
    /// Declare Claim Topics Registry
    let trusted_issuers_registry_contract = declare("TrustedIssuersRegistry")
        .unwrap()
        .contract_class();
    /// Declare Identity Registry Storage
    let identity_registry_storage_contract = declare("IdentityRegistryStorage")
        .unwrap()
        .contract_class();
    /// Declare Identity Registry
    let identity_registry_contract = declare("IdentityRegistry").unwrap().contract_class();
    /// Declare Modular Compliance
    let modular_compliance_contract = declare("ModularCompliance").unwrap().contract_class();
    /// Declare Token
    let token_contract = declare("Token").unwrap().contract_class();
    /// Declare Agent Manager
    let agent_manager_contract = declare("AgentManager").unwrap().contract_class();
    /// Declare Owner Manager
    let owner_manager_contract = declare("OwnerManager").unwrap().contract_class();

    /// TODO: Comment this out and replace with mock when sierra 1.7 is supported
    //let trex_implementation_authority_contract =
    //declare("TREXImplementationAuthority").unwrap().contract_class();
    //let version = Version {
    //    major: 4,
    //    minor: 0,
    //    patch: 0
    //};
    //
    let implementations = TREXImplementations {
        token_implementation: *token_contract.class_hash,
        ctr_implementation: *claim_topics_registry_contract.class_hash,
        ir_implementation: *identity_registry_contract.class_hash,
        irs_implementation: *identity_registry_storage_contract.class_hash,
        tir_implementation: *trusted_issuers_registry_contract.class_hash,
        mc_implementation: *modular_compliance_contract.class_hash,
    };
    //
    //let mut impl_auth_ctor_calldata: Array<felt252> = array![];
    //version.serialize(ref impl_auth_ctor_calldata);
    //implementations.serialize(ref impl_auth_ctor_calldata);
    //let (trex_implementation_authority_address, _) =
    //trex_implementatipon_authority_contract.deploy(@impl_auth_ctor_calldata).unwrap();
    let trex_implementation_authority_address = starknet::contract_address_const::<
        'IMPLEMENTATION_AUTHORITY',
    >();
    mock_implementation_authority(trex_implementation_authority_address, @implementations);
    let oid_setup = setup_onchain_id(@accounts);
    /// Declare Factory & Deploy TREXFactory
    let factory_contract = declare("TREXFactory").unwrap().contract_class();
    let (factory_address, _) = factory_contract
        .deploy(
            @array![
                trex_implementation_authority_address.into(),
                oid_setup.identity_factory.contract_address.into(),
                starknet::get_contract_address().into(),
            ],
        )
        .unwrap();

    let trex_factory = ITREXFactoryDispatcher { contract_address: factory_address };
    oid_setup.identity_factory.add_token_factory(factory_address);
    let token_details = TokenDetails {
        owner: starknet::get_contract_address(),
        name: "TREXDINO",
        symbol: "TREX",
        decimals: 0,
        irs: Zero::zero(),
        onchain_id: Zero::zero(),
        ir_agents: [accounts.token_agent.account.contract_address].span(),
        token_agents: [accounts.token_agent.account.contract_address].span(),
        /// Add compliance
        compliance_modules: [].span(),
        /// Compliance Settings
        compliance_settings: [].span(),
    };

    let claim_details = ClaimDetails {
        claim_topics: ['CLAIM_TOPIC'].span(),
        issuers: [oid_setup.claim_issuer.contract_address].span(),
        issuer_claims: [['CLAIM_TOPIC'].span()].span(),
    };

    trex_factory.deploy_TREX_suite('MY_SALT', token_details, claim_details);

    let token_address = trex_factory.get_token('MY_SALT');
    let token = ITokenDispatcher { contract_address: token_address };
    let identity_registry = token.identity_registry();
    let compliance = token.compliance();
    let token_identity_adddress = token.onchain_id();
    let identity_registry_storage = identity_registry.identity_storage();
    let trusted_issuers_registry = identity_registry.issuers_registry();
    let claim_topics_registry = identity_registry.topics_registry();

    let (agent_manager_address, _) = agent_manager_contract
        .deploy(@array![token_address.into(), accounts.token_agent.account.contract_address.into()])
        .unwrap();
    let agent_manager = IAgentManagerDispatcher { contract_address: agent_manager_address };

    let (owner_manager_address, _) = owner_manager_contract
        .deploy(@array![token_address.into(), starknet::get_contract_address().into()])
        .unwrap();
    let owner_manager = IOwnerManagerDispatcher { contract_address: owner_manager_address };

    start_cheat_caller_address(
        identity_registry.contract_address, accounts.token_agent.account.contract_address,
    );
    identity_registry
        .batch_register_identity(
            [accounts.alice.account.contract_address, accounts.bob.account.contract_address].span(),
            [oid_setup.alice_identity.contract_address, oid_setup.bob_identity.contract_address]
                .span(),
            [42, 666].span(),
        );
    stop_cheat_caller_address(identity_registry.contract_address);

    IAgentRoleDispatcher { contract_address: identity_registry.contract_address }
        .add_agent(agent_manager_address);

    start_cheat_caller_address(
        agent_manager.contract_address, accounts.token_agent.account.contract_address,
    );
    IAccessControlDispatcher { contract_address: agent_manager.contract_address }
        .grant_role(AgentRoles::AGENT_ADMIN, accounts.token_admin.account.contract_address);
    stop_cheat_caller_address(agent_manager.contract_address);

    IAgentRoleDispatcher { contract_address: token.contract_address }
        .add_agent(agent_manager_address);
    start_cheat_caller_address(
        token.contract_address, accounts.token_agent.account.contract_address,
    );
    token.mint(accounts.alice.account.contract_address, 1000);
    token.mint(accounts.bob.account.contract_address, 500);
    token.unpause();
    stop_cheat_caller_address(token.contract_address);

    FullSuiteSetup {
        accounts,
        onchain_id: oid_setup,
        trex_factory,
        agent_manager,
        owner_manager,
        token: ITokenDispatcher { contract_address: token_address },
        token_identity: IdentityABIDispatcher { contract_address: token_identity_adddress },
        trusted_issuers_registry,
        claim_topics_registry,
        identity_registry,
        identity_registry_storage,
        modular_compliance: compliance,
    }
}

/// Setup for OnchainID Contracts
fn setup_onchain_id(accounts: @TestAccounts) -> OnchainIdentitySetup {
    /// Declare ONCHAINID Contracts
    let identity_contract = declare("Identity").unwrap().contract_class();
    let claim_issuer_contract = declare("ClaimIssuer").unwrap().contract_class();
    let id_factory_contract = declare("IdFactory").unwrap().contract_class();
    /// NOTE: this contract name will collide with impl auth of ERC3643
    let implementation_authority_contract = declare("ImplementationAuthority")
        .unwrap()
        .contract_class();
    /// Deploy OID impl auth and factory
    let mut implementation_authority_ctor_data: Array<felt252> = array![];
    identity_contract.serialize(ref implementation_authority_ctor_data);
    starknet::get_contract_address().serialize(ref implementation_authority_ctor_data);
    let (implementation_authority_address, _) = implementation_authority_contract
        .deploy(@implementation_authority_ctor_data)
        .unwrap();
    let mut implementation_authority_dispatcher = IImplementationAuthorityDispatcher {
        contract_address: implementation_authority_address,
    };
    // Declare and Deploy IdFactory
    let (id_factory_address, _) = id_factory_contract
        .deploy(
            @array![
                implementation_authority_address.into(), starknet::get_contract_address().into(),
            ],
        )
        .unwrap();
    let id_factory_dispatcher = IIdFactoryDispatcher { contract_address: id_factory_address };
    /// Deploy Claim Issuer
    let (claim_issuer_address, _) = claim_issuer_contract
        .deploy(@array![(*accounts.claim_issuer.account.contract_address).into()])
        .unwrap();
    let claim_issuer_dispatcher = ClaimIssuerABIDispatcher {
        contract_address: claim_issuer_address,
    };
    /// Register keys
    start_cheat_caller_address(
        claim_issuer_address, *accounts.claim_issuer.account.contract_address,
    );
    // Register claim issuer public key as management + claim_key
    let claim_issuer_pub_key_hash = poseidon_hash_span(
        array![*accounts.claim_issuer.key_pair.public_key].span(),
    );
    claim_issuer_dispatcher.add_key(claim_issuer_pub_key_hash, 1, 1);
    claim_issuer_dispatcher.add_key(claim_issuer_pub_key_hash, 3, 1);
    stop_cheat_caller_address(claim_issuer_address);
    /// Deploy OID for Alice
    id_factory_dispatcher.create_identity(*accounts.alice.account.contract_address, 'alice');

    let alice_identity = IdentityABIDispatcher {
        contract_address: id_factory_dispatcher
            .get_identity(*accounts.alice.account.contract_address),
    };
    /// Register keys for Alice
    start_cheat_caller_address(
        alice_identity.contract_address, *accounts.alice.account.contract_address,
    );
    // Register Alice pub key as management key
    alice_identity
        .add_key(poseidon_hash_span(array![*accounts.alice.key_pair.public_key].span()), 1, 1);
    // register claim_issuer key as claim key
    alice_identity
        .add_key(
            poseidon_hash_span(
                array![(*accounts.claim_issuer.account.contract_address).into()].span(),
            ),
            3,
            1,
        );
    /// Construct and issue claim for Alice
    let claim_topic = 'CLAIM_TOPIC';
    let claim_data = "Some claim data";
    let claim_id = poseidon_hash_span(array![claim_issuer_address.into(), claim_topic].span());

    let mut serialized_claim_to_sign: Array<felt252> = array![];
    alice_identity.contract_address.serialize(ref serialized_claim_to_sign);
    claim_topic.serialize(ref serialized_claim_to_sign);
    claim_data.serialize(ref serialized_claim_to_sign);

    let hashed_claim = poseidon_hash_span(
        array!['Starknet Message', poseidon_hash_span(serialized_claim_to_sign.span())].span(),
    );

    let (r, s) = (*accounts).claim_issuer.key_pair.sign(hashed_claim).unwrap();

    let claim_for_alice = TestClaim {
        claim_id,
        identity: alice_identity.contract_address,
        issuer: claim_issuer_address,
        topic: claim_topic,
        scheme: 1,
        data: claim_data.clone(),
        signature: Signature::StarkSignature(
            StarkSignature { r, s, public_key: *accounts.claim_issuer.key_pair.public_key },
        ),
        uri: "https://example.com",
    };

    alice_identity
        .add_claim(
            claim_for_alice.topic,
            claim_for_alice.scheme,
            claim_for_alice.issuer,
            claim_for_alice.signature,
            claim_for_alice.data.clone(),
            claim_for_alice.uri.clone(),
        );
    stop_cheat_caller_address(alice_identity.contract_address);
    id_factory_dispatcher.create_identity(*accounts.bob.account.contract_address, 'bob');
    let bob_identity = IdentityABIDispatcher {
        contract_address: id_factory_dispatcher
            .get_identity((*accounts).bob.account.contract_address),
    };
    /// Register claim for Bob
    start_cheat_caller_address(
        bob_identity.contract_address, *accounts.bob.account.contract_address,
    );

    let mut serialized_claim_to_sign: Array<felt252> = array![];
    bob_identity.contract_address.serialize(ref serialized_claim_to_sign);
    claim_topic.serialize(ref serialized_claim_to_sign);
    claim_data.serialize(ref serialized_claim_to_sign);

    let hashed_claim = poseidon_hash_span(
        array!['Starknet Message', poseidon_hash_span(serialized_claim_to_sign.span())].span(),
    );

    let (r, s) = (*accounts).claim_issuer.key_pair.sign(hashed_claim).unwrap();

    let claim_for_bob = TestClaim {
        claim_id,
        identity: bob_identity.contract_address,
        issuer: claim_issuer_address,
        topic: claim_topic,
        scheme: 1,
        data: claim_data,
        signature: Signature::StarkSignature(
            StarkSignature { r, s, public_key: *accounts.claim_issuer.key_pair.public_key },
        ),
        uri: "https://example.com",
    };

    bob_identity
        .add_claim(
            claim_for_bob.topic,
            claim_for_bob.scheme,
            claim_for_bob.issuer,
            claim_for_bob.signature,
            claim_for_bob.data.clone(),
            claim_for_bob.uri.clone(),
        );
    stop_cheat_caller_address(bob_identity.contract_address);

    OnchainIdentitySetup {
        identity_factory: id_factory_dispatcher,
        implementation_authority: implementation_authority_dispatcher,
        claim_issuer: claim_issuer_dispatcher,
        alice_identity,
        bob_identity,
        claim_for_alice,
        claim_for_bob,
    }
}

fn generate_account() -> Account {
    let mock_account_contract = declare("MockAccount").unwrap().contract_class();
    let key_pair = KeyPairTrait::<felt252, felt252>::generate();
    let (account_address, _) = mock_account_contract.deploy(@array![key_pair.public_key]).unwrap();
    let account = AccountContractDispatcher { contract_address: account_address };
    Account { account, key_pair }
}

fn mock_implementation_authority(
    contract_address: ContractAddress, implementations: @TREXImplementations,
) {
    mock_call(
        contract_address,
        selector!("get_current_implementations"),
        *implementations,
        core::num::traits::Bounded::MAX,
    );
    mock_call(
        contract_address,
        selector!("get_token_implementation"),
        *implementations.token_implementation,
        core::num::traits::Bounded::MAX,
    );
    mock_call(
        contract_address,
        selector!("get_ctr_implementation"),
        *implementations.ctr_implementation,
        core::num::traits::Bounded::MAX,
    );
    mock_call(
        contract_address,
        selector!("get_ir_implementation"),
        *implementations.ir_implementation,
        core::num::traits::Bounded::MAX,
    );
    mock_call(
        contract_address,
        selector!("get_irs_implementation"),
        *implementations.irs_implementation,
        core::num::traits::Bounded::MAX,
    );
    mock_call(
        contract_address,
        selector!("get_tir_implementation"),
        *implementations.tir_implementation,
        core::num::traits::Bounded::MAX,
    );
    mock_call(
        contract_address,
        selector!("get_mc_implementation"),
        *implementations.mc_implementation,
        core::num::traits::Bounded::MAX,
    );
}

pub fn setup_accounts() -> TestAccounts {
    TestAccounts {
        alice: generate_account(),
        bob: generate_account(),
        charlie: generate_account(),
        claim_issuer: generate_account(),
        token_issuer: generate_account(),
        token_agent: generate_account(),
        token_admin: generate_account(),
    }
}

#[test]
fn test_setup() {
    setup_full_suite();
}
