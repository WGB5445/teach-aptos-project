// script {
//     use std::signer;
//     use aptos_framework::aptos_account;
//
//     fun main (sender1: &signer, sender2: &signer){
//         aptos_account::transfer(
//             sender1,
//             signer::address_of(sender2),
//             1
//         );
//     }
// }