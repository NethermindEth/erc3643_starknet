use core::num::traits::Zero;
use dva::dva_transfer_manager::DVATransferManager;
use dva::idva_transfer_manager::{
    DelegatedApproval, DelegatedApprovalMessage, DelegatedApprovalMessageStructHash, Events::*,
    IDVATransferManagerDispatcher, IDVATransferManagerDispatcherTrait, TransferStatus,
};
use factory::tests_common::{FullSuiteSetup, setup_full_suite};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use registry::interface::iidentity_registry::IIdentityRegistryDispatcherTrait;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};

fn setup_full_suite_with_transfer_manager() -> (FullSuiteSetup, IDVATransferManagerDispatcher) {
    let setup = setup_full_suite();
    let transfer_manager_contract = declare("DVATransferManager").unwrap().contract_class();
    let (transfer_manager_address, _) = transfer_manager_contract.deploy(@array![]).unwrap();
    (setup, IDVATransferManagerDispatcher { contract_address: transfer_manager_address })
}

fn setup_full_suite_with_verified_transfer_manager() -> (
    FullSuiteSetup, IDVATransferManagerDispatcher,
) {
    let (setup, transfer_manager) = setup_full_suite_with_transfer_manager();
    let alice_identity = setup.onchain_id.alice_identity.contract_address;

    start_cheat_caller_address(
        setup.identity_registry.contract_address,
        setup.accounts.token_agent.account.contract_address,
    );
    setup.identity_registry.register_identity(transfer_manager.contract_address, alice_identity, 0);
    stop_cheat_caller_address(setup.identity_registry.contract_address);

    (setup, transfer_manager)
}

fn setup_full_suite_with_transfer(
    sequential_approval: bool,
) -> (FullSuiteSetup, IDVATransferManagerDispatcher, felt252) {
    let (setup, transfer_manager) = setup_full_suite_with_verified_transfer_manager();
    let token_address = setup.token.contract_address;
    let alice = setup.accounts.alice.account.contract_address;
    let bob = setup.accounts.bob.account.contract_address;
    let charlie = setup.accounts.charlie.account.contract_address;

    start_cheat_caller_address(
        transfer_manager.contract_address, setup.accounts.token_agent.account.contract_address,
    );
    transfer_manager
        .set_approval_criteria(
            token_address, true, true, sequential_approval, array![charlie].span(),
        );
    stop_cheat_caller_address(transfer_manager.contract_address);

    start_cheat_caller_address(token_address, alice);
    IERC20Dispatcher { contract_address: token_address }
        .approve(transfer_manager.contract_address, 100000);
    stop_cheat_caller_address(token_address);

    let transfer_id = transfer_manager.calculate_transfer_id(0, alice, bob, 100);

    start_cheat_caller_address(transfer_manager.contract_address, alice);
    transfer_manager.initiate_transfer(token_address, bob, 100);
    stop_cheat_caller_address(transfer_manager.contract_address);

    (setup, transfer_manager, transfer_id)
}

mod name {
    use super::{
        IDVATransferManagerDispatcherTrait, setup_full_suite_with_verified_transfer_manager,
    };

    #[test]
    fn test_should_return_module_name() {
        let (_, transfer_manager) = setup_full_suite_with_verified_transfer_manager();
        assert_eq!(transfer_manager.name(), "DVATransferManager");
    }
}
