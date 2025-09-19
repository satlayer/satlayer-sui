import { Transaction } from '@mysten/sui/transactions';
import * as dotenv from 'dotenv';
import getExecStuff from '../../utils/execStuff';
import { AdminCap, COIN_A_TYPE, COIN_B_TYPE, packageId, Vault, Version } from '../../utils/packageInfo';
import getTxHex from '../../utils/getTxHex';
dotenv.config();

async function toggleVaultPause({pause, useMultiSig}: {pause: boolean, useMultiSig: boolean}) {

    const { keypair, client } = getExecStuff();
    const tx = new Transaction();

    tx.moveCall({
        target: `${packageId}::satlayer_pool::toggle_vault_pause`,
        arguments: [
          tx.object(AdminCap),
          tx.object(Vault),
          tx.pure.bool(pause),
          tx.object(Version),
        ],
        typeArguments: [COIN_A_TYPE, COIN_B_TYPE ],
    });

    if (useMultiSig) {
        console.log(`Toggle vault pause to ${pause} raw tx hex:\n`, await getTxHex({
            tx,
            client
        }));
        return
    }

    // To execute the transaction
    const result = await client.signAndExecuteTransaction({
        signer: keypair,
        transaction: tx,
    });
    console.log(result);
}

toggleVaultPause({
    pause: true, // set pause value here, by default vault is paused when first created/initialized
    useMultiSig: true
});
