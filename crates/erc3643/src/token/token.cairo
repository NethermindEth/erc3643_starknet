#[starknet::contract]
pub mod Token {
    use core::num::traits::Zero;
    use core::poseidon::poseidon_hash_span;
    use crate::compliance::imodular_compliance::{
        IModularComplianceDispatcher, IModularComplianceDispatcherTrait,
    };
    use crate::registry::interface::iidentity_registry::{
        IIdentityRegistryDispatcher, IIdentityRegistryDispatcherTrait,
    };
    use crate::roles::agent_role::AgentRoleComponent;
    use crate::token::itoken::{ITOKEN_ID, IToken};
    use onchain_id_starknet::interface::iidentity::{
        IdentityABIDispatcher, IdentityABIDispatcherTrait,
    };
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_security::pausable::PausableComponent;
    use openzeppelin_token::erc20::{
        ERC20Component, ERC20HooksEmptyImpl, interface::{IERC20, IERC20Metadata},
    };
    use openzeppelin_upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use openzeppelin_utils::cryptography::{nonces::NoncesComponent, snip12::SNIP12Metadata};
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    component!(path: AgentRoleComponent, storage: agent_role, event: AgentRoleEvent);

    #[abi(embed_v0)]
    impl AgentRoleImpl = AgentRoleComponent::AgentRoleImpl<ContractState>;
    impl AgentRoleInternalImpl = AgentRoleComponent::InternalImpl<ContractState>;

    component!(path: PausableComponent, storage: pausable, event: PausableEvent);

    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;

    component!(path: NoncesComponent, storage: nonces, event: NoncesEvent);

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20PermitImpl = ERC20Component::ERC20PermitImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl SNIP12MetadataExternal =
        ERC20Component::SNIP12MetadataExternalImpl<ContractState>;

    component!(path: UpgradeableComponent, storage: upgrades, event: UpgradeableEvent);

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    pub const TOKEN_VERSION: felt252 = '0.1.0';

