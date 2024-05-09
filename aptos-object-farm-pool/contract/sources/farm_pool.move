module farm_pool::farm_pool {
    use std::option::{Self, none, Option};
    use std::signer;
    use std::string::utf8;
    use aptos_std::math64;
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::fungible_asset::{Self, FungibleAsset, Metadata};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::timestamp::{Self, now_seconds};

    use aptos_token_objects::collection;
    use aptos_token_objects::token;

    const ErrMetadataType: u64 = 10;
    const ErrOwner: u64 = 11;

    struct FarmPool has key {
        stake_token_metadata: Object<Metadata>,
        reward_token_metadate: Object<Metadata>,
        reward_token_per_sec: u64,
        reward_per_token: u64,
        total_stake_amount: u64,
        last_update_time: u64,
        operator: address
    }

    struct FarmPoolRefs has key {
        extend_ref: object::ExtendRef
    }

    struct UserFarmInfo has key {
        farm_pool: Object<FarmPool>,
        index: u64,
        stake_amount: u64,
        deb: u64,
        unclaimed_reward: u64
    }

    struct UserFarmInfoRefs has key {
        extend_ref: object::ExtendRef,
        mutator_ref: token::MutatorRef,
        burn_ref: token::BurnRef,
        transfer_ref: object::TransferRef
    }

    struct ResourceAccountCap has key {
        cap: SignerCapability
    }

    const SEED: vector<u8> = b"farm pool";

    struct UserFarmInfoCollectionRef has key {
        mutator_ref: collection::MutatorRef
    }

    fun init_module(deployer: &signer) {
        let (signer, cap) = account::create_resource_account(
            deployer,
            SEED
        );
        move_to(
            &signer,
            ResourceAccountCap {
                cap
            }
        );
        let collection_cref = collection::create_unlimited_collection(
            &signer,
            utf8(b""),
            utf8(b"Staking Voucher"),
            none(),
            utf8(b"")
        );


        move_to(
            &signer,
            UserFarmInfoCollectionRef {
                mutator_ref: collection::generate_mutator_ref(&collection_cref)
            }
        );
    }

    inline fun get_address(): address {
        account::create_resource_address(
            &@farm_pool,
            SEED
        )
    }

    inline fun get_signer(): &signer {
        &account::create_signer_with_capability(&borrow_global<ResourceAccountCap>(get_address()).cap)
    }

    public fun create(
        signer: &signer,
        stake_token_metadata: Object<Metadata>,
        reward_token_metadate: Object<Metadata>,
        fa: FungibleAsset,
        reward_token_per_sec: u64
    ): Object<FarmPool> {
        assert!(fungible_asset::metadata_from_asset(&fa) == reward_token_metadate, ErrMetadataType);
        let object_cref = object::create_object(get_address());
        move_to(
            &object::generate_signer(&object_cref),
            FarmPoolRefs {
                extend_ref: object::generate_extend_ref(&object_cref)
            }
        );

        move_to(
            &object::generate_signer(&object_cref),
            FarmPool {
                stake_token_metadata,
                reward_token_metadate,
                reward_token_per_sec,
                reward_per_token: 0,
                total_stake_amount: 0,
                last_update_time: now_seconds(),
                operator: signer::address_of(signer)
            }
        );

        primary_fungible_store::deposit(
            object::address_from_constructor_ref(&object_cref),
            fa
        );

        object::object_from_constructor_ref(&object_cref)
    }

    fun create_user_farm_info(farm_pool: Object<FarmPool>): Object<UserFarmInfo> acquires ResourceAccountCap {
        let object_cref = token::create_numbered_token(
            get_signer(),
            utf8(b"Staking Voucher"),
            utf8(b""),
            utf8(b"Staking Voucher #"),
            utf8(b""),
            none(),
            utf8(b""),
        );

        move_to(
            &object::generate_signer(&object_cref),
            UserFarmInfo {
                farm_pool,
                index: 0,
                stake_amount: 0,
                deb: 0,
                unclaimed_reward: 0
            }
        );

        move_to(
            &object::generate_signer(&object_cref),
            UserFarmInfoRefs {
                extend_ref: object::generate_extend_ref(&object_cref),
                burn_ref: token::generate_burn_ref(&object_cref),
                mutator_ref: token::generate_mutator_ref(&object_cref),
                transfer_ref: object::generate_transfer_ref(&object_cref),
            }
        );

        object::object_from_constructor_ref(&object_cref)
    }

    fun update_pool_index(farm_pool_object: Object<FarmPool>) acquires FarmPool {
        let farm_pool = borrow_global_mut<FarmPool>(object::object_address(&farm_pool_object));
        let now = timestamp::now_seconds();
        let time = (now - farm_pool.last_update_time);
        if (time == 0) {
            return
        };
        let rewards = time * farm_pool.reward_token_per_sec;
        farm_pool.reward_per_token = farm_pool.reward_per_token + rewards / math64::max(
            farm_pool.total_stake_amount,
            0
        );
        update_farm_pool_last_time(farm_pool);
    }

    fun decrease_amount(user_farm_info_object: Object<UserFarmInfo>, amount: u64): u64 acquires UserFarmInfo, FarmPool {
        let user_farm_info = borrow_global_mut<UserFarmInfo>(object::object_address(&user_farm_info_object));
        update_pool_index(user_farm_info.farm_pool);
        let farm_pool = borrow_global_mut<FarmPool>(object::object_address(&user_farm_info.farm_pool));
        decrease_farm_pool_stake_amount(farm_pool, amount);
        let claimable_rewards = farm_pool.reward_per_token * user_farm_info.stake_amount;

        user_farm_info.unclaimed_reward = user_farm_info.unclaimed_reward + claimable_rewards - user_farm_info.deb;

        user_farm_info.stake_amount = user_farm_info.stake_amount - amount;

        user_farm_info.deb = farm_pool.reward_per_token * user_farm_info.stake_amount;

        user_farm_info.stake_amount
    }

    fun increase_amount(user_farm_info_object: Object<UserFarmInfo>, amount: u64): u64 acquires UserFarmInfo, FarmPool {
        let user_farm_info = borrow_global_mut<UserFarmInfo>(object::object_address(&user_farm_info_object)) ;
        update_pool_index(user_farm_info.farm_pool);

        let farm_pool = borrow_global_mut<FarmPool>(object::object_address(&user_farm_info.farm_pool));
        increase_farm_pool_stake_amount(farm_pool, amount);

        let claimable_rewards = farm_pool.reward_per_token * user_farm_info.stake_amount;

        user_farm_info.unclaimed_reward = user_farm_info.unclaimed_reward + claimable_rewards - user_farm_info.deb;

        user_farm_info.stake_amount = user_farm_info.stake_amount + amount;

        user_farm_info.deb = farm_pool.reward_per_token * user_farm_info.stake_amount;

        user_farm_info.stake_amount
    }

    fun update_farm_pool_last_time(farm_pool: &mut FarmPool) {
        farm_pool.last_update_time = timestamp::now_seconds()
    }

    fun increase_farm_pool_stake_amount(farm_pool: &mut FarmPool, amount: u64) {
        farm_pool.total_stake_amount = farm_pool.total_stake_amount + amount;
    }

    fun decrease_farm_pool_stake_amount(farm_pool: &mut FarmPool, amount: u64) {
        farm_pool.total_stake_amount = farm_pool.total_stake_amount - amount;
    }

    #[view]
    public fun claimable_rewards(object: Object<UserFarmInfo>): u64 acquires FarmPool, UserFarmInfo {
        let object_address = object::object_address(&object);
        let user_farm_info = borrow_global<UserFarmInfo>(object_address);
        let new_index = get_new_reward_per_token(user_farm_info.farm_pool);
        new_index * user_farm_info.stake_amount + user_farm_info.unclaimed_reward - user_farm_info.deb
    }

    public fun get_new_reward_per_token(farm_pool_object: Object<FarmPool>): u64 acquires FarmPool {
        let farm_pool = borrow_global<FarmPool>(object::object_address(&farm_pool_object));
        let time = (timestamp::now_seconds() - farm_pool.last_update_time);
        let rewards = time * farm_pool.reward_token_per_sec;
        if (farm_pool.total_stake_amount == 0) {
            farm_pool.reward_per_token
        }else {
            farm_pool.reward_per_token + rewards / farm_pool.total_stake_amount
        }
    }

    inline fun assert_owner(object: Object<UserFarmInfo>, owner: address): &mut UserFarmInfo {
        assert!(object::is_owner(object, owner), ErrOwner);
        borrow_global_mut(object::object_address(&object))
    }

    public fun claim_rewards(
        sender: &signer,
        user_farm_info_object: Object<UserFarmInfo>
    ): FungibleAsset acquires FarmPool, UserFarmInfo, FarmPoolRefs, UserFarmInfoRefs {
        update_pool_index(get_user_farm_info_farm_pool(user_farm_info_object));
        let claimable_rewards = claimable_rewards(user_farm_info_object);
        let user_farm_info = assert_owner(user_farm_info_object, signer::address_of(sender));
        user_farm_info.deb = get_new_reward_per_token(user_farm_info.farm_pool) * user_farm_info.stake_amount;
        user_farm_info.unclaimed_reward = 0;
        let metadata = get_rewards_metadata_object(get_user_farm_info_farm_pool(user_farm_info_object));
        let fa = primary_fungible_store::withdraw(
            get_farm_pool_signer(user_farm_info_object),
            metadata,
            claimable_rewards
        );

        if (get_user_farm_info_stake_amount(user_farm_info_object) == 0) {
            let UserFarmInfo {
                farm_pool: _,
                index: _,
                stake_amount: _,
                deb: _,
                unclaimed_reward: _
            } = move_from<UserFarmInfo>(object::object_address(&user_farm_info_object));

            let UserFarmInfoRefs {
                extend_ref: _,
                mutator_ref: _,
                burn_ref,
                transfer_ref: _
            } = move_from<UserFarmInfoRefs>(object::object_address(&user_farm_info_object));

            token::burn(burn_ref);
        };
        fa
    }

    public fun stake(
        sender_address: address,
        op_user_farm_info_object: Option<Object<UserFarmInfo>>,
        farm_pool_object: Object<FarmPool>,
        fa: FungibleAsset
    ): Object<UserFarmInfo> acquires FarmPool, ResourceAccountCap, UserFarmInfo {
        let farm_pool = borrow_global_mut<FarmPool>(object::object_address(&farm_pool_object));
        assert!(fungible_asset::metadata_from_asset(&fa) == farm_pool.stake_token_metadata, ErrMetadataType);

        let user_farm_info_object = if (option::is_none(&op_user_farm_info_object)) {
            let object = create_user_farm_info(
                farm_pool_object
            );
            object::transfer(
                get_signer(),
                object,
                sender_address
            );
            object
        }else {
            option::destroy_some(op_user_farm_info_object)
        };

        assert!(
            farm_pool_object == borrow_global<UserFarmInfo>(object::object_address(&user_farm_info_object)).farm_pool,
            ErrMetadataType
        );
        increase_amount(
            user_farm_info_object,
            fungible_asset::amount(&fa)
        );

        primary_fungible_store::deposit(
            object::object_address(&user_farm_info_object),
            fa
        );
        user_farm_info_object
    }

    public fun unstake(
        sender: &signer,
        user_farm_info_object: Object<UserFarmInfo>,
        amount: u64
    ): FungibleAsset acquires FarmPool, UserFarmInfo, UserFarmInfoRefs {
        assert_owner(user_farm_info_object, signer::address_of(sender));
        decrease_amount(
            user_farm_info_object,
            amount
        );
        let metadata = get_stake_metadata_object(get_user_farm_info_farm_pool(user_farm_info_object));
        primary_fungible_store::withdraw(
            &object::generate_signer_for_extending(
                &borrow_global<UserFarmInfoRefs>(object::object_address(&user_farm_info_object)).extend_ref
            ),
            metadata,
            amount
        )
    }

    public fun set_reward_token_per_sec(
        sender: &signer,
        farm_pool_object: Object<FarmPool>,
        reward_token_per_sec: u64
    ) acquires FarmPool {
        assert!(
            borrow_global<FarmPool>(object::object_address(&farm_pool_object)).operator == signer::address_of(sender),
            0
        );
        update_pool_index(farm_pool_object);
        let farm_pool = borrow_global_mut<FarmPool>(object::object_address(&farm_pool_object));
        farm_pool.reward_token_per_sec = reward_token_per_sec
    }

    public fun add_reward(
        farm_pool_object: Object<FarmPool>,
        fa: FungibleAsset
    ) acquires FarmPool {
        update_pool_index(farm_pool_object);
        assert!(fungible_asset::metadata_from_asset(&fa) == get_rewards_metadata_object(farm_pool_object), 1);
        primary_fungible_store::deposit(
            object::object_address(&farm_pool_object),
            fa
        )
    }

    public fun get_rewards_metadata_object(farm_pool_object: Object<FarmPool>): Object<Metadata> acquires FarmPool {
        borrow_global<FarmPool>(
            object::object_address(&farm_pool_object)
        ).reward_token_metadate
    }

    public fun get_stake_metadata_object(farm_pool_object: Object<FarmPool>): Object<Metadata> acquires FarmPool {
        borrow_global<FarmPool>(
            object::object_address(&farm_pool_object)
        ).stake_token_metadata
    }

    public fun get_user_farm_info_farm_pool(
        user_farm_info_object: Object<UserFarmInfo>
    ): Object<FarmPool> acquires UserFarmInfo {
        borrow_global<UserFarmInfo>(object::object_address(&user_farm_info_object)).farm_pool
    }

    inline fun get_farm_pool_signer(user_farm_info_object: Object<UserFarmInfo>): &signer acquires UserFarmInfo {
        &object::generate_signer_for_extending(
            &borrow_global<FarmPoolRefs>(
                object::object_address(
                    &borrow_global<UserFarmInfo>(object::object_address(&user_farm_info_object)).farm_pool
                )
            ).extend_ref
        )
    }

    public fun get_user_farm_info_stake_amount(user_farm_info_object: Object<UserFarmInfo>): u64 acquires UserFarmInfo {
        borrow_global<UserFarmInfo>(object::object_address(&user_farm_info_object)).stake_amount
    }

    #[test_only]
    public fun init_for_test(sender: &signer) {
        init_module(sender)
    }
}
