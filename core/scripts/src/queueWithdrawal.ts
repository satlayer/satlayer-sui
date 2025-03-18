import { coinWithBalance, Transaction } from '@mysten/sui/transactions';
import * as dotenv from 'dotenv';
import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui/utils";
import getExecStuff from '../utils/execStuff';
import { packageId,  Vault, COIN_A_TYPE, COIN_B_TYPE, Version } from '../utils/packageInfo';
dotenv.config();

async function queueWithdrawal() {
    const { keypair, client } = getExecStuff();
    const tx = new Transaction();

    const receiptCoin = coinWithBalance({
      type: COIN_B_TYPE, // Receipt token Type
      balance: 5_000_000_000, // you can put amount to deposit
    });

    
    tx.moveCall({
        target: `${packageId}::satlayer_pool::queue_withdrawal`,
        arguments: [
            tx.object(Vault), // Vault
            receiptCoin, // Receipt Coin
            tx.object(SUI_CLOCK_OBJECT_ID),  // clock id 
            tx.object(Version),
        ],
        typeArguments: [
            COIN_A_TYPE,
            COIN_B_TYPE,
        ]
    });
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
queueWithdrawal();