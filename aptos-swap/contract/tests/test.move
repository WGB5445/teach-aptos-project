#[test_only]
module main::test {
    use std::signer;
    use std::string::utf8;
    use aptos_framework::aptos_account;
    use aptos_framework::aptos_coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use pool::pool::Lp;
    use pool::pool;

    struct A {}

    struct B {}

    struct CoinStore<phantom T>  has key {
        mint_cap: coin::MintCapability<T>,
        burn_cap: coin::BurnCapability<T>,
        freeze_cap: coin::FreezeCapability<T>
    }

    public fun init_coin(sender: &signer){
        let (burn, freeze, mint) = coin::initialize<A>(
            sender,
            utf8(b"A"),
            utf8(b"A"),
            8,
            true,
        );

        move_to(sender, CoinStore<A>{
            mint_cap: mint,
            burn_cap: burn,
            freeze_cap:freeze
        });

        let (burn, freeze, mint) = coin::initialize<B>(
            sender,
            utf8(b"B"),
            utf8(b"B"),
            8,
            true,
        );
        move_to(sender, CoinStore<B>{
            mint_cap: mint,
            burn_cap: burn,
            freeze_cap:freeze
        });
    }

    fun mint_to<T>(addr: address, amount: u64) acquires CoinStore {
        aptos_account::deposit_coins(addr,coin::mint(amount, &borrow_global<CoinStore<T>>(@main).mint_cap)) ;
    }



    #[test(deployer = @main, fx = @aptos_framework)]
    fun test(deployer: &signer, fx: &signer) acquires CoinStore {

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

        pool::init_for_test(deployer);
        init_coin(deployer);

        mint_to<A>(signer::address_of(deployer), 5000 * 100000000);
        mint_to<B>(signer::address_of(deployer), 5000 * 100000000);
        pool::create_pool<A,B>(
            deployer,
            1000 * 100000000,
            2000 * 100000000,
        );

        // order_coin_type()


        // Swap A - > B
        pool::swap<A,B>(deployer, 10 * 100000000, 0);
        assert!( coin::balance<B>(signer::address_of(deployer)) == 301980198019, 1);


        // Swap B - > A
        pool::swap<B,A>(deployer,1980198019, 0 );
        assert!( coin::balance<A>(signer::address_of(deployer)) == 399999999999, 2);

    }


    #[test(deployer = @main)]
    fun test_add_liq(deployer: &signer) acquires CoinStore {
        pool::init_for_test(deployer);
        init_coin(deployer);
        mint_to<A>(signer::address_of(deployer), 5000 * 100000000);
        mint_to<B>(signer::address_of(deployer), 5000 * 100000000);

        pool::create_pool<A,B>(
            deployer,
            1000 * 100000000,
            2000 * 100000000,
        );

        assert!( coin::balance<A>(signer::address_of(deployer)) == 400000000000, 1);
        assert!( coin::balance<B>(signer::address_of(deployer)) == 300000000000, 2);
        assert!( coin::balance<Lp<A,B>>(signer::address_of(deployer)) == 141421355737, 3);


        // Add Liquidity
        pool::add_liquidity<A, B>(
            deployer,
            1000 * 100000000,
            2000 * 100000000,

            1000 * 100000000,
            2000 * 100000000,
        );

        assert!( coin::balance<A>(signer::address_of(deployer)) == 300000000000,4);
        assert!( coin::balance<B>(signer::address_of(deployer)) == 100000000000, 5);
        assert!( coin::balance<Lp<A,B>>(signer::address_of(deployer)) == 282842711974, 6);
    }
}
