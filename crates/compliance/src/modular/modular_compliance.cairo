#[starknet::contract]
mod ModularCompliance {
    use compliance::modular::imodular_compliance::IModularCompliance;
    use starknet::ContractAddress;
    use starknet::storage::{
        Vec, VecTrait, MutableVecTrait, Map, StoragePathEntry, StorageMapReadAccess,
        StorageMapWriteAccess
    };

    #[storage]
    struct Storage {
        /// token linked to the compliance contract
        token_bound: ContractAddress,
        /// Array of modules bound to the compliance
        modules: Vec<ContractAddress>,
        /// Mapping of module binding status
        module_bound: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ModuleInteraction: ModuleInteraction,
        TokenBound: TokenBound,
        TokenUnbound: TokenUnbound,
        ModuleAdded: ModuleAdded,
        ModuleRemoved: ModuleRemoved
    }
    /// @dev Event emitted for each executed interaction with a module contract.
    /// For gas efficiency, only the interaction calldata selector (first 4
    /// bytes) is included in the event. For interactions without calldata or
    /// whose calldata is shorter than 4 bytes, the selector will be `0`.
    #[derive(Drop, starknet::Event)]
    struct ModuleInteraction {
        #[key]
        target: ContractAddress,
        selector: i32
    }

    /// this event is emitted when a token has been bound to the compliance contract
    /// the event is emitted by the bind_token function
    /// `token` is the address of the token to bind
    #[derive(Drop, starknet::Event)]
    struct TokenBound {
        token: ContractAddress,
    }

    ///  this event is emitted when a token has been unbound from the compliance contract
    ///  the event is emitted by the unbind_token function
    ///  `token` is the address of the token to unbind
    #[derive(Drop, starknet::Event)]
    struct TokenUnbound {
        token: ContractAddress,
    }

    ///  this event is emitted when a module has been added to the list of modules bound to the
    ///  compliance contract the event is emitted by the add_module function
    ///  `module` is the address of the compliance module
    #[derive(Drop, starknet::Event)]
    struct ModuleAdded {
        #[key]
        module: ContractAddress,
    }

    ///  this event is emitted when a module has been removed from the list of modules bound to the
    ///  compliance contract the event is emitted by the remove_module function
    ///  `module` is the address of the compliance module
    #[derive(Drop, starknet::Event)]
    struct ModuleRemoved {
        #[key]
        module: ContractAddress,
    }
    //#[abi(embed_v0)]
//impl ModularComplianceImpl of IModularCompliance<ContractState>{
//
//}
}
