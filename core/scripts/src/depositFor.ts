import { coinWithBalance, Transaction } from '@mysten/sui/transactions';
import * as dotenv from 'dotenv';
import getExecStuff from '../utils/execStuff';
import { packageId, Vault, COIN_A_TYPE, COIN_B_TYPE, Version } from '../utils/packageInfo';
dotenv.config();

async function depositFor() {
    const { keypair, client } = getExecStuff();
    const tx = new Transaction();

    const depositCoin = coinWithBalance({
      type: COIN_A_TYPE, // Deposit Coin Type
      balance: 5_000_000_000, // you can put amount to deposit
    });

    let return_coin = tx.moveCall({
        target: `${packageId}::satlayer_pool::deposit_for`,
        arguments: [
            tx.object(Vault),
            depositCoin,
            tx.object(Version) 
        ],
        typeArguments: [
            COIN_A_TYPE,
            COIN_B_TYPE,
        ]
    });

    tx.transferObjects([return_coin], keypair.getPublicKey().toSuiAddress())
    const result = await client.signAndExecuteTransaction({
        signer: keypair,
        transaction: tx,
        requestType: "WaitForLocalExecution",
        options: {
            showObjectChanges: true,
            showEffects: true,
        },
    });
    console.log(result.digest);
    
}
depositFor();