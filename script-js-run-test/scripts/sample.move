script {
    use aptos_framework::aptos_account;

    fun main(sender: &signer, to: address, amount: u64){
        aptos_account::transfer(
            sender,
            to,
            amount
        );
        aptos_account::transfer(
            sender,
            to,
            amount
        );
    }
}