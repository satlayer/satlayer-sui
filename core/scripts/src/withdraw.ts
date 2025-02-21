import { Transaction } from '@mysten/sui/transactions';
import * as dotenv from 'dotenv';
import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui/utils";
import getExecStuff from '../utils/execStuff';
import { packageId, Vault, COIN_A_TYPE, COIN_B_TYPE, Version, } from '../utils/packageInfo';
dotenv.config();

async function withdraw() {
    const { keypair, client } = getExecStuff();
    const tx = new Transaction();
    
    let coin = tx.moveCall({
        target: `${packageId}::satlayer_pool::withdraw`,
        arguments: [
            tx.object(Vault), // Vault
            tx.object(SUI_CLOCK_OBJECT_ID),  // clock id 
            tx.object(Version),
        ],
        typeArguments: [
            COIN_A_TYPE,
            COIN_B_TYPE,
        ]
    });

    tx.transferObjects([coin], keypair.getPublicKey().toSuiAddress());

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
withdraw();