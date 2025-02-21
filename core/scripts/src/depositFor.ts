import { Transaction } from '@mysten/sui/transactions';
import * as dotenv from 'dotenv';
import getExecStuff from '../utils/execStuff';
import { packageId, Vault, COIN_A_TYPE, COIN_B_TYPE, Version } from '../utils/packageInfo';
dotenv.config();

async function depositFor() {
    const { keypair, client } = getExecStuff();
    const tx = new Transaction();

    let return_coin = tx.moveCall({
        target: `${packageId}::satlayer_pool::deposit_for`,
        arguments: [
            tx.object(Vault),
            tx.object('0xf779a6dd878b696f6d66f4dc7465bc784e2ed0e1ee7bedeb38703feb98705058'),
            tx.object(Version) 
        ],
        typeArguments: [
            COIN_A_TYPE,
            COIN_B_TYPE,// need to add another typeName
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