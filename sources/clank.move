module clank::vaults {
    use aptos_std::table::{Table};
    use aptos_framework::account;
    use aptos_framework::aptos_coin::AptosCoin;
    use std::vector;
    use std::signer::address_of;
    use aptos_std::table;
    use aptos_framework::coin;
    use std::aptos_account;
    use aptos_framework::resource_account;

    struct WithdrawlLog has store {
        withdrawal_coin_number: u64,
        timestamp: u64 // can be substituted by block height
    }

    struct Vault has key {
        resource_signer_cap: account::SignerCapability,
        origin_account: address,
        sub_account: address, // use for 2FA
        token_limit_number: u64,
        memoried_authentication_key: vector<u8>,
        waiting_withdrawal_mapping: Table<address, u64>, // <receiver, number of token to send>
        withdrawal_history: vector<WithdrawlLog>,
        withdrawal_change_req: vector<u64> // 2 length array
    }

    // `init_module` is automatically called when publishing the module
    fun init_module(resource_account: &signer) {
        let resource_signer_cap = resource_account::retrieve_resource_account_cap(resource_account, @origin_account);
        let vault = Vault {
            resource_signer_cap,
            origin_account: address_of(resource_account),
            sub_account: address_of(resource_account),
            token_limit_number: 0,
            memoried_authentication_key: vector::empty<u8>(),
            waiting_withdrawal_mapping: table::new<address, u64>(),
            withdrawal_history: vector::empty<WithdrawlLog>(),
            withdrawal_change_req: vector::empty<u64>()
        };
        move_to(resource_account, vault)
    }

    public entry fun deposit(sender: &signer, amount: u64) {
        aptos_account::transfer(sender, @resource_account, amount)
    }

    #[test_only]
    public entry fun set_up_test(origin_account: &signer, resource_account: &signer) {
        use std::vector;

        aptos_account::create_account(address_of(origin_account));
        // create a resource account from the origin account, mocking the module publishing process
        resource_account::create_resource_account(origin_account, vector::empty<u8>(), vector::empty<u8>());
        init_module(resource_account);
    }

    #[test(origin_account = @0xcafe, resource_account = @0xc3bb8488ab1a5815a9d543d7e41b0e0df46a7396f89b22821f07a4362f75ddc5, core = @0x1)]
    public entry fun test_init(origin_account: &signer, resource_account: &signer, core: &signer) {
        set_up_test(origin_account, resource_account);
        let (burn_cap, mint_cap) = aptos_framework::aptos_coin::initialize_for_test(core);
        coin::deposit(address_of(origin_account), coin::mint(1000, &mint_cap));
        assert!(coin::balance<AptosCoin>(address_of(origin_account)) == 1000, 0);
        deposit(origin_account, 500);
        assert!(coin::balance<AptosCoin>(address_of(origin_account)) == 500, 0);
        assert!(coin::balance<AptosCoin>(address_of(resource_account)) == 500, 0);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
}