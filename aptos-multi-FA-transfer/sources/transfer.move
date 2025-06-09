module contract::transfer {
    use aptos_framework::fungible_asset::Metadata;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::object;

    entry public fun transfer(sender: &signer, fa_object_address: vector<address>, amounts: vector<u64>, to: address){
        fa_object_address.zip_ref(&amounts,|object, amount|{
            primary_fungible_store::transfer(
                sender,
                object::address_to_object<Metadata>(*object),
                to,
                *amount,
            )
        });
    }
}
