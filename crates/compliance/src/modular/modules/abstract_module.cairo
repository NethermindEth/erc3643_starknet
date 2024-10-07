#[starknet::component]
mod AbstractModule {
    use compliance::modular::modules::imodule::{IModule, ModuleEvents};

    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess,
    };
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        compliance_bound: Map<ContractAddress, bool>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    //#[embedable_as(ModuleImpl)]
    //impl ModuleImpl of IModule<ContractState>{
    //    
    //}
}
