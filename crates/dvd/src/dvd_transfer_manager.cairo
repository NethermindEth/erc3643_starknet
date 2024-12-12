#[starknet::contract]
mod DVDTransferManager {
    use core::{num::traits::{Pow, Zero}, poseidon::poseidon_hash_span};
    use crate::idvd_transfer_manager::{Delivery, Fee, IDVDTransferManager, TxFees};
    use openzeppelin_access::ownable::{
        OwnableComponent, interface::{IOwnableDispatcher, IOwnableDispatcherTrait},
    };
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use roles::agent_role::{IAgentRoleDispatcher, IAgentRoleDispatcherTrait};
    use starknet::{
        ContractAddress,
        storage::{Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess},
    };
    use token::itoken::{ITokenDispatcher, ITokenDispatcherTrait};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        fee: Map<felt252, Fee>,
        token_1_to_deliver: Map<felt252, Delivery>,
        token_2_to_deliver: Map<felt252, Delivery>,
        tx_nonce: felt252,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        DVDTransferInitiated: DVDTransferInitiated,
        DVDTransferExecuted: DVDTransferExecuted,
        DVDTransferCancelled: DVDTransferCancelled,
        FeeModified: FeeModified,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct DVDTransferInitiated {
        #[key]
        transfer_id: felt252,
        maker: ContractAddress,
        #[key]
        token_1: ContractAddress,
        token_1_amount: u256,
        taker: ContractAddress,
        #[key]
        token_2: ContractAddress,
        token_2_amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct DVDTransferExecuted {
        #[key]
        transfer_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct DVDTransferCancelled {
        #[key]
        transfer_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct FeeModified {
        #[key]
        parity: felt252,
        token_1: ContractAddress,
        token_2: ContractAddress,
        fee_1: u256,
        fee_2: u256,
        fee_base: u32,
        fee_1_wallet: ContractAddress,
        fee_2_wallet: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl DVDTransferManagerImpl of IDVDTransferManager<ContractState> {
        fn modify_fee(
            ref self: ContractState,
            token1: ContractAddress,
            token2: ContractAddress,
            fee1: u256,
            fee2: u256,
            fee_base: u32,
            fee1_wallet: ContractAddress,
            fee2_wallet: ContractAddress,
        ) {
            let caller = starknet::get_caller_address();
            assert(
                caller == self.ownable.owner()
                    || self.is_trex_owner(token1, caller)
                    || self.is_trex_owner(token2, caller),
                'Only owner can call',
            );
            assert(
                IERC20Dispatcher { contract_address: token1 }.total_supply().is_non_zero()
                    && IERC20Dispatcher { contract_address: token2 }.total_supply().is_non_zero(),
                'Address is not an ERC20',
            );
            assert(fee_base > 1 && fee_base < 6, 'fee_base out of range');
            let ten_pow_fee_base = 10_u256.pow(fee_base);
            assert(fee1 <= ten_pow_fee_base, 'fee1 out of range');
            assert(fee2 <= ten_pow_fee_base, 'fee2 out of range');

            if fee1.is_non_zero() {
                assert(fee1_wallet.is_non_zero(), 'fee wallet 1 zero address!');
            }

            if fee2.is_non_zero() {
                assert(fee2_wallet.is_non_zero(), 'fee wallet 2 zero address!');
            }

            let parity = self.calcualate_parity(token1, token2);
            let parity_fee = Fee {
                token_1_fee: fee1,
                token_2_fee: fee2,
                fee_base,
                fee_1_wallet: fee1_wallet,
                fee_2_wallet: fee2_wallet,
            };
            self.fee.entry(parity).write(parity_fee);
            self
                .emit(
                    FeeModified {
                        parity,
                        token_1: token1,
                        token_2: token2,
                        fee_1: fee1,
                        fee_2: fee2,
                        fee_base,
                        fee_1_wallet: fee1_wallet,
                        fee_2_wallet: fee2_wallet,
                    },
                );
            /// NOTE: We might not need this. we can sort addresses and store in single key.
            let reflect_parity = self.calcualate_parity(token2, token1);
            let reflect_parity_fee = Fee {
                token_1_fee: fee2,
                token_2_fee: fee1,
                fee_base,
                fee_1_wallet: fee2_wallet,
                fee_2_wallet: fee1_wallet,
            };
            self.fee.entry(reflect_parity).write(reflect_parity_fee);
            self
                .emit(
                    FeeModified {
                        parity: reflect_parity,
                        token_1: token2,
                        token_2: token1,
                        fee_1: fee2,
                        fee_2: fee1,
                        fee_base,
                        fee_1_wallet: fee2_wallet,
                        fee_2_wallet: fee1_wallet,
                    },
                );
        }

        fn initiate_dvd_transfer(
            ref self: ContractState,
            token1: ContractAddress,
            token1_amount: u256,
            counterpart: ContractAddress,
            token2: ContractAddress,
            token2_amount: u256,
        ) {
            let token_1_erc20_dispatcher = IERC20Dispatcher { contract_address: token1 };
            let caller = starknet::get_caller_address();
            /// NOTE: This allowance etc... looks redundant. This does not give any guarantees on
            /// settlement time.
            assert(
                token_1_erc20_dispatcher.balance_of(caller) >= token1_amount, 'Not enough balance',
            );
            assert(
                token_1_erc20_dispatcher
                    .allowance(caller, starknet::get_contract_address()) >= token1_amount,
                'Not enough allowance',
            );
            assert(counterpart.is_non_zero(), 'Counterpart cannot be null');
            assert(
                IERC20Dispatcher { contract_address: token2 }.total_supply().is_non_zero(),
                'Address is not an ERC20',
            );
            let token1_delivery = Delivery {
                counterpart: caller, token: token1, amount: token1_amount,
            };
            let token2_delivery = Delivery { counterpart, token: token2, amount: token2_amount };
            let nonce = self.tx_nonce.read();
            self.tx_nonce.write(nonce + 1);
            let transfer_id = self
                .calculate_transfer_id(
                    nonce,
                    token1_delivery.counterpart,
                    token1_delivery.token,
                    token1_delivery.amount,
                    token2_delivery.counterpart,
                    token2_delivery.token,
                    token2_delivery.amount,
                );
            self.token_1_to_deliver.entry(transfer_id).write(token1_delivery);
            self.token_2_to_deliver.entry(transfer_id).write(token2_delivery);
            self
                .emit(
                    DVDTransferInitiated {
                        transfer_id,
                        maker: token1_delivery.counterpart,
                        token_1: token1_delivery.token,
                        token_1_amount: token1_delivery.amount,
                        taker: token2_delivery.counterpart,
                        token_2: token2_delivery.token,
                        token_2_amount: token2_delivery.amount,
                    },
                );
        }

        fn take_dvd_transfer(ref self: ContractState, transfer_id: felt252) {
            let token1 = self.token_1_to_deliver.entry(transfer_id).read();
            let token2 = self.token_2_to_deliver.entry(transfer_id).read();
            assert(
                token1.counterpart.is_non_zero() && token2.counterpart.is_non_zero(),
                'Transfer ID does not exist',
            );

            let caller = starknet::get_caller_address();
            assert!(
                caller == token2.counterpart
                    || self.is_trex_agent(token1.token, caller)
                    || self.is_trex_agent(token2.token, caller),
                "Transfer has to be done by the counterpart or by owner",
            );

            let token1_dispatcher = IERC20Dispatcher { contract_address: token1.token };
            let token2_dispatcher = IERC20Dispatcher { contract_address: token2.token };
            /// NOTE: This allowance etc... looks redundant if transfer fromm succeeds it succeeds
            assert(
                token2_dispatcher.balance_of(token2.counterpart) >= token2.amount,
                'Not enough balance',
            );
            assert(
                token2_dispatcher
                    .allowance(token2.counterpart, starknet::get_contract_address()) >= token2
                    .amount,
                'Not enough allowance',
            );
            let fees = self.calculate_fee(transfer_id);
            if fees.tx_fee_1.is_non_zero() {
                token1_dispatcher
                    .transfer_from(
                        token1.counterpart, token2.counterpart, token1.amount - fees.tx_fee_1,
                    );
                token1_dispatcher
                    .transfer_from(token1.counterpart, fees.fee_1_wallet, fees.tx_fee_1);
            } else {
                token1_dispatcher
                    .transfer_from(token1.counterpart, token2.counterpart, token1.amount);
            }

            if fees.tx_fee_2.is_non_zero() {
                token2_dispatcher
                    .transfer_from(
                        token2.counterpart, token1.counterpart, token2.amount - fees.tx_fee_2,
                    );
                token2_dispatcher
                    .transfer_from(token2.counterpart, fees.fee_2_wallet, fees.tx_fee_2);
            } else {
                token2_dispatcher
                    .transfer_from(token2.counterpart, token1.counterpart, token2.amount);
            }

            self.token_1_to_deliver.entry(transfer_id).write(Default::default());
            self.token_2_to_deliver.entry(transfer_id).write(Default::default());
            self.emit(DVDTransferExecuted { transfer_id });
        }

        fn cancel_dvd_transfer(ref self: ContractState, transfer_id: felt252) {
            let token1 = self.token_1_to_deliver.entry(transfer_id).read();
            let token2 = self.token_2_to_deliver.entry(transfer_id).read();
            assert(
                token1.counterpart.is_non_zero() && token2.counterpart.is_non_zero(),
                'Transfer ID does not exist',
            );
            let caller = starknet::get_caller_address();
            assert!(
                self.ownable.owner() == caller
                    || caller == token1.counterpart
                    || caller == token2.counterpart
                    || self.is_trex_agent(token1.token, caller)
                    || self.is_trex_agent(token2.token, caller),
                "Not allowed to cancel this transfer",
            );

            self.token_1_to_deliver.entry(transfer_id).write(Default::default());
            self.token_2_to_deliver.entry(transfer_id).write(Default::default());
            self.emit(DVDTransferCancelled { transfer_id });
        }

        fn is_trex(self: @ContractState, token: ContractAddress) -> bool {
            ITokenDispatcher { contract_address: token }
                .identity_registry()
                .contract_address
                .is_non_zero()
        }

        fn is_trex_owner(
            self: @ContractState, token: ContractAddress, user: ContractAddress,
        ) -> bool {
            if self.is_trex(token) {
                return IOwnableDispatcher { contract_address: token }.owner() == user;
            }

            false
        }

        fn is_trex_agent(
            self: @ContractState, token: ContractAddress, user: ContractAddress,
        ) -> bool {
            if self.is_trex(token) {
                return IAgentRoleDispatcher { contract_address: token }.is_agent(user);
            }

            false
        }

        fn calculate_fee(self: @ContractState, transfer_id: felt252) -> TxFees {
            let token1 = self.token_1_to_deliver.entry(transfer_id).read();
            let token2 = self.token_2_to_deliver.entry(transfer_id).read();
            assert(
                token1.counterpart.is_non_zero() && token2.counterpart.is_non_zero(),
                'Transfer ID does not exist',
            );
            let parity = self.calcualate_parity(token1.token, token2.token);
            let fee_details = self.fee.entry(parity).read();
            if fee_details.token_1_fee.is_zero() || fee_details.token_2_fee.is_zero() {
                return TxFees {
                    tx_fee_1: Zero::zero(),
                    tx_fee_2: Zero::zero(),
                    fee_1_wallet: Zero::zero(),
                    fee_2_wallet: Zero::zero(),
                };
            }

            let tx_fee_1 = (token1.amount
                * fee_details.token_1_fee
                * 10_u256.pow(fee_details.fee_base - 2))
                / 10_u256.pow(fee_details.fee_base);
            let tx_fee_2 = (token2.amount
                * fee_details.token_2_fee
                * 10_u256.pow(fee_details.fee_base - 2))
                / 10_u256.pow(fee_details.fee_base);
            TxFees {
                tx_fee_1,
                tx_fee_2,
                fee_1_wallet: fee_details.fee_1_wallet,
                fee_2_wallet: fee_details.fee_2_wallet,
            }
        }

        fn calcualate_parity(
            self: @ContractState, token1: ContractAddress, token2: ContractAddress,
        ) -> felt252 {
            poseidon_hash_span(array![token1.into(), token2.into()].span())
        }

        fn calculate_transfer_id(
            self: @ContractState,
            nonce: felt252,
            maker: ContractAddress,
            token1: ContractAddress,
            token1_amount: u256,
            taker: ContractAddress,
            token2: ContractAddress,
            token2_amount: u256,
        ) -> felt252 {
            let mut serialized_data: Array<felt252> = array![];
            nonce.serialize(ref serialized_data);
            maker.serialize(ref serialized_data);
            token1.serialize(ref serialized_data);
            token1_amount.serialize(ref serialized_data);
            taker.serialize(ref serialized_data);
            token2.serialize(ref serialized_data);
            token2_amount.serialize(ref serialized_data);

            poseidon_hash_span(serialized_data.span())
        }
    }
}
