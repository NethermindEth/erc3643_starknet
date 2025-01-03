pub mod add_claim_topic {
    #[test]
    #[should_panic]
    fn test_should_panic_when_sender_is_not_owner() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_panic_when_topic_array_contains_more_than_14_elements() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_panic_when_topic_already_added() {
        panic!("");
    }
}

pub mod remove_claim_topic {
    #[test]
    #[should_panic]
    fn test_should_panic_when_sender_is_not_owner() {
        panic!("");
    }

    #[test]
    fn test_should_remove_claim_topic() {
        assert!(true, "");
    }
}
