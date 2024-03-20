module pool::pool {
    use std::option;
    use std::signer;
    use std::string;
    use aptos_std::comparator;
    use aptos_std::math128;

    use aptos_std::type_info;
    use aptos_framework::account;
    use aptos_framework::account::SignerCapability;
    use aptos_framework::coin;
    use aptos_framework::coin::Coin;
    use aptos_framework::resource_account;
    #[test_only]
    use std::bcs;

    const ENoTExistPool: u64 = 1;
    const ECannotCreateSameCoinPool: u64 = 2;
    const ENotEnoughCoin: u64 = 3;
    const EOverflow: u64 = 4;
    const EOutOfMin: u64 = 5;
    const EInsufficientAmount: u64 = 6;
    const EInsufficientLiquidity: u64 = 7;

    struct Lp<phantom CoinType1, phantom CoinType2>{ }

    struct Pool<phantom CoinType1, phantom CoinType2> has key{
        coin1: Coin<CoinType1>,
        coin2: Coin<CoinType2>,

        mint_cap: coin::MintCapability<Lp<CoinType1, CoinType2>>,
        burn_cap: coin::BurnCapability<Lp<CoinType1, CoinType2>>
    }

    struct State has key{
        cap: SignerCapability
    }

    fun init_module(sender: &signer){
        let signer_cap = resource_account::retrieve_resource_account_cap(sender, @main);
        move_to(sender, State{cap:signer_cap});
    }

    public entry fun create_pool<CoinType1, CoinType2>(sender: &signer, coin1: u64, coin2: u64) acquires State {
        assert!(!exist_pool<CoinType1, CoinType2>(), ENoTExistPool);
        assert!(type_info::type_of<CoinType1>() != type_info::type_of<CoinType2>(), ECannotCreateSameCoinPool);
        assert!(coin::balance<CoinType1>(signer::address_of(sender)) >= coin1, ENotEnoughCoin);
        assert!(coin::balance<CoinType2>(signer::address_of(sender)) >= coin2, ENotEnoughCoin);
        if(order_coin_type<CoinType1, CoinType2>()) {
            private_create_pool<CoinType1, CoinType2>(sender, coin1, coin2);
        }else {
            private_create_pool<CoinType2, CoinType1>(sender, coin2, coin1);
        }
    }

    fun private_create_pool<T1, T2>(sender: &signer, coin1: u64, coin2: u64) acquires State {
        let state = borrow_global_mut<State>(get_resouce_account());
        let signer = &account::create_signer_with_capability(&state.cap);

        let name = string::utf8(b"lp<");
        string::append(&mut name, coin::symbol<T1>());
        string::append_utf8(&mut name, b",");
        string::append(&mut name, coin::symbol<T2>());
        string::append_utf8(&mut name, b">");

        let symbol = coin::symbol<T1>();
        string::append_utf8(&mut symbol, b"-");
        string::append(&mut symbol, coin::symbol<T2>());


        let ( burn_cap , freeze_cap , mint_cap)  = coin::initialize<Lp<T1,T2>>(
            signer,
            name,
            symbol,
            8,
            true
        );

        coin::destroy_freeze_cap(freeze_cap);
        let init_amount = math128::sqrt(((coin1 as u128) * (coin2 as u128) ));
        assert!(init_amount <= 18_446_744_073_709_551_615, EOverflow);

        let init_coin =  coin::mint((init_amount as u64) - 500 , &mint_cap);
        let lock_coin = coin::mint(500, &mint_cap);

        coin::register<Lp<T1,T2>>(signer);
        coin::register<Lp<T1,T2>>(sender);

        coin::deposit(get_resouce_account(),lock_coin);
        coin::deposit(signer::address_of(sender),init_coin);

        move_to(signer, Pool<T1, T2>{
            coin1: coin::withdraw<T1>(sender,coin1),
            coin2: coin::withdraw<T2>(sender,coin2),
            mint_cap,
            burn_cap
        });
    }

    fun private_liquidity_pool<T1,T2>(sender: &signer, coin1: u64, coin2: u64, min_amount_coin1: u64, min_amount_coin2: u64) acquires Pool, State {
        let pool = borrow_global_mut<Pool<T1, T2>>(get_resouce_account());

        let coin1_amount = coin::value(&pool.coin1);
        let coin2_amount = coin::value(&pool.coin2);

        let lp_supply = option::destroy_some(coin::supply<Lp<T1, T2>>());
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
        let lp_coin = coin::mint((new_lp_amount as u64) , &pool.mint_cap);

        coin::register<Lp<T1,T2>>(sender);
        coin::deposit(signer::address_of(sender),lp_coin);

        coin::merge(&mut pool.coin1, coin::withdraw<T1>(sender,add_coin1_amount));
        coin::merge(&mut pool.coin2, coin::withdraw<T2>(sender,add_coin2_amount));
    }

    public entry fun remove_liquidity<CoinType1, CoinType2>(sender: &signer, lp: u64) acquires Pool, State {
        assert!(exist_pool<CoinType1, CoinType2>(), ENoTExistPool);
        assert!(type_info::type_of<CoinType1>() != type_info::type_of<CoinType2>(), ECannotCreateSameCoinPool);
        assert!(coin::balance<Lp<CoinType1, CoinType2>>(signer::address_of(sender)) >= lp, ENotEnoughCoin);

        if(order_coin_type<CoinType1, CoinType2>()) {
            private_remove_liquidity<CoinType1, CoinType2>(sender, lp);
        }else {
            private_remove_liquidity<CoinType2, CoinType1>(sender, lp);
        }
    }

    public fun private_remove_liquidity<T1, T2>(sender: &signer, lp: u64) acquires Pool, State {

        let pool = borrow_global_mut<Pool<T1, T2>>(get_resouce_account());

        let lp_supply = option::destroy_some(coin::supply<Lp<T1, T2>>());
        let coin1_amount = coin::value(&pool.coin1);
        let coin2_amount = coin::value(&pool.coin2);

        let coin1_redeem = (coin1_amount as u128) * (lp as u128) / lp_supply;
        let coin2_redeem = (coin2_amount as u128) * (lp as u128)  / lp_supply;

        assert!(coin1_redeem <= 18_446_744_073_709_551_615, EOverflow);
        assert!(coin2_redeem <= 18_446_744_073_709_551_615, EOverflow);

        coin::register<T1>(sender);
        coin::register<T2>(sender);

        coin::deposit(signer::address_of(sender), coin::extract(&mut pool.coin1,(coin1_redeem as u64)));
        coin::deposit(signer::address_of(sender), coin::extract(&mut pool.coin2, (coin2_redeem as u64)));

        let lp_coin = coin::withdraw<Lp<T1, T2>>(sender, lp);
        coin::burn(lp_coin, &pool.burn_cap);
    }

    public  entry fun swap<CoinType1, CoinType2>(sender: &signer, in: u64, out_min: u64) acquires Pool, State {
        assert!(exist_pool<CoinType1, CoinType2>(), ENoTExistPool);
        assert!(type_info::type_of<CoinType1>() != type_info::type_of<CoinType2>(), ECannotCreateSameCoinPool);
        assert!(coin::balance<CoinType1>(signer::address_of(sender)) >= in, ENotEnoughCoin);

        if(order_coin_type<CoinType1, CoinType2>()) {
            private_swap<CoinType1, CoinType2>(sender, in, out_min, true);
        }else {
            private_swap<CoinType2, CoinType1>(sender, in, out_min, false);
        }
    }

    public entry fun add_liquidity<CoinType1, CoinType2>(
        sender: &signer,
        amount_coin1: u64,
        amount_coin2: u64,
        min_amount_coin1: u64,
        min_amount_coin2: u64,
    ) acquires Pool, State {
         assert!(exist_pool<CoinType1, CoinType2>(), ENoTExistPool);
         assert!(type_info::type_of<CoinType1>() != type_info::type_of<CoinType2>(), ECannotCreateSameCoinPool);
         assert!(coin::balance<CoinType1>(signer::address_of(sender)) >= amount_coin1, ENotEnoughCoin);
         assert!(coin::balance<CoinType2>(signer::address_of(sender)) >= amount_coin2, ENotEnoughCoin);

         if(order_coin_type<CoinType1, CoinType2>()) {
             private_liquidity_pool<CoinType1, CoinType2>(sender, amount_coin1, amount_coin2, min_amount_coin1, min_amount_coin2);
         }else {
             private_liquidity_pool<CoinType2, CoinType1>(sender, amount_coin2, amount_coin1, min_amount_coin2, min_amount_coin1);
         }
    }

    public fun private_swap<T1, T2>(sender: &signer, in: u64, out_min: u64, is_coin1: bool) acquires Pool, State {
        let pool = borrow_global_mut<Pool<T1, T2>>(get_resouce_account());

        let coin1_pool_amount = coin::value(&pool.coin1);
        let coin2_pool_amount = coin::value(&pool.coin2);


        let coin2_out_amount = if( is_coin1 ) {
            (in as u128) * (coin2_pool_amount as u128) / ((coin1_pool_amount + in)  as u128)
        }else{
            (in as u128) * (coin1_pool_amount as u128) / ((coin2_pool_amount + in) as u128)
        };

        assert!(coin2_out_amount >= (out_min as u128), EOutOfMin);
        assert!(coin2_out_amount <= 18_446_744_073_709_551_615, EOverflow);


        if(is_coin1) {
            coin::merge(&mut pool.coin1, coin::withdraw(sender, in));
            coin::deposit(signer::address_of(sender), coin::extract(&mut pool.coin2, (coin2_out_amount as u64)));
            coin::register<T2>(sender);
        }else {
            coin::merge(&mut pool.coin2, coin::withdraw(sender, in));
            coin::deposit(signer::address_of(sender), coin::extract(&mut pool.coin1, (coin2_out_amount as u64)));
            coin::register<T1>(sender);
        }
    }

    #[view]
    public fun order_coin_type<T1, T2>(): bool{
        comparator::is_smaller_than( &comparator::compare(
            &type_info::type_of<T1>(),
            &type_info::type_of<T2>()
        ))
    }

    #[view]
    public fun get_resouce_account(): address acquires State {
        account::get_signer_capability_address(&
            borrow_global<State>(@pool).cap)
    }

    #[view]
    public fun exist_pool<T1,T2>(): bool acquires State {
        if(order_coin_type<T1, T2>()) {
            exists<Pool<T1, T2>>(get_resouce_account())
        }else {
            exists<Pool<T2, T1>>(get_resouce_account())
        }
    }

    #[view]
    public fun get_liqidity<CoinType1, CoinType2>(): (u64, u64) acquires Pool, State {
        if(order_coin_type<CoinType1, CoinType2>()) {
          let pool =   borrow_global<Pool<CoinType1, CoinType2>>(get_resouce_account());
            (coin::value(&pool.coin1), coin::value(&pool.coin2))
        }else {
            let pool =   borrow_global<Pool<CoinType2, CoinType1>>(get_resouce_account());
            (coin::value(&pool.coin2), coin::value(&pool.coin1))
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
