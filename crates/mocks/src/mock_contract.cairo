use starknet::ContractAddress;

#[starknet::interface]
pub trait IMockContract<TContractState> {
    fn set_investor_country(ref self: TContractState, country: u16);
    fn set_identity(ref self: TContractState, account: ContractAddress, identity: ContractAddress);
    fn forced_transfer(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256,
    ) -> bool;
    fn investor_country(self: @TContractState, investor: ContractAddress) -> u16;
    fn identity_registry(self: @TContractState) -> ContractAddress;
    fn identity(self: @TContractState, account: ContractAddress) -> ContractAddress;
}

#[starknet::contract]
mod MockContract {
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    pub const E18: u256 = 1_000_000_000_000_000_000;

    #[storage]
    struct Storage {
        investor_country: u16,
        ir: Map<ContractAddress, ContractAddress>,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc20.initializer("Mock", "MCK");
        self.erc20.mint(starknet::get_caller_address(), 100 * E18);
    }

    #[abi(embed_v0)]
    impl MockContractImpl of super::IMockContract<ContractState> {
        fn set_investor_country(ref self: ContractState, country: u16) {
            self.investor_country.write(country);
        }

        fn set_identity(
            ref self: ContractState, account: ContractAddress, identity: ContractAddress,
        ) {
            self.ir.entry(account).write(identity);
        }

        fn forced_transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
        ) -> bool {
            self.erc20._transfer(from, to, amount);
            true
        }

        fn investor_country(self: @ContractState, investor: ContractAddress) -> u16 {
            self.investor_country.read()
        }

        fn identity_registry(self: @ContractState) -> ContractAddress {
            starknet::get_contract_address()
        }

        fn identity(self: @ContractState, account: ContractAddress) -> ContractAddress {
            self.ir.entry(account).read()
        }
    }
}
