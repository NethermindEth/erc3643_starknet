// we might utilize or modify
// https://github.com/OpenZeppelin/cairo-contracts/blob/main/packages/access/src/accesscontrol/accesscontrol.cairo
// instead of redaclaring variable again and again
use starknet::ContractAddress;

trait IRoles<TContractState> {
    fn add(ref self: TContractState, account: ContractAddress);
    fn remove(ref self: TContractState, account: ContractAddress);
    fn has(self: @TContractState, account: ContractAddress) -> bool;
}
// might turn this to a reciving storage pointer, more like lib in solidity
#[starknet::component]
pub mod RolesComponent {
    use starknet::ContractAddress;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess,};

    #[storage]
    struct Storage {
        bearer: Map<ContractAddress, bool>
    }

    pub impl RolesImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>
    > of super::IRoles<ComponentState<TContractState>> {
        fn add(ref self: ComponentState<TContractState>, account: ContractAddress) {
            assert!(!self.has(account), "Roles: account already has role");
            self.bearer.write(account, true);
        }

        fn remove(ref self: ComponentState<TContractState>, account: ContractAddress) {
            assert!(self.has(account), "Roles: account does not have role");
            self.bearer.write(account, false);
        }

        fn has(self: @ComponentState<TContractState>, account: ContractAddress) -> bool {
            assert!(
                account != starknet::contract_address_const::<0>(),
                "Roles: account is the zero address"
            );
            self.bearer.read(account)
        }
    }
}
