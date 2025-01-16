#[starknet::contract]
pub mod TREXFactory {
    use compliance::imodular_compliance::{
        IModularComplianceDispatcher, IModularComplianceDispatcherTrait,
    };
    use core::num::traits::Zero;
    use crate::{
        iimplementation_authority::{
            IImplementationAuthorityDispatcher, IImplementationAuthorityDispatcherTrait,
        },
        itrex_factory::{ClaimDetails, ITREXFactory, TokenDetails},
    };
    use onchain_id_starknet::factory::iid_factory::{
        IIdFactoryDispatcher, IIdFactoryDispatcherTrait,
    };
    use openzeppelin_access::ownable::{
        OwnableComponent, interface::{IOwnableDispatcher, IOwnableDispatcherTrait},
    };
    use registry::interface::{
        iclaim_topics_registry::{
            IClaimTopicsRegistryDispatcher, IClaimTopicsRegistryDispatcherTrait,
        },
        iidentity_registry::IIdentityRegistryDispatcher,
        iidentity_registry_storage::{
            IIdentityRegistryStorageDispatcher, IIdentityRegistryStorageDispatcherTrait,
        },
        itrusted_issuers_registry::{
            ITrustedIssuersRegistryDispatcher, ITrustedIssuersRegistryDispatcherTrait,
        },
    };
    use roles::agent_role::{IAgentRoleDispatcher, IAgentRoleDispatcherTrait};
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress};
    use token::itoken::{ITokenDispatcher, ITokenDispatcherTrait};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        implementation_authority: ContractAddress,
        id_factory: ContractAddress,
        /// salt to token
        token_deployed: Map<felt252, ContractAddress>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Deployed: Deployed,
        IdFactorySet: IdFactorySet,
        ImplementationAuthoritySet: ImplementationAuthoritySet,
        TREXSuiteDeployed: TREXSuiteDeployed,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Deployed {
        #[key]
        pub address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IdFactorySet {
        #[key]
        pub id_factory: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ImplementationAuthoritySet {
        pub implementation_authority: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TREXSuiteDeployed {
        pub token: ContractAddress,
        pub ir: ContractAddress,
        pub irs: ContractAddress,
        pub tir: ContractAddress,
        pub ctr: ContractAddress,
        pub mc: ContractAddress,
        pub salt: felt252,
    }

    pub mod Errors {
        pub const ID_FACTORY_ZERO_ADDRESS: felt252 = 'id_factory: Zero Address';
        pub const OWNER_ZERO_ADDRESS: felt252 = 'owner: Zero Address';
        pub const IMPLEMENTATION_AUTHORITY_ZERO_ADDRESS: felt252 = 'IA: Zero Address';
        pub const TOKEN_ALREADY_DEPLOYED: felt252 = 'Token already deployed';
        pub const INVALID_CLAIM_PATTERN: felt252 = 'Invalid claim pattern';
        pub const INVALID_COMPLIANCE_PATTERN: felt252 = 'Invalid compliance pattern';
        pub const MAX_ISSUERS: felt252 = 'Max 5 issuers at deployment';
        pub const MAX_CLAIM_TOPICS: felt252 = 'Max 5 topics at deployment';
        pub const MAX_COMPLIANCE_MODULES: felt252 = 'Max 30 compliance at deployment';
        pub const MAX_AGENTS: felt252 = 'Max 5 agents at deployment';
        pub const INVALID_IMPLEMENTATION: felt252 = 'Invalid implementation: Zero';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        implementation_authority: ContractAddress,
        id_factory: ContractAddress,
        owner: ContractAddress,
    ) {
        assert(id_factory.is_non_zero(), Errors::ID_FACTORY_ZERO_ADDRESS);
        assert(owner.is_non_zero(), Errors::OWNER_ZERO_ADDRESS);
        /// Set id factory
        self.id_factory.write(id_factory);
        self.emit(IdFactorySet { id_factory });
        self._set_implementation_authority(implementation_authority);
        /// Init ownable
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl TREXFactoryImpl of ITREXFactory<ContractState> {
        fn set_implementation_authority(
            ref self: ContractState, implementation_authority: ContractAddress,
        ) {
            self.ownable.assert_only_owner();
            self._set_implementation_authority(implementation_authority);
        }

        fn set_id_factory(ref self: ContractState, id_factory: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(id_factory.is_non_zero(), Errors::ID_FACTORY_ZERO_ADDRESS);
            self.id_factory.write(id_factory);
            self.emit(IdFactorySet { id_factory });
        }

        fn deploy_TREX_suite(
            ref self: ContractState,
            salt: felt252,
            token_details: TokenDetails,
            claim_details: ClaimDetails,
        ) {
            self.ownable.assert_only_owner();
            let salt_to_token_storage = self.token_deployed.entry(salt);
            assert(salt_to_token_storage.read() == Zero::zero(), Errors::TOKEN_ALREADY_DEPLOYED);
            assert(
                claim_details.issuers.len() == claim_details.issuer_claims.len(),
                Errors::INVALID_CLAIM_PATTERN,
            );
            assert(claim_details.issuers.len() <= 5, Errors::MAX_ISSUERS);
            assert(claim_details.claim_topics.len() <= 5, Errors::MAX_CLAIM_TOPICS);
            assert(
                token_details.ir_agents.len() <= 5 && token_details.token_agents.len() <= 5,
                Errors::MAX_AGENTS,
            );
            assert(token_details.compliance_modules.len() <= 30, Errors::MAX_COMPLIANCE_MODULES);
            assert(
                token_details.compliance_modules.len() >= token_details.compliance_settings.len(),
                Errors::INVALID_COMPLIANCE_PATTERN,
            );
            let implementation_authority_address = self.implementation_authority.read();
            let implementations = IImplementationAuthorityDispatcher {
                contract_address: implementation_authority_address,
            }
                .get_current_implementations();
            let tir = ITrustedIssuersRegistryDispatcher {
                contract_address: self
                    .deploy_TIR(
                        implementations.tir_implementation, salt, implementation_authority_address,
                    ),
            };
            let ctr = IClaimTopicsRegistryDispatcher {
                contract_address: self
                    .deploy_CTR(
                        implementations.ctr_implementation, salt, implementation_authority_address,
                    ),
            };
            let mc = IModularComplianceDispatcher {
                contract_address: self
                    .deploy_MC(
                        implementations.mc_implementation, salt, implementation_authority_address,
                    ),
            };
            let irs = if token_details.irs.is_zero() {
                IIdentityRegistryStorageDispatcher {
                    contract_address: self
                        .deploy_IRS(
                            implementations.irs_implementation,
                            salt,
                            implementation_authority_address,
                        ),
                }
            } else {
                IIdentityRegistryStorageDispatcher { contract_address: token_details.irs }
            };
            let ir = IIdentityRegistryDispatcher {
                contract_address: self
                    .deploy_IR(
                        implementations.ir_implementation,
                        salt,
                        tir.contract_address,
                        ctr.contract_address,
                        irs.contract_address,
                        implementation_authority_address,
                    ),
            };
            let token_address = self
                .deploy_token(
                    implementations.token_implementation,
                    salt,
                    ir.contract_address,
                    mc.contract_address,
                    token_details.name,
                    token_details.symbol,
                    token_details.decimals,
                    token_details.onchain_id,
                    implementation_authority_address,
                );
            salt_to_token_storage.write(token_address);

            if token_details.onchain_id.is_zero() {
                let token_identity = IIdFactoryDispatcher {
                    contract_address: self.id_factory.read(),
                }
                    .create_token_identity(token_address, token_details.owner, salt);
                ITokenDispatcher { contract_address: token_address }.set_onchain_id(token_identity);
            }

            for claim_topic in claim_details.claim_topics {
                ctr.add_claim_topic(*claim_topic);
            };

            for i in 0..claim_details.issuers.len() {
                tir
                    .add_trusted_issuer(
                        *claim_details.issuers.at(i), *claim_details.issuer_claims.at(i),
                    );
            };

            irs.bind_identity_registry(ir.contract_address);
            IAgentRoleDispatcher { contract_address: ir.contract_address }.add_agent(token_address);

            for ir_agent in token_details.ir_agents {
                IAgentRoleDispatcher { contract_address: ir.contract_address }.add_agent(*ir_agent);
            };

            for token_agent in token_details.token_agents {
                IAgentRoleDispatcher { contract_address: token_address }.add_agent(*token_agent);
            };

            let compliance_settings_len = token_details.compliance_settings.len();
            for i in 0..token_details.compliance_modules.len() {
                let compliance_module = *token_details.compliance_modules.at(i);
                if !mc.is_module_bound(compliance_module) {
                    mc.add_module(compliance_module)
                }

                if i < compliance_settings_len {
                    let compliance_setting = token_details.compliance_settings.at(i);
                    mc
                        .call_module_function(
                            *compliance_setting.selector,
                            *compliance_setting.calldata,
                            compliance_module,
                        );
                }
            };

            IOwnableDispatcher { contract_address: token_address }
                .transfer_ownership(token_details.owner);
            IOwnableDispatcher { contract_address: ir.contract_address }
                .transfer_ownership(token_details.owner);
            IOwnableDispatcher { contract_address: tir.contract_address }
                .transfer_ownership(token_details.owner);
            IOwnableDispatcher { contract_address: ctr.contract_address }
                .transfer_ownership(token_details.owner);
            IOwnableDispatcher { contract_address: mc.contract_address }
                .transfer_ownership(token_details.owner);
            self
                .emit(
                    TREXSuiteDeployed {
                        token: token_address,
                        ir: ir.contract_address,
                        irs: irs.contract_address,
                        tir: tir.contract_address,
                        ctr: ctr.contract_address,
                        mc: mc.contract_address,
                        salt,
                    },
                );
        }

        fn recover_contract_ownership(
            ref self: ContractState, contract: ContractAddress, new_owner: ContractAddress,
        ) {
            self.ownable.assert_only_owner();

            IOwnableDispatcher { contract_address: contract }.transfer_ownership(new_owner);
        }

        fn get_implementation_authority(self: @ContractState) -> ContractAddress {
            self.implementation_authority.read()
        }

        fn get_id_factory(self: @ContractState) -> ContractAddress {
            self.id_factory.read()
        }

        fn get_token(self: @ContractState, salt: felt252) -> ContractAddress {
            self.token_deployed.entry(salt).read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn deploy(
            ref self: ContractState,
            salt: felt252,
            implementation_class_hash: ClassHash,
            calldata: Span<felt252>,
        ) -> ContractAddress {
            let (deployed_address, _) = starknet::syscalls::deploy_syscall(
                implementation_class_hash, salt, calldata, false,
            )
                .unwrap();
            self.emit(Deployed { address: deployed_address });
            deployed_address
        }

        fn deploy_TIR(
            ref self: ContractState,
            implementation_class_hash: ClassHash,
            salt: felt252,
            implementation_authority: ContractAddress,
        ) -> ContractAddress {
            self
                .deploy(
                    salt,
                    implementation_class_hash,
                    [implementation_authority.into(), starknet::get_contract_address().into()]
                        .span(),
                )
        }

        fn deploy_CTR(
            ref self: ContractState,
            implementation_class_hash: ClassHash,
            salt: felt252,
            implementation_authority: ContractAddress,
        ) -> ContractAddress {
            self
                .deploy(
                    salt,
                    implementation_class_hash,
                    [implementation_authority.into(), starknet::get_contract_address().into()]
                        .span(),
                )
        }

        fn deploy_MC(
            ref self: ContractState,
            implementation_class_hash: ClassHash,
            salt: felt252,
            implementation_authority: ContractAddress,
        ) -> ContractAddress {
            self
                .deploy(
                    salt,
                    implementation_class_hash,
                    [implementation_authority.into(), starknet::get_contract_address().into()]
                        .span(),
                )
        }

        fn deploy_IRS(
            ref self: ContractState,
            implementation_class_hash: ClassHash,
            salt: felt252,
            implementation_authority: ContractAddress,
        ) -> ContractAddress {
            self
                .deploy(
                    salt,
                    implementation_class_hash,
                    [implementation_authority.into(), starknet::get_contract_address().into()]
                        .span(),
                )
        }

        fn deploy_IR(
            ref self: ContractState,
            implementation_class_hash: ClassHash,
            salt: felt252,
            trusted_issuers_registry: ContractAddress,
            claim_topics_registry: ContractAddress,
            identity_storage: ContractAddress,
            implementation_authority: ContractAddress,
        ) -> ContractAddress {
            self
                .deploy(
                    salt,
                    implementation_class_hash,
                    [
                        trusted_issuers_registry.into(), claim_topics_registry.into(),
                        identity_storage.into(), implementation_authority.into(),
                        starknet::get_contract_address().into(),
                    ]
                        .span(),
                )
        }

        fn deploy_token(
            ref self: ContractState,
            implementation_class_hash: ClassHash,
            salt: felt252,
            identity_registry: ContractAddress,
            compliance: ContractAddress,
            name: ByteArray,
            symbol: ByteArray,
            decimals: u8,
            onchain_id: ContractAddress,
            implementation_authority: ContractAddress,
        ) -> ContractAddress {
            let mut ctor_calldata: Array<felt252> = array![
                identity_registry.into(), compliance.into(),
            ];
            name.serialize(ref ctor_calldata);
            symbol.serialize(ref ctor_calldata);
            decimals.serialize(ref ctor_calldata);
            onchain_id.serialize(ref ctor_calldata);
            implementation_authority.serialize(ref ctor_calldata);
            starknet::get_contract_address().serialize(ref ctor_calldata);
            self.deploy(salt, implementation_class_hash, ctor_calldata.span())
        }

        fn _set_implementation_authority(
            ref self: ContractState, implementation_authority: ContractAddress,
        ) {
            assert(
                implementation_authority.is_non_zero(),
                Errors::IMPLEMENTATION_AUTHORITY_ZERO_ADDRESS,
            );
            let implementations = IImplementationAuthorityDispatcher {
                contract_address: implementation_authority,
            }
                .get_current_implementations();

            assert(
                implementations.ctr_implementation.is_non_zero()
                    && implementations.ir_implementation.is_non_zero()
                    && implementations.irs_implementation.is_non_zero()
                    && implementations.tir_implementation.is_non_zero()
                    && implementations.mc_implementation.is_non_zero()
                    && implementations.token_implementation.is_non_zero(),
                Errors::INVALID_IMPLEMENTATION,
            );
            self.implementation_authority.write(implementation_authority);
            self.emit(ImplementationAuthoritySet { implementation_authority });
        }
    }
}