    #[storage]
    struct Storage {
        token_decimals: u8,
        token_onchain_id: ContractAddress,
        frozen: Map<ContractAddress, bool>,
        frozen_tokens: Map<ContractAddress, u256>,
        token_identity_registry: IIdentityRegistryDispatcher,
        token_compliance: IModularComplianceDispatcher,
        implementation_authority: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        agent_role: AgentRoleComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        upgrades: UpgradeableComponent::Storage,
        #[substorage(v0)]
        nonces: NoncesComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        UpdatedTokenInformation: UpdatedTokenInformation,
        IdentityRegistryAdded: IdentityRegistryAdded,
        ComplianceAdded: ComplianceAdded,
        RecoverySuccess: RecoverySuccess,
        AddressFrozen: AddressFrozen,
        TokensFrozen: TokensFrozen,
        TokensUnfrozen: TokensUnfrozen,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        AgentRoleEvent: AgentRoleComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        NoncesEvent: NoncesComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct UpdatedTokenInformation {
        #[key]
        pub new_name: ByteArray,
        #[key]
        pub new_symbol: ByteArray,
        pub new_decimals: u8,
        pub new_version: felt252,
        #[key]
        pub new_onchain_id: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct IdentityRegistryAdded {
        #[key]
        pub identity_registry: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ComplianceAdded {
        #[key]
        pub compliance: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RecoverySuccess {
        #[key]
        pub lost_wallet: ContractAddress,
        #[key]
        pub new_wallet: ContractAddress,
        #[key]
        pub investor_onchain_id: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AddressFrozen {
        #[key]
        pub user_address: ContractAddress,
        #[key]
        pub is_frozen: bool,
        #[key]
        pub owner: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokensFrozen {
        #[key]
        pub user_address: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokensUnfrozen {
        #[key]
        pub user_address: ContractAddress,
        pub amount: u256,
    }

    pub mod Errors {
        pub const OWNER_ZERO_ADDRESS: felt252 = 'Owner is Zero Address';
        pub const IDENTITY_REGISTRY_ZERO_ADDRESS: felt252 = 'Identity Registry Zero Address';
        pub const COMPLIANCE_ZERO_ADDRESS: felt252 = 'Compliance Zero Address';
        pub const IMPLEMENTATION_AUTHORITY_ZERO_ADDRESS: felt252 = 'Impl. Auth. Zero Address';
        pub const INVALID_DECIMALS: felt252 = 'Invalid Decimals: [0, 18]';
        pub const CALLER_NOT_IMPLEMENTATION_AUTHORITY: felt252 = 'Caller is not Impl. Auth.';
        pub const ERC20_EMPTY_NAME: felt252 = 'ERC20-Name: Empty string';
        pub const ERC20_EMPTY_SYMBOL: felt252 = 'ERC20-Symbol: Empty string';
        pub const NO_TOKENS_TO_RECOVER: felt252 = 'No tokens to recover';
        pub const RECOVERY_WALLET_NOT_AUTHORIZED: felt252 = 'Recovery wallet not authorized';
        pub const ARRAY_LENGTHS_NOT_PARALLEL: felt252 = 'Array lengths not parallel';
        pub const WALLET_IS_FROZEN: felt252 = 'Wallet is frozen';
        pub const INSUFFICIENT_AVAILABLE_BALANCE: felt252 = 'Insufficient available balance';
        pub const AMOUNT_EXCEEDS_AVAILABLE_FUNDS: felt252 = 'Amount exceeds available funds';
        pub const AMOUNT_EXCEEDS_FROZEN_TOKENS: felt252 = 'Amount exceeds frozen tokens';
        pub const IDENTITY_NOT_VERIFIED: felt252 = 'Identity is not verified';
        pub const COMPLIANCE_CHECK_FAILED: felt252 = 'Compliance check failed';
        pub const BURN_AMOUNT_EXCEEDS_BALANCE: felt252 = 'Burn amount exceeds balance';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        identity_registry: ContractAddress,
        compliance: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8,
        onchain_id: ContractAddress,
        implementation_authority: ContractAddress,
        owner: ContractAddress,
    ) {
        assert(owner.is_non_zero(), Errors::OWNER_ZERO_ADDRESS);
        assert(identity_registry.is_non_zero(), Errors::IDENTITY_REGISTRY_ZERO_ADDRESS);
        assert(compliance.is_non_zero(), Errors::COMPLIANCE_ZERO_ADDRESS);
        assert(decimals <= 18, Errors::INVALID_DECIMALS);
        assert(
            implementation_authority.is_non_zero(), Errors::IMPLEMENTATION_AUTHORITY_ZERO_ADDRESS,
        );
        self.ownable.initializer(owner);
        self.erc20.initializer(name, symbol);
        self.token_decimals.write(decimals);
        self.token_onchain_id.write(onchain_id);
        self.implementation_authority.write(implementation_authority);
        self.pausable.pause();
        self.set_compliance(compliance);
        self.set_identity_registry(identity_registry);
        self.src5.register_interface(ITOKEN_ID);
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        /// Upgrades the implementation used by this contract.
        ///
        /// # Arguments
        ///
        /// - `new_class_hash` A `ClassHash` representing the implementation to update to.
        ///
        /// # Requirements
        ///
        /// - This function can only be called by the implementation authority.
        /// - The `ClassHash` should already have been declared.
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            assert(
                self.implementation_authority.read() == starknet::get_caller_address(),
                Errors::CALLER_NOT_IMPLEMENTATION_AUTHORITY,
            );
            self.upgrades.upgrade(new_class_hash);
        }
    }

    #[abi(embed_v0)]
    impl TokenImpl of IToken<ContractState> {
        fn set_name(ref self: ContractState, name: ByteArray) {
            self.ownable.assert_only_owner();
            assert(name != "", Errors::ERC20_EMPTY_NAME);
            self.erc20.ERC20_name.write(name.clone());
            self
                .emit(
                    UpdatedTokenInformation {
                        new_name: name,
                        new_symbol: self.erc20.ERC20_symbol.read(),
                        new_decimals: self.token_decimals.read(),
                        new_version: TOKEN_VERSION,
                        new_onchain_id: self.token_onchain_id.read(),
                    },
                );
        }

        fn set_symbol(ref self: ContractState, symbol: ByteArray) {
            self.ownable.assert_only_owner();
            assert(symbol != "", Errors::ERC20_EMPTY_SYMBOL);
            self.erc20.ERC20_symbol.write(symbol.clone());
            self
                .emit(
                    UpdatedTokenInformation {
                        new_name: self.erc20.ERC20_name.read(),
                        new_symbol: symbol,
                        new_decimals: self.token_decimals.read(),
                        new_version: TOKEN_VERSION,
                        new_onchain_id: self.token_onchain_id.read(),
                    },
                );
        }

        fn set_onchain_id(ref self: ContractState, onchain_id: ContractAddress) {
            self.ownable.assert_only_owner();
            self.token_onchain_id.write(onchain_id);
            self
                .emit(
                    UpdatedTokenInformation {
                        new_name: self.erc20.ERC20_name.read(),
                        new_symbol: self.erc20.ERC20_symbol.read(),
                        new_decimals: self.token_decimals.read(),
                        new_version: TOKEN_VERSION,
                        new_onchain_id: onchain_id,
                    },
                );
        }

        fn pause(ref self: ContractState) {
            self.agent_role.assert_only_agent();
            self.pausable.pause();
        }

        fn unpause(ref self: ContractState) {
            self.agent_role.assert_only_agent();
            self.pausable.unpause();
        }

        fn set_address_frozen(
            ref self: ContractState, user_address: ContractAddress, freeze: bool,
        ) {
            self.agent_role.assert_only_agent();
            self._set_address_frozen(user_address, freeze);
        }

        fn freeze_partial_tokens(
            ref self: ContractState, user_address: ContractAddress, amount: u256,
        ) {
            self.agent_role.assert_only_agent();
            self._freeze_partial_tokens(user_address, amount);
        }

        fn unfreeze_partial_tokens(
            ref self: ContractState, user_address: ContractAddress, amount: u256,
        ) {
            self.agent_role.assert_only_agent();
            self._unfreeze_partial_tokens(user_address, amount);
        }

        fn set_identity_registry(ref self: ContractState, identity_registry: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(identity_registry.is_non_zero(), Errors::IDENTITY_REGISTRY_ZERO_ADDRESS);
            self
                .token_identity_registry
                .write(IIdentityRegistryDispatcher { contract_address: identity_registry });
            self.emit(IdentityRegistryAdded { identity_registry });
        }

        fn set_compliance(ref self: ContractState, compliance: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(compliance.is_non_zero(), Errors::COMPLIANCE_ZERO_ADDRESS);
            let current_compliance = self.token_compliance.read();
            let this_address = starknet::get_contract_address();
            if current_compliance.contract_address.is_non_zero() {
                current_compliance.unbind_token(this_address);
            }
            let new_compliance = IModularComplianceDispatcher { contract_address: compliance };
            self.token_compliance.write(new_compliance);
            new_compliance.bind_token(this_address);
            self.emit(ComplianceAdded { compliance });
        }

        fn forced_transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
        ) -> bool {
            self.agent_role.assert_only_agent();
            self._forced_transfer(from, to, amount)
        }

        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            self.agent_role.assert_only_agent();
            self._mint(to, amount);
        }

        fn burn(ref self: ContractState, user_address: ContractAddress, amount: u256) {
            self.agent_role.assert_only_agent();
            self._burn(user_address, amount);
        }

        fn recovery_address(
            ref self: ContractState,
            lost_wallet: ContractAddress,
            new_wallet: ContractAddress,
            investor_onchain_id: ContractAddress,
        ) -> bool {
            self.agent_role.assert_only_agent();
            let balance_of_lost_wallet = self.erc20.balance_of(lost_wallet);
            assert(balance_of_lost_wallet.is_non_zero(), Errors::NO_TOKENS_TO_RECOVER);
            let onchain_id = IdentityABIDispatcher { contract_address: investor_onchain_id };
            let key = poseidon_hash_span(array![new_wallet.into()].span());
            assert(onchain_id.key_has_purpose(key, 1), Errors::RECOVERY_WALLET_NOT_AUTHORIZED);
            let frozen_tokens_of_lost_wallet = self.frozen_tokens.entry(lost_wallet).read();
            let token_identity_registry = self.token_identity_registry.read();
            token_identity_registry
                .register_identity(
                    new_wallet,
                    onchain_id.contract_address,
                    token_identity_registry.investor_country(lost_wallet),
                );
            self.forced_transfer(lost_wallet, new_wallet, balance_of_lost_wallet);
            if frozen_tokens_of_lost_wallet.is_non_zero() {
                self.freeze_partial_tokens(new_wallet, frozen_tokens_of_lost_wallet);
            }

            if self.frozen.entry(lost_wallet).read() {
                self.set_address_frozen(new_wallet, true);
            }

            token_identity_registry.delete_identity(lost_wallet);
            self.emit(RecoverySuccess { lost_wallet, new_wallet, investor_onchain_id });
            true
        }

        fn batch_transfer(
            ref self: ContractState, to_list: Span<ContractAddress>, amounts: Span<u256>,
        ) {
            self.pausable.assert_not_paused();
            assert(to_list.len() == amounts.len(), Errors::ARRAY_LENGTHS_NOT_PARALLEL);
            let caller = starknet::get_caller_address();
            assert(!self.frozen.entry(caller).read(), Errors::WALLET_IS_FROZEN);

            let mut total_amount = 0;
            for amount in amounts {
                total_amount += *amount;
            };

            assert(
                total_amount <= self.erc20.balance_of(caller)
                    - self.frozen_tokens.entry(caller).read(),
                Errors::INSUFFICIENT_AVAILABLE_BALANCE,
            );

            for i in 0..to_list.len() {
                let recipient = *to_list.at(i);
                let amount = *amounts.at(i);

                assert(!self.frozen.entry(recipient).read(), Errors::WALLET_IS_FROZEN);

                let token_compliance = self.token_compliance.read();
                assert(
                    self.token_identity_registry.read().is_verified(recipient),
                    Errors::IDENTITY_NOT_VERIFIED,
                );
                assert(
                    token_compliance.can_transfer(caller, recipient, amount),
                    Errors::COMPLIANCE_CHECK_FAILED,
                );
                self.erc20._transfer(caller, recipient, amount);
                token_compliance.transferred(caller, recipient, amount);
            };
        }

        fn batch_forced_transfer(
            ref self: ContractState,
            from_list: Span<ContractAddress>,
            to_list: Span<ContractAddress>,
            amounts: Span<u256>,
        ) {
            self.agent_role.assert_only_agent();
            let to_list_len = to_list.len();
            assert(
                from_list.len() == to_list_len && to_list_len == amounts.len(),
                Errors::ARRAY_LENGTHS_NOT_PARALLEL,
            );
            for i in 0..to_list_len {
                self._forced_transfer(*from_list.at(i), *to_list.at(i), *amounts.at(i));
            };
        }

        fn batch_mint(
            ref self: ContractState, to_list: Span<ContractAddress>, amounts: Span<u256>,
        ) {
            self.agent_role.assert_only_agent();
            let to_list_len = to_list.len();
            assert(to_list_len == amounts.len(), Errors::ARRAY_LENGTHS_NOT_PARALLEL);
            for i in 0..to_list_len {
                self._mint(*to_list.at(i), *amounts.at(i));
            };
        }

        fn batch_burn(
            ref self: ContractState, user_addresses: Span<ContractAddress>, amounts: Span<u256>,
        ) {
            self.agent_role.assert_only_agent();
            let user_addresses_len = user_addresses.len();
            assert(user_addresses_len == amounts.len(), Errors::ARRAY_LENGTHS_NOT_PARALLEL);
            for i in 0..user_addresses_len {
                self._burn(*user_addresses.at(i), *amounts.at(i));
            };
        }

        fn batch_set_address_frozen(
            ref self: ContractState, user_addresses: Span<ContractAddress>, freeze: Span<bool>,
        ) {
            self.agent_role.assert_only_agent();
            let user_addresses_len = user_addresses.len();
            assert(user_addresses_len == freeze.len(), Errors::ARRAY_LENGTHS_NOT_PARALLEL);
            for i in 0..user_addresses_len {
                self._set_address_frozen(*user_addresses.at(i), *freeze.at(i));
            };
        }

        fn batch_freeze_partial_tokens(
            ref self: ContractState, user_addresses: Span<ContractAddress>, amounts: Span<u256>,
        ) {
            self.agent_role.assert_only_agent();
            let user_addresses_len = user_addresses.len();
            assert(user_addresses_len == amounts.len(), Errors::ARRAY_LENGTHS_NOT_PARALLEL);
            for i in 0..user_addresses_len {
                self._freeze_partial_tokens(*user_addresses.at(i), *amounts.at(i));
            };
        }

        fn batch_unfreeze_partial_tokens(
            ref self: ContractState, user_addresses: Span<ContractAddress>, amounts: Span<u256>,
        ) {
            self.agent_role.assert_only_agent();
            let user_addresses_len = user_addresses.len();
            assert(user_addresses_len == amounts.len(), Errors::ARRAY_LENGTHS_NOT_PARALLEL);
            for i in 0..user_addresses_len {
                self._unfreeze_partial_tokens(*user_addresses.at(i), *amounts.at(i));
            };
        }

        fn onchain_id(self: @ContractState) -> ContractAddress {
            self.token_onchain_id.read()
        }

        fn version(self: @ContractState) -> felt252 {
            TOKEN_VERSION
        }

        fn identity_registry(self: @ContractState) -> IIdentityRegistryDispatcher {
            self.token_identity_registry.read()
        }

        fn compliance(self: @ContractState) -> IModularComplianceDispatcher {
            self.token_compliance.read()
        }

        fn is_frozen(self: @ContractState, user_address: ContractAddress) -> bool {
            self.frozen.entry(user_address).read()
        }

        fn get_frozen_tokens(self: @ContractState, user_address: ContractAddress) -> u256 {
            self.frozen_tokens.entry(user_address).read()
        }
    }

    #[abi(embed_v0)]
    impl ERC3643_ERC20Impl of IERC20<ContractState> {
        fn total_supply(self: @ContractState) -> u256 {
            self.erc20.total_supply()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.erc20.balance_of(account)
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress,
        ) -> u256 {
            self.erc20.allowance(owner, spender)
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            self.pausable.assert_not_paused();
            let caller = starknet::get_caller_address();
            assert(
                !self.frozen.entry(recipient).read() && !self.frozen.entry(caller).read(),
                Errors::WALLET_IS_FROZEN,
            );
            assert(
                amount <= self.erc20.balance_of(caller) - self.frozen_tokens.entry(caller).read(),
                Errors::INSUFFICIENT_AVAILABLE_BALANCE,
            );
            let token_compliance = self.token_compliance.read();
            assert(
                self.token_identity_registry.read().is_verified(recipient),
                Errors::IDENTITY_NOT_VERIFIED,
            );
            assert(
                token_compliance.can_transfer(caller, recipient, amount),
                Errors::COMPLIANCE_CHECK_FAILED,
            );
            self.erc20._transfer(caller, recipient, amount);
            token_compliance.transferred(caller, recipient, amount);
            true
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) -> bool {
            self.pausable.assert_not_paused();
            assert(
                !self.frozen.entry(recipient).read() && !self.frozen.entry(sender).read(),
                Errors::WALLET_IS_FROZEN,
            );
            assert(
                amount <= self.erc20.balance_of(sender) - self.frozen_tokens.entry(sender).read(),
                Errors::INSUFFICIENT_AVAILABLE_BALANCE,
            );
            let token_compliance = self.token_compliance.read();
            assert(
                self.token_identity_registry.read().is_verified(recipient),
                Errors::IDENTITY_NOT_VERIFIED,
            );
            assert(
                token_compliance.can_transfer(sender, recipient, amount),
                Errors::COMPLIANCE_CHECK_FAILED,
            );
            self.erc20._spend_allowance(sender, starknet::get_caller_address(), amount);
            self.erc20._transfer(sender, recipient, amount);
            token_compliance.transferred(sender, recipient, amount);
            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            self.erc20.approve(spender, amount)
        }
    }

    #[abi(embed_v0)]
    impl ERC20MetadataImpl of IERC20Metadata<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            self.erc20.ERC20_name.read()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.erc20.ERC20_symbol.read()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.token_decimals.read()
        }
    }

    pub impl SNIP12MetadataImpl of SNIP12Metadata {
        fn name() -> felt252 {
            'ERC3643_TOKEN'
        }

        fn version() -> felt252 {
            TOKEN_VERSION
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _forced_transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
        ) -> bool {
            let from_balance = self.erc20.balance_of(from);
            assert(from_balance >= amount, ERC20Component::Errors::INSUFFICIENT_BALANCE);
            let from_frozen_tokens_storage = self.frozen_tokens.entry(from);
            let from_frozen_tokens = from_frozen_tokens_storage.read();
            let free_balance = from_balance - from_frozen_tokens;
            if amount > free_balance {
                let tokens_to_unfreeze = amount - free_balance;
                from_frozen_tokens_storage.write(from_frozen_tokens - tokens_to_unfreeze);
                self.emit(TokensUnfrozen { user_address: from, amount: tokens_to_unfreeze });
            }
            assert(
                self.token_identity_registry.read().is_verified(to), Errors::IDENTITY_NOT_VERIFIED,
            );
            self.erc20._transfer(from, to, amount);
            self.token_compliance.read().transferred(from, to, amount);
            true
        }

        fn _freeze_partial_tokens(
            ref self: ContractState, user_address: ContractAddress, amount: u256,
        ) {
            let balance = self.erc20.balance_of(user_address);
            let user_frozen_tokens_storage = self.frozen_tokens.entry(user_address);
            let user_frozen_tokens = user_frozen_tokens_storage.read();
            assert(balance >= user_frozen_tokens + amount, Errors::AMOUNT_EXCEEDS_AVAILABLE_FUNDS);
            user_frozen_tokens_storage.write(user_frozen_tokens + amount);
            self.emit(TokensFrozen { user_address, amount });
        }

        fn _unfreeze_partial_tokens(
            ref self: ContractState, user_address: ContractAddress, amount: u256,
        ) {
            let user_frozen_tokens_storage = self.frozen_tokens.entry(user_address);
            let user_frozen_tokens = user_frozen_tokens_storage.read();
            assert(user_frozen_tokens >= amount, Errors::AMOUNT_EXCEEDS_FROZEN_TOKENS);
            user_frozen_tokens_storage.write(user_frozen_tokens - amount);
            self.emit(TokensUnfrozen { user_address, amount });
        }

        fn _set_address_frozen(
            ref self: ContractState, user_address: ContractAddress, freeze: bool,
        ) {
            self.frozen.entry(user_address).write(freeze);
            self
                .emit(
                    AddressFrozen {
                        user_address, is_frozen: freeze, owner: starknet::get_caller_address(),
                    },
                );
        }

        fn _mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            assert(
                self.token_identity_registry.read().is_verified(to), Errors::IDENTITY_NOT_VERIFIED,
            );
            let token_compliance = self.token_compliance.read();
            assert(
                token_compliance.can_transfer(Zero::zero(), to, amount),
                Errors::COMPLIANCE_CHECK_FAILED,
            );
            self.erc20.mint(to, amount);
            token_compliance.created(to, amount);
        }

        fn _burn(ref self: ContractState, user_address: ContractAddress, amount: u256) {
            let user_balance = self.erc20.balance_of(user_address);
            assert(user_balance >= amount, Errors::BURN_AMOUNT_EXCEEDS_BALANCE);
            let user_frozen_tokens_storage = self.frozen_tokens.entry(user_address);
            let user_frozen_tokens = user_frozen_tokens_storage.read();
            let free_balance = user_balance - user_frozen_tokens;
            if amount > free_balance {
                let tokens_to_unfreeze = amount - free_balance;
                user_frozen_tokens_storage.write(user_frozen_tokens - tokens_to_unfreeze);
                self.emit(TokensUnfrozen { user_address, amount: tokens_to_unfreeze });
            }
            self.erc20.burn(user_address, amount);
            self.token_compliance.read().destroyed(user_address, amount);
        }
    }
}
