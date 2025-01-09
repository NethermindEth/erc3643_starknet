//! TODO: Ensure address zero checks are needed or not
//! NOTE: UpdatedTokenInformation event is emitted one parameter change but it reads all the other,
//! very in efficient but due to expected rare occurance might be neglegible
//! Revise error messages
#[starknet::contract]
pub mod Token {
    use compliance::imodular_compliance::{
        IModularComplianceDispatcher, IModularComplianceDispatcherTrait,
    };
    use core::num::traits::Zero;
    use core::poseidon::poseidon_hash_span;
    use crate::itoken::IToken;
    use onchain_id_starknet::interface::iidentity::{
        IdentityABIDispatcher, IdentityABIDispatcherTrait,
    };
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_security::pausable::PausableComponent;
    use openzeppelin_token::erc20::{
        ERC20Component, ERC20HooksEmptyImpl, interface::{IERC20, IERC20Metadata},
    };
    use openzeppelin_upgrades::{interface::IUpgradeable, upgradeable::UpgradeableComponent};
    use registry::interface::iidentity_registry::{
        IIdentityRegistryDispatcher, IIdentityRegistryDispatcherTrait,
    };
    use roles::agent_role::AgentRoleComponent;
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

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    component!(path: UpgradeableComponent, storage: upgrades, event: UpgradeableEvent);

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        token_decimals: u8,
        token_onchain_id: ContractAddress,
        token_version: ByteArray,
        frozen: Map<ContractAddress, bool>,
        frozen_tokens: Map<ContractAddress, u256>,
        token_identity_registry: IIdentityRegistryDispatcher,
        token_compliance: IModularComplianceDispatcher,
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
    }

    #[derive(Drop, starknet::Event)]
    pub struct UpdatedTokenInformation {
        #[key]
        pub new_name: ByteArray,
        #[key]
        pub new_symbol: ByteArray,
        pub new_decimals: u8,
        pub new_version: ByteArray,
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

    #[constructor]
    fn constructor(
        ref self: ContractState,
        identity_registry: ContractAddress,
        compliance: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8,
        onchain_id: ContractAddress,
        owner: ContractAddress,
    ) {
        assert(owner.is_non_zero(), 'Owner is Zero Address');
        assert(identity_registry.is_non_zero(), 'Identity Registry Zero Address');
        assert(compliance.is_non_zero(), 'Compliance Zero Address');
        assert(decimals <= 18, 'Invalid Decimals: [0, 18]');
        self.ownable.initializer(owner);
        self.erc20.initializer(name, symbol);
        self.token_decimals.write(decimals);
        self.token_onchain_id.write(onchain_id);
        self.pausable.pause();
        self.set_compliance(compliance);
        self.set_identity_registry(identity_registry);
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
        /// - This function can only be called by the owner.
        /// - The `ClassHash` should already have been declared.
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgrades.upgrade(new_class_hash);
        }
    }

    #[abi(embed_v0)]
    impl TokenImpl of IToken<ContractState> {
        fn set_name(ref self: ContractState, name: ByteArray) {
            self.ownable.assert_only_owner();
            assert(name != "", 'ERC20-Name: Empty string');
            self.erc20.ERC20_name.write(name.clone());
            self
                .emit(
                    UpdatedTokenInformation {
                        new_name: name,
                        new_symbol: self.erc20.ERC20_symbol.read(),
                        new_decimals: self.token_decimals.read(),
                        new_version: self.token_version.read(),
                        new_onchain_id: self.token_onchain_id.read(),
                    },
                );
        }

        fn set_symbol(ref self: ContractState, symbol: ByteArray) {
            self.ownable.assert_only_owner();
            assert(symbol != "", 'ERC20-Symbol: Empty string');
            self.erc20.ERC20_symbol.write(symbol.clone());
            self
                .emit(
                    UpdatedTokenInformation {
                        new_name: self.erc20.ERC20_name.read(),
                        new_symbol: symbol,
                        new_decimals: self.token_decimals.read(),
                        new_version: self.token_version.read(),
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
                        new_version: self.token_version.read(),
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
            self
                .token_identity_registry
                .write(IIdentityRegistryDispatcher { contract_address: identity_registry });
            self.emit(IdentityRegistryAdded { identity_registry });
        }

        fn set_compliance(ref self: ContractState, compliance: ContractAddress) {
            self.ownable.assert_only_owner();
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
            assert(balance_of_lost_wallet.is_non_zero(), 'No tokens to recover');
            let onchain_id = IdentityABIDispatcher { contract_address: investor_onchain_id };
            let key = poseidon_hash_span(array![new_wallet.into()].span());
            assert(onchain_id.key_has_purpose(key, 1), 'Recovery not possible');
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
            ref self: ContractState,
            from_list: Span<ContractAddress>,
            to_list: Span<ContractAddress>,
            amounts: Span<u256>,
        ) {
            self.pausable.assert_not_paused();
            let caller = starknet::get_caller_address();
            assert(!self.frozen.entry(caller).read(), 'Wallet is frozen');

            let mut total_amount = 0;
            for amount in amounts {
                total_amount += *amount;
            };

            assert(
                total_amount <= self.erc20.balance_of(caller)
                    - self.frozen_tokens.entry(caller).read(),
                'Insufficient available balance',
            );

            for i in 0..to_list.len() {
                let recipient = *to_list.at(i);
                let amount = *amounts.at(i);

                assert(!self.frozen.entry(recipient).read(), 'Wallet is frozen');

                let token_compliance = self.token_compliance.read();
                assert(
                    self.token_identity_registry.read().is_verified(recipient)
                        && token_compliance.can_transfer(caller, recipient, amount),
                    'Transfer not possible',
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
                'Arrays length not parrallel',
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
            assert(to_list_len == amounts.len(), 'Arrays length not parrallel');
            for i in 0..to_list_len {
                self._mint(*to_list.at(i), *amounts.at(i));
            };
        }

        fn batch_burn(
            ref self: ContractState, user_addresses: Span<ContractAddress>, amounts: Span<u256>,
        ) {
            self.agent_role.assert_only_agent();
            let user_addresses_len = user_addresses.len();
            assert(user_addresses_len == amounts.len(), 'Arrays length not parrallel');
            for i in 0..user_addresses_len {
                self._burn(*user_addresses.at(i), *amounts.at(i));
            };
        }

        fn batch_set_address_frozen(
            ref self: ContractState, user_addresses: Span<ContractAddress>, freeze: Span<bool>,
        ) {
            self.agent_role.assert_only_agent();
            let user_addresses_len = user_addresses.len();
            assert(user_addresses_len == freeze.len(), 'Arrays length not parrallel');
            for i in 0..user_addresses_len {
                self._set_address_frozen(*user_addresses.at(i), *freeze.at(i));
            };
        }

        fn batch_freeze_partial_tokens(
            ref self: ContractState, user_addresses: Span<ContractAddress>, amounts: Span<u256>,
        ) {
            self.agent_role.assert_only_agent();
            let user_addresses_len = user_addresses.len();
            assert(user_addresses_len == amounts.len(), 'Arrays length not parrallel');
            for i in 0..user_addresses_len {
                self._freeze_partial_tokens(*user_addresses.at(i), *amounts.at(i));
            };
        }

        fn batch_unfreeze_partial_tokens(
            ref self: ContractState, user_addresses: Span<ContractAddress>, amounts: Span<u256>,
        ) {
            self.agent_role.assert_only_agent();
            let user_addresses_len = user_addresses.len();
            assert(user_addresses_len == amounts.len(), 'Arrays length not parrallel');
            for i in 0..user_addresses_len {
                self._unfreeze_partial_tokens(*user_addresses.at(i), *amounts.at(i));
            };
        }

        fn onchain_id(self: @ContractState) -> ContractAddress {
            self.token_onchain_id.read()
        }

        fn version(self: @ContractState) -> ByteArray {
            self.token_version.read()
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
                'Wallet is frozen',
            );
            assert(
                amount <= self.erc20.balance_of(caller) - self.frozen_tokens.entry(caller).read(),
                'Insufficient available balance',
            );
            let token_compliance = self.token_compliance.read();
            assert(
                self.token_identity_registry.read().is_verified(recipient)
                    && token_compliance.can_transfer(caller, recipient, amount),
                'Transfer not possible',
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
            let caller = starknet::get_caller_address();
            assert(
                !self.frozen.entry(recipient).read() && !self.frozen.entry(caller).read(),
                'Wallet is frozen',
            );
            assert(
                amount <= self.erc20.balance_of(caller) - self.frozen_tokens.entry(caller).read(),
                'Insufficient available balance',
            );
            let token_compliance = self.token_compliance.read();
            assert(
                self.token_identity_registry.read().is_verified(recipient)
                    && token_compliance.can_transfer(caller, recipient, amount),
                'Transfer not possible',
            );
            self.erc20._spend_allowance(sender, caller, amount);
            self.erc20._transfer(caller, recipient, amount);
            token_compliance.transferred(caller, recipient, amount);
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

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _forced_transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
        ) -> bool {
            let from_balance = self.erc20.balance_of(from);
            assert(from_balance >= amount, 'Sender balance insufficient');
            let from_frozen_tokens_storage = self.frozen_tokens.entry(from);
            let from_frozen_tokens = from_frozen_tokens_storage.read();
            let free_balance = from_balance - from_frozen_tokens;
            if amount > free_balance {
                let tokens_to_unfreeze = amount - free_balance;
                from_frozen_tokens_storage.write(from_frozen_tokens - tokens_to_unfreeze);
                self.emit(TokensUnfrozen { user_address: from, amount });
            }
            assert(self.token_identity_registry.read().is_verified(to), 'Transfer not possible');
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
            assert!(balance >= user_frozen_tokens + amount, "Amount exceeds available balance");
            user_frozen_tokens_storage.write(user_frozen_tokens + amount);
            self.emit(TokensFrozen { user_address, amount });
        }

        fn _unfreeze_partial_tokens(
            ref self: ContractState, user_address: ContractAddress, amount: u256,
        ) {
            let user_frozen_tokens_storage = self.frozen_tokens.entry(user_address);
            let user_frozen_tokens = user_frozen_tokens_storage.read();
            assert!(user_frozen_tokens >= amount, "Amount should be lte to frozen tokens");
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
            assert(self.token_identity_registry.read().is_verified(to), 'Identity is not verified');
            let token_compliance = self.token_compliance.read();
            assert(
                token_compliance.can_transfer(Zero::zero(), to, amount), 'Compliance not followed',
            );
            self.erc20.mint(to, amount);
            token_compliance.created(to, amount);
        }

        fn _burn(ref self: ContractState, user_address: ContractAddress, amount: u256) {
            let user_balance = self.erc20.balance_of(user_address);
            assert(user_balance >= amount, 'Cannot burn more than balance');
            let user_frozen_tokens_storage = self.frozen_tokens.entry(user_address);
            let user_frozen_tokens = user_frozen_tokens_storage.read();
            let free_balance = user_balance - user_frozen_tokens;
            if amount > free_balance {
                let tokens_to_unfreeze = amount - free_balance;
                user_frozen_tokens_storage.write(user_frozen_tokens - tokens_to_unfreeze);
                self.emit(TokensUnfrozen { user_address, amount });
            }
            self.erc20.burn(user_address, amount);
            self.token_compliance.read().destroyed(user_address, amount);
        }
    }
}
