module faucet::faucet {
    use std::signer;
    use std::string::utf8;
    use aptos_framework::account::SignerCapability;
    use aptos_framework::aptos_account;
    use aptos_framework::coin;

    struct USDC {}
    struct WETH {}
    struct WBTC {}

    struct Cap has key {
        cap: SignerCapability
    }


    struct CoinStore<phantom T>  has key {
        mint_cap: coin::MintCapability<T>,
        burn_cap: coin::BurnCapability<T>,
        freeze_cap: coin::FreezeCapability<T>
    }


    fun init_module(sender: &signer){
        let (burn, freeze, mint) = coin::initialize<USDC>(
            sender,
            utf8(b"USD Coin"),
            utf8(b"USDC"),
            8,
            true,
        );

        move_to(sender, CoinStore<USDC>{
            mint_cap: mint,
            burn_cap: burn,
            freeze_cap:freeze
        });

        let (burn, freeze, mint) = coin::initialize<WBTC>(
            sender,
            utf8(b"Wrapped Bitcoin"),
            utf8(b"WBTC"),
            8,
            true,
        );

        move_to(sender, CoinStore<WBTC>{
            mint_cap: mint,
            burn_cap: burn,
            freeze_cap:freeze
        });

        let (burn, freeze, mint) = coin::initialize<WETH>(
            sender,
            utf8(b"Wrapped Ethereum"),
            utf8(b"WETH"),
            8,
            true,
        );

        move_to(sender, CoinStore<WETH>{
            mint_cap: mint,
            burn_cap: burn,
            freeze_cap:freeze
        });
    }

    entry fun mint<T>( sender: &signer, amount: u64) acquires CoinStore {
        aptos_account::deposit_coins(signer::address_of(sender),coin::mint(amount, &borrow_global<CoinStore<T>>(@faucet).mint_cap));
    }
}
