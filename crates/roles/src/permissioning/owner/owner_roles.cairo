use starknet::ContractAddress;

#[starknet::interface]
trait IOwnerRoles<TContractState> {
    fn add_owner_admin(ref self: TContractState, owner: ContractAddress);
    fn remove_owner_admin(ref self: TContractState, owner: ContractAddress);
    fn add_registry_address_setter(ref self: TContractState, owner: ContractAddress);
    fn remove_registry_address_setter(ref self: TContractState, owner: ContractAddress);
    fn add_compliance_setter(ref self: TContractState, owner: ContractAddress);
    fn remove_compliance_setter(ref self: TContractState, owner: ContractAddress);
    fn add_compliance_manager(ref self: TContractState, owner: ContractAddress);
    fn remove_compliance_manager(ref self: TContractState, owner: ContractAddress);
    fn add_claim_registry_manager(ref self: TContractState, owner: ContractAddress);
    fn remove_claim_registry_manager(ref self: TContractState, owner: ContractAddress);
    fn add_issuer_registry_manager(ref self: TContractState, owner: ContractAddress);
    fn remove_issuer_registry_manager(ref self: TContractState, owner: ContractAddress);
    fn add_token_info_manager(ref self: TContractState, owner: ContractAddress);
    fn remove_token_info_manager(ref self: TContractState, owner: ContractAddress);
    fn is_owner_admin(self: @TContractState, owner: ContractAddress) -> bool;
    fn is_token_info_manager(self: @TContractState, owner: ContractAddress) -> bool;
    fn is_issuers_registry_manager(self: @TContractState, owner: ContractAddress) -> bool;
    fn is_claim_registry_manager(self: @TContractState, owner: ContractAddress) -> bool;
    fn is_compliance_manager(self: @TContractState, owner: ContractAddress) -> bool;
    fn is_compliance_setter(self: @TContractState, owner: ContractAddress) -> bool;
    fn is_registry_address_setter(self: @TContractState, owner: ContractAddress) -> bool;
}

#[starknet::component]
mod OwnerRoles {
    use starknet::ContractAddress;
    use starknet::storage::{Map, StoragePathEntry, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    struct Storage {
        OwnerRoles_owner_admin: Map<ContractAddress, bool>,
        OwnerRoles_registry_address_setter: Map<ContractAddress, bool>,
        OwnerRoles_compliance_setter: Map<ContractAddress, bool>,
        OwnerRoles_compliance_manager: Map<ContractAddress, bool>,
        OwnerRoles_claim_registry_manager: Map<ContractAddress, bool>,
        OwnerRoles_issuers_registry_manager: Map<ContractAddress, bool>,
        OwnerRoles_token_info_manager: Map<ContractAddress, bool>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        RoleAdded: RoleAdded,
        RoleRemoved: RoleRemoved
    }

    #[derive(Drop, starknet::Event)]
    struct RoleAdded {
        #[key]
        owner: ContractAddress,
        role: ByteArray
    }

    #[derive(Drop, starknet::Event)]
    struct RoleRemoved {
        #[key]
        owner: ContractAddress,
        role: ByteArray
    }
}
