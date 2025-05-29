import { Account, AccountAddress, Aptos, AptosConfig, Ed25519PrivateKey, Network, U64 } from "@aptos-labs/ts-sdk"
import { readFileSync } from 'fs';


// build aptos config 

const aptosConfig = new AptosConfig( { network: Network.DEVNET } );

// build aptos client

const aptosClient = new Aptos(aptosConfig);


async function runScript(){
    const script = readFileSync('sampleScript.mv');
    console.log("Script: ", Buffer.from(script).toString('hex'));


    // payload

    const payload = {
        bytecode: Buffer.from(script),
        typeArguments: [],
        functionArguments: [
            AccountAddress.fromString("0xf2e160bc0d31cb0fec7063370113c49341c75c60b64bdb2478ad2e0482e96635"),
            new U64(123)
        ],
    }

    // new Account 
    let account = Account.fromPrivateKey({privateKey: new Ed25519PrivateKey("0x5e90c6b4f884515079c3bd88f046040dd957e69ee7428dfc4ae35980e4806455")})

    console.log("AccountAddress: ", account.accountAddress.toString());

    // build txn 

    const simple_txn = await aptosClient.transaction.build.simple({
        sender: account.accountAddress,
        data: payload,
    });

    console.log("Simple Transaction: ", simple_txn);

    // simulate the transaction

    const simulation = await aptosClient.transaction.simulate.simple({
        transaction: simple_txn,
    });
    console.log("Simulation Result: ", simulation);



    // submit the transaction
    const submitted_txn = await aptosClient.transaction.submit.simple({
        transaction: simple_txn,
        senderAuthenticator: account.signTransactionWithAuthenticator(simple_txn),
    });

    console.log("Submitted Transaction: ", submitted_txn);



}


async function runMultiAgentScript(){
    const script = readFileSync('multiAgentScript.mv');
    console.log("Script: ", Buffer.from(script).toString('hex'));


    // payload

    const payload = {
        bytecode: Buffer.from(script),
        typeArguments: [],
        functionArguments: [],
    }

    // new Account 
    let account1 = Account.fromPrivateKey({privateKey: new Ed25519PrivateKey("0x5e90c6b4f884515079c3bd88f046040dd957e69ee7428dfc4ae35980e4806455")})

    console.log("Account1 Address: ", account1.accountAddress.toString());

    let account2 = Account.fromPrivateKey({privateKey: new Ed25519PrivateKey("0x83e5ce5ebc7281fb717853b35b0b9e3777c86dccd103842ce884631376df335f")})
    console.log("Account2 Address: ", account2.accountAddress.toString());

    // build txn 

    const multi_agent_txn = await aptosClient.transaction.build.multiAgent({
        sender: account1.accountAddress,
        data: payload,
        secondarySignerAddresses: [
            account2.accountAddress
        ]
    });

    console.log("Multi Agent Transaction: ", multi_agent_txn);

    // simulate the transaction

    const simulation = await aptosClient.transaction.simulate.multiAgent({
        transaction: multi_agent_txn,
    });
    console.log("Simulation Result: ", simulation);



    // submit the transaction
    const submitted_txn = await aptosClient.transaction.submit.multiAgent({
        transaction: multi_agent_txn,
        senderAuthenticator: account1.signTransactionWithAuthenticator(multi_agent_txn),
        additionalSignersAuthenticators: [
            account2.signTransactionWithAuthenticator(multi_agent_txn)
        ]
    });

    console.log("Submitted Transaction: ", submitted_txn);
}


await runScript()
await runMultiAgentScript()
