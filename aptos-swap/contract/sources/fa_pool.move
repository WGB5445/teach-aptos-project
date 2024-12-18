module pool::fa_pool {
    use std::bcs;
    use std::option;
    use std::signer;
    use std::string;
    use std::string::utf8;
    use aptos_std::comparator;
    use aptos_std::math128;
    use aptos_framework::account;
    use aptos_framework::account::SignerCapability;
    use aptos_framework::dispatchable_fungible_asset;
    use aptos_framework::fungible_asset;
    use aptos_framework::fungible_asset::{FungibleStore, Metadata};
    use aptos_framework::object;
    use aptos_framework::object::Object;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::resource_account;

    const ENoTExistPool: u64 = 1;
    const ECannotCreateSameCoinPool: u64 = 2;
    const ENotEnoughCoin: u64 = 3;
    const EOverflow: u64 = 4;
    const EOutOfMin: u64 = 5;
    const EInsufficientAmount: u64 = 6;
    const EInsufficientLiquidity: u64 = 7;

    struct Pool has key{
        coin1: Object<FungibleStore>,
        coin2: Object<FungibleStore>,

        mint_cap: fungible_asset::MintRef,
        burn_cap: fungible_asset::BurnRef
    }

    struct State has key{
        cap: SignerCapability
    }

    fun init_module(sender: &signer){
        let signer_cap = resource_account::retrieve_resource_account_cap(sender, @main);
        move_to(sender, State{cap:signer_cap});
    }

    public fun get_resource_address(): address acquires State {
        account::get_signer_capability_address(&State[@pool].cap)
    }

    public entry fun create_pool(sender: &signer, metadata_coin_1: Object<Metadata>, metadata_coin_2: Object<Metadata>, coin1: u64, coin2: u64) acquires State {
        assert!(!exist_pool(
            metadata_coin_1,
            metadata_coin_2
        ), ENoTExistPool);
        assert!(metadata_coin_1 != metadata_coin_2, ECannotCreateSameCoinPool);
        assert!(primary_fungible_store::balance(signer::address_of(sender), metadata_coin_1) >= coin1, ENotEnoughCoin);
        assert!(primary_fungible_store::balance(signer::address_of(sender), metadata_coin_2) >= coin2, ENotEnoughCoin);
        if(order_coin_type(
            metadata_coin_1,
            metadata_coin_2
        )) {
            private_create_pool(sender, metadata_coin_1, metadata_coin_2 ,coin1, coin2);
        }else {
            private_create_pool(sender, metadata_coin_2, metadata_coin_1, coin2, coin1);
        }
    }

    fun private_create_pool(sender: &signer, metadata_coin_1: Object<Metadata>, metadata_coin_2: Object<Metadata>, coin1: u64, coin2: u64) acquires State {
        let state = borrow_global_mut<State>(get_resouce_account());
        let signer = &account::create_signer_with_capability(&state.cap);

        let name = string::utf8(b"lp<");
        name.append(fungible_asset::symbol(metadata_coin_1));
        name.append_utf8(b",");
        name.append(fungible_asset::symbol(metadata_coin_2));
        name.append_utf8(b">");

        let symbol = fungible_asset::symbol(metadata_coin_1);
        symbol.append_utf8(b"-");
        symbol.append(fungible_asset::symbol(metadata_coin_2));

        let vec = vector[];
        vec.append(bcs::to_bytes(&metadata_coin_1));
        vec.append(bcs::to_bytes(&metadata_coin_2));

        let metadata_object_cref = &object::create_named_object(
            signer,
            vec
        );

        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            metadata_object_cref,
            option::none(),
            name,
            symbol,
            8,
            utf8(b""),
            utf8(b"")
        );

        let mint_cap = fungible_asset::generate_mint_ref(
            metadata_object_cref
        );

        let burn_cap = fungible_asset::generate_burn_ref(
            metadata_object_cref
        );

        let init_amount = math128::sqrt(((coin1 as u128) * (coin2 as u128) ));
        assert!(init_amount <= 18_446_744_073_709_551_615, EOverflow);

        let init_coin =  fungible_asset::mint( &mint_cap ,(init_amount as u64) - 500 );
        let lock_coin = fungible_asset::mint( &mint_cap ,500 );

        primary_fungible_store::deposit(get_resouce_account(),lock_coin);
        primary_fungible_store::deposit(signer::address_of(sender),init_coin);

        let coin1_object_store_cref = &object::create_object(get_resource_address());
        fungible_asset::create_store(
            coin1_object_store_cref,
            metadata_coin_1
        );
        dispatchable_fungible_asset::deposit<FungibleStore>( object::object_from_constructor_ref(coin1_object_store_cref) ,primary_fungible_store::withdraw(
            sender,
            metadata_coin_1,
            coin1
        ));

        let coin2_object_store_cref = &object::create_object(get_resource_address());
        fungible_asset::create_store(
            coin2_object_store_cref,
            metadata_coin_2
        );

        dispatchable_fungible_asset::deposit<FungibleStore>( object::object_from_constructor_ref(coin2_object_store_cref) ,primary_fungible_store::withdraw(
            sender,
            metadata_coin_2,
            coin2
        ));


        move_to( &object::generate_signer(metadata_object_cref) , Pool{
            coin1: object::object_from_constructor_ref(coin1_object_store_cref),
            coin2: object::object_from_constructor_ref(coin2_object_store_cref),
            mint_cap,
            burn_cap
        });
    }

    fun private_liquidity_pool(sender: &signer, metadata_coin_1: Object<Metadata>, metadata_coin_2: Object<Metadata>, coin1: u64, coin2: u64, min_amount_coin1: u64, min_amount_coin2: u64) acquires Pool, State {

        let vec = vector[];
        vec.append(bcs::to_bytes(&metadata_coin_1));
        vec.append(bcs::to_bytes(&metadata_coin_2));

        let pool_address = object::create_object_address(
            &get_resource_address(),
            vec
        );

        let pool = &mut Pool[pool_address];

        let coin1_amount =  fungible_asset::balance(pool.coin1);
        let coin2_amount = fungible_asset::balance(pool.coin2);

        let lp_supply =  fungible_asset::supply(object::address_to_object<Metadata>(pool_address)).destroy_some();
        let (add_coin1_amount, add_coin2_amount) = if (coin1_amount == 0 && coin2_amount == 0) {
            (coin1, coin2)
        } else {
            let coin2_optimal = quote(coin1, coin1_amount, coin2_amount);
            if (coin2_optimal >= min_amount_coin2) {
                (coin1, coin2_optimal)
            } else {
                let coin1_optimal = quote(coin2, coin2_amount, coin1_amount);
                assert!(coin1_optimal >= min_amount_coin1, EInsufficientAmount);
                (coin1_optimal, coin2)
            }
        };

        let new_lp_amount = math128::min(
            (add_coin1_amount as u128) * lp_supply / (coin1_amount as u128),
            (add_coin2_amount as u128) * lp_supply / (coin2_amount as u128)
        );
        assert!(new_lp_amount <= 18_446_744_073_709_551_615, EOverflow);

        let lp_coin = fungible_asset::mint(&pool.mint_cap,(new_lp_amount as u64) );

        primary_fungible_store::deposit(signer::address_of(sender),lp_coin);

        fungible_asset::deposit( pool.coin1, primary_fungible_store::withdraw(sender, metadata_coin_1,add_coin1_amount));
        fungible_asset::deposit(pool.coin2, primary_fungible_store::withdraw(sender,metadata_coin_2,add_coin2_amount));
    }

    public entry fun remove_liquidity(sender: &signer,metadata_coin_1: Object<Metadata>, metadata_coin_2: Object<Metadata>, lp: u64) acquires Pool, State {
        assert!(!exist_pool(
            metadata_coin_1,
            metadata_coin_2
        ), ENoTExistPool);
        assert!(metadata_coin_1 != metadata_coin_2, ECannotCreateSameCoinPool);
        let vec = vector[];
        vec.append(bcs::to_bytes(&metadata_coin_1));
        vec.append(bcs::to_bytes(&metadata_coin_2));
        let pool_address = object::create_object_address(
            &get_resource_address(),
            vec
        );
        assert!(primary_fungible_store::balance(signer::address_of(sender), object::address_to_object<Metadata>(pool_address)) >= lp, ENotEnoughCoin);

        if(order_coin_type(
            metadata_coin_1,
            metadata_coin_2
        )) {
            private_remove_liquidity(sender,metadata_coin_1,metadata_coin_2, lp);
        }else {
            private_remove_liquidity(sender, metadata_coin_2,metadata_coin_1 ,lp);
        }
    }

    public fun private_remove_liquidity(sender: &signer,metadata_coin_1: Object<Metadata>, metadata_coin_2: Object<Metadata>, lp: u64) acquires Pool, State {
        let state = borrow_global_mut<State>(get_resouce_account());
        let signer = &account::create_signer_with_capability(&state.cap);

        let vec = vector[];
        vec.append(bcs::to_bytes(&metadata_coin_1));
        vec.append(bcs::to_bytes(&metadata_coin_2));

        let pool_address = object::create_object_address(
            &get_resource_address(),
            vec
        );

        let pool = &mut Pool[pool_address];

        let coin1_amount =  fungible_asset::balance(pool.coin1);
        let coin2_amount = fungible_asset::balance(pool.coin2);

        let lp_supply =  fungible_asset::supply(object::address_to_object<Metadata>(pool_address)).destroy_some();


        let coin1_redeem = (coin1_amount as u128) * (lp as u128) / lp_supply;
        let coin2_redeem = (coin2_amount as u128) * (lp as u128)  / lp_supply;

        assert!(coin1_redeem <= 18_446_744_073_709_551_615, EOverflow);
        assert!(coin2_redeem <= 18_446_744_073_709_551_615, EOverflow);


        primary_fungible_store::deposit(signer::address_of(sender), fungible_asset::withdraw(
            signer,
            pool.coin1,
            (coin1_redeem as u64)
        ));
        primary_fungible_store::deposit(signer::address_of(sender), fungible_asset::withdraw(
            signer,
            pool.coin1,
            (coin1_redeem as u64)
        ));

        let lp_coin = primary_fungible_store::withdraw(sender, object::address_to_object<Metadata>(pool_address),lp);
        fungible_asset::burn(&pool.burn_cap, lp_coin);
    }

    public  entry fun swap(sender: &signer, metadata_coin_1: Object<Metadata>, metadata_coin_2: Object<Metadata>,in: u64, out_min: u64) acquires Pool, State {
        assert!(exist_pool(
            metadata_coin_1,
            metadata_coin_2
        ), ENoTExistPool);
        assert!(metadata_coin_1 != metadata_coin_2, ECannotCreateSameCoinPool);
        assert!(primary_fungible_store::balance(signer::address_of(sender), metadata_coin_1) >= in, ENotEnoughCoin);

        if(order_coin_type(
            metadata_coin_1,
            metadata_coin_2
        )) {
            private_swap(sender, metadata_coin_1, metadata_coin_2, in, out_min,  true);
        }else {
            private_swap(sender, metadata_coin_2,metadata_coin_1, in, out_min, false);
        }
    }

    public entry fun add_liquidity(
        sender: &signer,
        metadata_coin_1: Object<Metadata>,
        metadata_coin_2: Object<Metadata>,
        amount_coin1: u64,
        amount_coin2: u64,
        min_amount_coin1: u64,
        min_amount_coin2: u64,
    ) acquires Pool, State {
        assert!(exist_pool(
            metadata_coin_1,
            metadata_coin_2
        ), ENoTExistPool);
        assert!(metadata_coin_1 != metadata_coin_2, ECannotCreateSameCoinPool);
        assert!(primary_fungible_store::balance(signer::address_of(sender), metadata_coin_1) >= amount_coin1, ENotEnoughCoin);
        assert!(primary_fungible_store::balance(signer::address_of(sender), metadata_coin_2) >= amount_coin2, ENotEnoughCoin);


        if(order_coin_type(
            metadata_coin_1,
            metadata_coin_2
        )) {
            private_liquidity_pool(sender,metadata_coin_1, metadata_coin_2 ,amount_coin1, amount_coin2, min_amount_coin1, min_amount_coin2);
        }else {
            private_liquidity_pool(sender,metadata_coin_2, metadata_coin_1 ,amount_coin2, amount_coin1, min_amount_coin2, min_amount_coin1);
        }
    }

    public fun private_swap(sender: &signer,metadata_coin_1: Object<Metadata>, metadata_coin_2: Object<Metadata>, in: u64, out_min: u64, is_coin1: bool) acquires Pool, State {
        let state = borrow_global_mut<State>(get_resouce_account());
        let signer = &account::create_signer_with_capability(&state.cap);

        let vec = vector[];
        vec.append(bcs::to_bytes(&metadata_coin_1));
        vec.append(bcs::to_bytes(&metadata_coin_2));

        let pool_address = object::create_object_address(
            &get_resource_address(),
            vec
        );

        let pool = &mut Pool[pool_address];

        let coin1_pool_amount =  fungible_asset::balance(pool.coin1);
        let coin2_pool_amount = fungible_asset::balance(pool.coin2);


        let coin2_out_amount = if( is_coin1 ) {
            (in as u128) * (coin2_pool_amount as u128) / ((coin1_pool_amount + in)  as u128)
        }else{
            (in as u128) * (coin1_pool_amount as u128) / ((coin2_pool_amount + in) as u128)
        };

        assert!(coin2_out_amount >= (out_min as u128), EOutOfMin);
        assert!(coin2_out_amount <= 18_446_744_073_709_551_615, EOverflow);


        if(is_coin1) {
            fungible_asset::deposit(pool.coin1, primary_fungible_store::withdraw(sender,metadata_coin_1 ,in));
            primary_fungible_store::deposit(signer::address_of(sender), fungible_asset::withdraw(signer,pool.coin2, (coin2_out_amount as u64)));
        }else {
            fungible_asset::deposit (pool.coin2, primary_fungible_store::withdraw(sender, metadata_coin_2 ,in));
            primary_fungible_store::deposit(signer::address_of(sender),fungible_asset::withdraw(signer,pool.coin1, (coin2_out_amount as u64)));
        }
    }

    #[view]
    public fun order_coin_type(
        metadata_coin_1: Object<Metadata>,
        metadata_coin_2: Object<Metadata>
    ): bool{
        comparator::compare(
            &metadata_coin_1,
            &metadata_coin_2
        ).is_smaller_than()
    }

    #[view]
    public fun get_resouce_account(): address acquires State {
        account::get_signer_capability_address(&
            borrow_global<State>(@pool).cap)
    }

    #[view]
    public fun exist_pool(
        metadata_coin_1: Object<Metadata>,
        metadata_coin_2: Object<Metadata>
    ): bool acquires State {
        if(order_coin_type(
            metadata_coin_1,
            metadata_coin_2
        )) {
            let vec = vector[];
            vec.append(bcs::to_bytes(&metadata_coin_1));
            vec.append(bcs::to_bytes(&metadata_coin_2));
            let pool_address = object::create_object_address(
                &get_resource_address(),
                vec
            );
            object::is_object(pool_address) && object::object_exists<Pool>(pool_address)
        }else {
            let vec = vector[];
            vec.append(bcs::to_bytes(&metadata_coin_2));
            vec.append(bcs::to_bytes(&metadata_coin_1));
            let pool_address = object::create_object_address(
                &get_resource_address(),
                vec
            );
            object::is_object(pool_address) && object::object_exists<Pool>(pool_address)
        }
    }

    #[view]
    public fun get_liqidity(
        metadata_coin_1: Object<Metadata>,
        metadata_coin_2: Object<Metadata>,
    ): (u64, u64) acquires Pool, State {
        if(order_coin_type(
            metadata_coin_1,
            metadata_coin_2
        )) {
            let vec = vector[];
            vec.append(bcs::to_bytes(&metadata_coin_1));
            vec.append(bcs::to_bytes(&metadata_coin_2));

            let pool_address = object::create_object_address(
                &get_resource_address(),
                vec
            );
            let pool = &mut Pool[pool_address];
            (fungible_asset::balance(pool.coin1), fungible_asset::balance(pool.coin2))
        }else {
            let vec = vector[];
            vec.append(bcs::to_bytes(&metadata_coin_2));
            vec.append(bcs::to_bytes(&metadata_coin_1));

            let pool_address = object::create_object_address(
                &get_resource_address(),
                vec
            );

            let pool = &mut Pool[pool_address];
            (fungible_asset::balance(pool.coin2), fungible_asset::balance(pool.coin1))
        }
    }

    #[view]
    public fun quote(coin1: u64, coin1_amount: u64, coin2_amount: u64): u64 {
        assert!(coin1 > 0, EInsufficientAmount);
        assert!(coin1_amount > 0 && coin2_amount > 0, EInsufficientLiquidity);
        (((coin1 as u128) * (coin2_amount as u128) / (coin1_amount as u128)) as u64)
    }

    #[test_only]
    public fun init_for_test (sender: &signer){
        let (signer, cap) = account::create_resource_account(sender, bcs::to_bytes(&string::utf8(b"dex")));
        move_to(&signer, State{cap});
    }
}
