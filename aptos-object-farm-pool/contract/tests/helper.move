#[test_only]
module farm_pool::helper {
    use std::option;
    use std::string::utf8;
    use aptos_framework::account;
    use aptos_framework::fungible_asset;
    use aptos_framework::fungible_asset::Metadata;
    use aptos_framework::object;
    use aptos_framework::object::Object;
    use aptos_framework::primary_fungible_store;

    struct FaRefs has key {
        mint_ref: fungible_asset::MintRef
    }

    public fun create_fa(): Object<Metadata> {
        let obj_cref = object::create_sticky_object(@aptos_framework);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            &obj_cref,
            option::none(),
            utf8(b""),
            utf8(b""),
            8,
            utf8(b""),
            utf8(b""),
        );
        move_to(&account::create_signer_for_test(object::address_from_constructor_ref(&obj_cref)), FaRefs {
            mint_ref: fungible_asset::generate_mint_ref(&obj_cref)
        });
        object::object_from_constructor_ref(&obj_cref)
    }

    public fun mint_fa(metadata: Object<Metadata>, amount: u64): fungible_asset::FungibleAsset acquires FaRefs {
        fungible_asset::mint(
            &borrow_global<FaRefs>(object::object_address(&metadata)).mint_ref,
            amount
        )
    }
}
