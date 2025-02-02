use crate::roles::agent_role::IAgentRoleDispatcher;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};

fn setup() -> IAgentRoleDispatcher {
    let agent_role_contract = declare("MockAgentRole").unwrap().contract_class();
    let (deployed_address, _) = agent_role_contract
        .deploy(@array![starknet::get_contract_address().into()])
        .unwrap();
    IAgentRoleDispatcher { contract_address: deployed_address }
}

pub mod add_agent {
    use core::num::traits::Zero;
    use crate::roles::agent_role::{AgentRoleComponent, IAgentRoleDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_reverts_when_sender_is_not_the_owner() {
        let agent_role = setup();
        start_cheat_caller_address(
            agent_role.contract_address, starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        agent_role.add_agent(starknet::contract_address_const::<'AGENT'>());
        stop_cheat_caller_address(agent_role.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Agent address zero!')]
    fn test_should_reverts_when_address_to_add_is_zero_address() {
        let agent_role = setup();

        agent_role.add_agent(Zero::zero());
    }

    #[test]
    fn test_should_add_the_agent() {
        let agent_role = setup();
        let agent = starknet::contract_address_const::<'AGENT'>();

        let mut spy = spy_events();
        agent_role.add_agent(agent);

        assert(agent_role.is_agent(agent), 'Agent not registered');
        spy
            .assert_emitted(
                @array![
                    (
                        agent_role.contract_address,
                        AgentRoleComponent::Event::AgentAdded(
                            AgentRoleComponent::AgentAdded { agent },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic(expected: 'Agent already registered')]
    fn test_should_reverts_when_address_to_add_is_already_an_agent() {
        let agent_role = setup();
        let agent = starknet::contract_address_const::<'AGENT'>();

        agent_role.add_agent(agent);
        /// Registering twice should panic
        agent_role.add_agent(agent);
    }
}

pub mod remove_agent {
    use core::num::traits::Zero;
    use crate::roles::agent_role::{AgentRoleComponent, IAgentRoleDispatcherTrait};
    use snforge_std::{
        EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use super::setup;

    #[test]
    #[should_panic(expected: 'Caller is not the owner')]
    fn test_should_reverts_when_sender_is_not_the_owner() {
        let agent_role = setup();
        start_cheat_caller_address(
            agent_role.contract_address, starknet::contract_address_const::<'NOT_OWNER'>(),
        );
        agent_role.remove_agent(starknet::contract_address_const::<'AGENT'>());
        stop_cheat_caller_address(agent_role.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Agent address zero!')]
    fn test_should_reverts_when_address_to_remove_is_zero_address() {
        let agent_role = setup();

        agent_role.remove_agent(Zero::zero());
    }

    #[test]
    #[should_panic(expected: 'Agent not registered')]
    fn test_should_reverts_when_address_to_remove_is_not_an_agent() {
        let agent_role = setup();

        agent_role.remove_agent(starknet::contract_address_const::<'AGENT'>());
    }

    #[test]
    fn test_should_remove_the_agent_when_address_to_remove_is_an_agent_address() {
        let agent_role = setup();
        let agent = starknet::contract_address_const::<'AGENT'>();
        agent_role.add_agent(agent);

        let mut spy = spy_events();
        agent_role.remove_agent(agent);

        assert(!agent_role.is_agent(agent), 'Agent not removed');
        spy
            .assert_emitted(
                @array![
                    (
                        agent_role.contract_address,
                        AgentRoleComponent::Event::AgentRemoved(
                            AgentRoleComponent::AgentRemoved { agent },
                        ),
                    ),
                ],
            );
    }
}
