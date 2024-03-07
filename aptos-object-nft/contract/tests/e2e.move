#[test_only]
module my_first_nft::e2e {
    use std::features;
    use std::string;

    use my_first_nft::my_first_nft;

    #[test_only]
    fun init_for_test(sender: &signer, fx: &signer) {
        my_first_nft::init_for_test(sender);
        let feature = features::get_concurrent_assets_feature();
        let agg_feature = features::get_aggregator_v2_api_feature();
        let auid_feature = features::get_auids();
        let module_event_feature = features::get_module_event_feature();
        features::change_feature_flags(fx, vector[auid_feature, module_event_feature], vector[feature, agg_feature]);
    }

    #[test(sender = @my_first_nft)]
    fun test_init(sender: &signer) {
        my_first_nft::init_for_test(sender);
    }

    #[test(sender = @my_first_nft, minter = @0x1234, fx = @aptos_framework, )]
    fun test_mint(sender: &signer, minter: &signer, fx: &signer) {
        init_for_test(sender, fx);
        my_first_nft::mint(minter, string::utf8(b"hello world"));
    }
}
