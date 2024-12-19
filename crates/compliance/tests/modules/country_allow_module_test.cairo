#[test]
fn test_should_return_the_name_of_the_module() {
    assert!(true, "");
}


#[test]
fn test_is_plug_and_play_should_return_true() {
    assert!(true, "");
}


#[test]
fn test_can_compliance_bind_should_return_true() {
    assert!(true, "");
}


#[test]
fn test_should_return_owner() {
    assert!(true, "");
}


pub mod transfer_ownership {
    #[test]
    #[should_panic]
    fn test_should_panic_when_caller_not_owner() {
        panic!("");
    }

    #[test]
    fn test_should_transfer_ownership() {
        assert!(true, "");
    }
}

pub mod upgrade {
    #[test]
    #[should_panic]
    fn test_should_panic_when_caller_is_not_owner() {
        panic!("");
    }

    #[test]
    fn test_should_upgrade() {
        assert!(true, "");
    }
}

pub mod batch_allow_countries {
    #[test]
    #[should_panic]
    fn test_should_panic_when_caller_not_compliance_contract() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_panic_when_calling_as_the_owner() {
        panic!("");
    }

    #[test]
    fn test_should_allow_given_countries_when_caller_is_compliance_contract() {
        assert!(true, "");
    }
}

pub mod batch_disallow_countries {
    #[test]
    #[should_panic]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_panic_when_calling_as_the_owner() {
        panic!("");
    }

    #[test]
    fn test_should_disallow_given_countries_when_caller_is_compliance_contract() {
        assert!(true, "");
    }
}

pub mod add_allowed_country {
    #[test]
    #[should_panic]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_panic_when_calling_as_the_owner() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_panic_when_country_already_allowed() {
        panic!("");
    }

    #[test]
    fn test_should_allow_given_country_when_country_not_allowed() {
        assert!(true, "");
    }
}

pub mod remove_allowed_country {
    #[test]
    #[should_panic]
    fn test_should_panic_when_caller_is_not_compliance_contract() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_panic_when_calling_as_the_owner() {
        panic!("");
    }

    #[test]
    #[should_panic]
    fn test_should_panic_when_country_not_allowed() {
        panic!("");
    }

    #[test]
    fn test_should_disallow_given_country_when_country_is_allowed() {
        assert!(true, "");
    }
}

pub mod module_check {
    #[test]
    fn test_should_return_true_when_identity_country_is_allowed() {
        assert!(true, "");
    }

    #[test]
    fn test_should_return_false_when_identity_country_not_allowed() {
        assert!(true, "");
    }
}

pub mod is_compliance_bound {
    #[test]
    fn test_should_return_true_when_address_is_bound_compliance() {
        assert!(true, "");
    }

    #[test]
    fn test_should_return_false_when_address_is_not_bound_compliance() {
        assert!(true, "");
    }
}

pub mod unbind_compliance {
    #[test]
    #[should_panic]
    fn test_should_panic_when_sender_is_not_bound_compliance() {
        panic!("");
    }

    #[test]
    fn test_should_unbind_compliance() {
        assert!(true, "");
    }
}
