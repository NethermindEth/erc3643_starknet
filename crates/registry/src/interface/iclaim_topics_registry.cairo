#[starknet::interface]
pub trait IClaimTopicsRegistry<TContractState> {
    fn add_claim_topic(ref self: TContractState, claim_topic: felt252);
    fn remove_claim_topic(ref self: TContractState, claim_topic: felt252);
    fn get_claim_topics(self: @TContractState) -> Array<felt252>;
}

#[event]
#[derive(Drop, starknet::Event)]
pub enum Event {
    ClaimTopicAddded: ClaimTopicAddded,
    ClaimTopicRemoved: ClaimTopicRemoved
}

#[derive(Drop, starknet::Event)]
pub struct ClaimTopicAddded {
    #[key]
    claim_topic: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct ClaimTopicRemoved {
    #[key]
    claim_topic: felt252,
}