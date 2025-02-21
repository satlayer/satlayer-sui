import { Transaction } from '@mysten/sui/transactions';
import * as dotenv from 'dotenv';
import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui/utils";
import getExecStuff from '../utils/execStuff';
import { packageId,  Vault, COIN_A_TYPE, COIN_B_TYPE, Version } from '../utils/packageInfo';
dotenv.config();

async function queueWithdrawal() {
    const { keypair, client } = getExecStuff();
    const tx = new Transaction();
    
    tx.moveCall({
        target: `${packageId}::satlayer_pool::queue_withdrawal`,
        arguments: [
            tx.object(Vault), // Vault
            tx.object('0x9e4ca52646cbcc5c704b07c835a3bcf0047a2afdabb0c8dfe9347b145eee0d72'), // Receipt Token 
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