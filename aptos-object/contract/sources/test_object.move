module object::test_object {
    use std::signer;
    use std::string::{Self, String};
    use aptos_framework::event;
    use aptos_framework::object::{Self, Object};

    struct Content has key {
        value : string::String
    }

    struct Refs has key {
        delete_ref: object::DeleteRef,
        extend_ref: object::ExtendRef,
    }

    #[event]
    struct CreateEvent has drop,store {
        sender: address,
        object: Object<Content>
    }

    entry fun create (sender: &signer, content: string::String){
        let object_cref = object::create_object(signer::address_of(sender));
        let object_signer = object::generate_signer(&object_cref);

        move_to(
            &object_signer,
            Refs {
                delete_ref: object::generate_delete_ref(&object_cref),
                extend_ref: object::generate_extend_ref(&object_cref),
            }
        );
        move_to(
            &object_signer,
            Content {
                value:content
            }
        );

        event::emit( CreateEvent {
            sender: signer::address_of(sender),
            object: object::object_from_constructor_ref(&object_cref)
        });
    }

    #[event]
    struct SetContentEvent has drop,store {
        sender: address,
        object: Object<Content>,
        old_content: String,
        new_content: String
    }

    entry fun set_content(sender: &signer, object: Object<Content>, new_content: string::String) acquires  Content {
        assert!(object::is_owner(object, signer::address_of(sender)), 1);

        let old_content = borrow_global<Content>(object::object_address(&object)).value;

        borrow_global_mut<Content>(object::object_address(&object)).value = new_content;

        event::emit(
            SetContentEvent {
                sender: signer::address_of(sender),
                object,
                old_content,
                new_content,
            }
        )
    }

    #[view]
    public fun get_content(object: Object<Content>): string::String acquires Content {
        borrow_global<Content>(object::object_address(&object)).value
    }

    #[event]
    struct DeleteEvent has drop,store {
        sender: address,
        object: Object<Content>,
        content: String
    }

    entry fun delete (sender: &signer,object: Object<Content>) acquires Content, Refs {
        assert!(object::is_owner(object, signer::address_of(sender)), 1);
        let Content {
            value
        } = move_from<Content>(object::object_address(&object));

        let Refs {
            delete_ref ,
            extend_ref: _ ,
        } = move_from<Refs>(object::object_address(&object));

        object::delete(
            delete_ref
        );

        event::emit(
            DeleteEvent {
                sender: signer::address_of(sender),
                object,
                content: value
            }
        )
    }

}
