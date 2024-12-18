#[test_only]
module main::fa_test {
    use std::bcs;
    use std::option;
    use std::signer;
    use std::string::utf8;
    use aptos_framework::account;
    use aptos_framework::aptos_account;
    use aptos_framework::aptos_coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::fungible_asset;
    use aptos_framework::fungible_asset::Metadata;
    use aptos_framework::object;
    use aptos_framework::primary_fungible_store;
    use pool::fa_pool;

    const Deployer: address = @main;

    #[test]
    fun test() {
        let deployer = &account::create_account_for_test(Deployer);
        let fx= &account::create_account_for_test(@aptos_framework);

        // Get  Aptos Coin
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(fx);

        // Mint Aptos Coin and Transfer
        aptos_account::deposit_coins(signer::address_of(deployer), coin::mint(
            1000 * 10000_0000,
            &mint_cap
        ));

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);

        // Check Aptos Coin balance
        assert!(coin::balance<AptosCoin>(signer::address_of(deployer)) == 1000 * 10000_0000 ,135);

        let metadata_object_a_cref = &object::create_sticky_object(
            signer::address_of(deployer)
        );

        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            metadata_object_a_cref,
            option::none(),
            utf8(b"A"),
            utf8(b"A"),
            8,
            utf8(b""),
            utf8(b"")
        );

        let metadata_a = object::object_from_constructor_ref<Metadata>(metadata_object_a_cref);

        let mint_cap_a = fungible_asset::generate_mint_ref(
            metadata_object_a_cref
        );

        primary_fungible_store::deposit(
            signer::address_of(deployer),
            fungible_asset::mint(
                &mint_cap_a,
                5000 * 100000000
            )
        );


        let metadata_object_b_cref = &object::create_sticky_object(
            signer::address_of(deployer)
        );

        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            metadata_object_b_cref,
            option::none(),
            utf8(b"A"),
            utf8(b"A"),
            8,
            utf8(b""),
            utf8(b"")
        );

        let metadata_b = object::object_from_constructor_ref<Metadata>(metadata_object_b_cref);


        let mint_cap_b = fungible_asset::generate_mint_ref(
            metadata_object_b_cref
        );

        primary_fungible_store::deposit(
            signer::address_of(deployer),
            fungible_asset::mint(
                &mint_cap_b,
                5000 * 100000000
            )
        );

        fa_pool::init_for_test(deployer);

        fa_pool::create_pool(
            deployer,
            metadata_a,
            metadata_b,
            1000 * 100000000,
            2000 * 100000000,
        );

        // order_coin_type()


        // Swap A - > B
        fa_pool::swap(deployer, metadata_a, metadata_b,10 * 100000000, 0);
        assert!( primary_fungible_store::balance(signer::address_of(deployer), metadata_b) == 301980198019, 1);


        // Swap B - > A
        fa_pool::swap(deployer, metadata_b, metadata_a , 1980198019, 0 );
        assert!( primary_fungible_store::balance(signer::address_of(deployer), metadata_a) == 399999999999, 2);
    }


    #[test]
    fun test_add_liq() {
        let deployer = &account::create_account_for_test(Deployer);
        let fx= &account::create_account_for_test(@aptos_framework);

        // Get  Aptos Coin
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(fx);

        // Mint Aptos Coin and Transfer
        aptos_account::deposit_coins(signer::address_of(deployer), coin::mint(
            1000 * 10000_0000,
            &mint_cap
        ));

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);

        // Check Aptos Coin balance
        assert!(coin::balance<AptosCoin>(signer::address_of(deployer)) == 1000 * 10000_0000 ,135);
        let metadata_object_a_cref = &object::create_sticky_object(
            signer::address_of(deployer)
        );

        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            metadata_object_a_cref,
            option::none(),
            utf8(b"A"),
            utf8(b"A"),
            8,
            utf8(b""),
            utf8(b"")
        );

        let metadata_a = object::object_from_constructor_ref<Metadata>(metadata_object_a_cref);

        let mint_cap_a = fungible_asset::generate_mint_ref(
            metadata_object_a_cref
        );

        primary_fungible_store::deposit(
            signer::address_of(deployer),
            fungible_asset::mint(
                &mint_cap_a,
                5000 * 100000000
            )
        );


        let metadata_object_b_cref = &object::create_sticky_object(
            signer::address_of(deployer)
        );

        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            metadata_object_b_cref,
            option::none(),
            utf8(b"A"),
            utf8(b"A"),
            8,
            utf8(b""),
            utf8(b"")
        );

        let metadata_b = object::object_from_constructor_ref<Metadata>(metadata_object_b_cref);


        let mint_cap_b = fungible_asset::generate_mint_ref(
            metadata_object_b_cref
        );

        primary_fungible_store::deposit(
            signer::address_of(deployer),
            fungible_asset::mint(
                &mint_cap_b,
                5000 * 100000000
            )
        );

        fa_pool::init_for_test(deployer);

        fa_pool::create_pool(
            deployer,
            metadata_a,
            metadata_b,
            1000 * 100000000,
            2000 * 100000000,
        );

        let pool_address = if(fa_pool::order_coin_type(
            metadata_a,
            metadata_b
        )) {
            let vec = vector[];
            vec.append(bcs::to_bytes(&metadata_a));
            vec.append(bcs::to_bytes(&metadata_b));

            object::create_object_address(
                &fa_pool::get_resource_address(),
                vec
            )
        }else {
            let vec = vector[];
            vec.append(bcs::to_bytes(&metadata_b));
            vec.append(bcs::to_bytes(&metadata_a));

            object::create_object_address(
                &fa_pool::get_resource_address(),
                vec
            )
        };



        assert!( primary_fungible_store::balance(signer::address_of(deployer), metadata_a) == 400000000000, 1);
        assert!( primary_fungible_store::balance(signer::address_of(deployer), metadata_b) == 300000000000, 2);
        assert!( primary_fungible_store::balance(signer::address_of(deployer), object::address_to_object<Metadata>(pool_address)) == 141421355737, 3);


        // Add Liquidity
        fa_pool::add_liquidity(
            deployer,
            metadata_a,
            metadata_b,
            1000 * 100000000,
            2000 * 100000000,

            1000 * 100000000,
            2000 * 100000000,
        );

        assert!( primary_fungible_store::balance(signer::address_of(deployer), metadata_a) == 300000000000,4);
        assert!( primary_fungible_store::balance(signer::address_of(deployer),metadata_b) == 100000000000, 5);
        assert!( primary_fungible_store::balance(signer::address_of(deployer), object::address_to_object<Metadata>(pool_address)) == 282842711974, 6);
    }
}
