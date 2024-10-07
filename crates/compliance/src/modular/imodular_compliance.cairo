use starknet::ContractAddress;

#[event]
#[derive(Drop, starknet::Event)]
pub enum ModularComplianceEvent {
    ModuleInteraction: ModuleInteraction,
    TokenBound: TokenBound,
    TokenUnbound: TokenUnbound,
    ModuleAdded: ModuleAdded,
    ModuleRemoved: ModuleRemoved,
}

#[derive(Drop, starknet::Event)]
pub struct ModuleInteraction {
    #[key]
    target: ContractAddress,
    selector: u32
}

#[derive(Drop, starknet::Event)]
pub struct TokenBound {
    token: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct TokenUnbound {
    token: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct ModuleAdded {
    #[key]
    module: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct ModuleRemoved {
    #[key]
    module: ContractAddress,
}

#[starknet::interface]
pub trait IModularCompliance<TContractState> {
    ///  @dev binds a token to the compliance contract
    ///  @param _token address of the token to bind
    ///  This function can be called ONLY by the owner of the compliance contract
    ///  Emits a TokenBound event
    fn bind_token(ref self: TContractState, token: ContractAddress);


    /// @dev unbinds a token from the compliance contract
    /// @param _token address of the token to unbind
    /// This function can be called ONLY by the owner of the compliance contract
    /// Emits a TokenUnbound event
    fn unbind_token(ref self: TContractState, token: ContractAddress);

    /// @dev adds a module to the list of compliance modules
    /// @param _module address of the module to add
    /// there cannot be more than 25 modules bound to the modular compliance for gas cost reasons
    /// This function can be called ONLY by the owner of the compliance contract
    /// Emits a ModuleAdded event
    fn add_module(ref self: TContractState, module: ContractAddress);

    /// @dev removes a module from the list of compliance modules
    /// @param _module address of the module to remove
    /// This function can be called ONLY by the owner of the compliance contract
    /// Emits a ModuleRemoved event
    fn remove_module(ref self: TContractState, module: ContractAddress);

    /// @dev calls any function on bound modules
    /// can be called only on bound modules
    /// @param callData the bytecode for interaction with the module, abi encoded
    /// @param _module The address of the module
    /// This function can be called only by the modular compliance owner
    /// emits a `ModuleInteraction` event
    fn call_module_function(ref self: TContractState, calldata: ByteArray, module: ContractAddress);

    /// @dev function called whenever tokens are transferred
    /// from one wallet to another
    /// this function can update state variables in the modules bound to the compliance
    /// these state variables being used by the module checks to decide if a transfer
    /// is compliant or not depending on the values stored in these state variables and on
    /// the parameters of the modules
    /// This function can be called ONLY by the token contract bound to the compliance
    /// @param _from The address of the sender
    /// @param _to The address of the receiver
    /// @param _amount The amount of tokens involved in the transfer
    /// This function calls moduleTransferAction() on each module bound to the compliance contract
    fn transferred(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256
    );

    ///  @dev function called whenever tokens are created on a wallet
    ///  this function can update state variables in the modules bound to the compliance
    ///  these state variables being used by the module checks to decide if a transfer
    ///  is compliant or not depending on the values stored in these state variables and on
    ///  the parameters of the modules
    ///  This function can be called ONLY by the token contract bound to the compliance
    ///  @param _to The address of the receiver
    ///  @param _amount The amount of tokens involved in the minting
    ///  This function calls moduleMintAction() on each module bound to the compliance contract
    fn created(ref self: TContractState, to: ContractAddress, amount: u256);

    /// @dev function called whenever tokens are destroyed from a wallet
    /// this function can update state variables in the modules bound to the compliance
    /// these state variables being used by the module checks to decide if a transfer
    /// is compliant or not depending on the values stored in these state variables and on
    /// the parameters of the modules
    /// This function can be called ONLY by the token contract bound to the compliance
    /// @param _from The address on which tokens are burnt
    /// @param _amount The amount of tokens involved in the burn
    /// This function calls moduleBurnAction() on each module bound to the compliance contract
    fn destroyed(ref self: TContractState, from: ContractAddress, amount: u256);

    ///  @dev checks that the transfer is compliant.
    ///  default compliance always returns true
    ///  READ ONLY FUNCTION, this function cannot be used to increment
    ///  counters, emit events, ...
    ///  @param _from The address of the sender
    ///  @param _to The address of the receiver
    ///  @param _amount The amount of tokens involved in the transfer
    ///  This function will call moduleCheck() on every module bound to the compliance
    ///  If each of the module checks return TRUE, this function will return TRUE as well
    ///  returns FALSE otherwise
    fn can_transfer(
        self: @TContractState, from: ContractAddress, to: ContractAddress, amount: u256
    ) -> bool;

    ///  @dev getter for the modules bound to the compliance contract
    ///  returns address array of module contracts bound to the compliance
    fn get_modules(self: @TContractState) -> Array<ContractAddress>;

    /// @dev getter for the address of the token bound
    /// returns the address of the token
    fn get_token_bound(self: @TContractState) -> ContractAddress;

    /// @dev checks if a module is bound to the compliance contract
    /// returns true if module is bound, false otherwise
    fn is_module_bound(self: @TContractState, module: ContractAddress) -> bool;
}

