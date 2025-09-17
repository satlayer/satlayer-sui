import { Transaction } from '@mysten/sui/transactions';
import * as dotenv from 'dotenv';
import getExecStuff from '../../utils/execStuff';
import { AdminCap, COIN_A_TYPE, COIN_B_TYPE, packageId, Vault, Version,  } from '../../utils/packageInfo';
import { toHex } from '@mysten/bcs';
dotenv.config();

async function toggleVaultPause(pause: boolean) {

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

    // Sign and execute the transaction
    const result = await client.signAndExecuteTransaction({
        signer: keypair,
        transaction: tx,
    });
    console.log(result);

    // For getting the raw transaction bytes
    // tx.setGasBudget(10000);
    // tx.setSender(keypair.getPublicKey().toSuiAddress());
    // const txBytes = await tx.build({client});
    // const txHex = toHex(txBytes)
    // console.log(txHex);
}
toggleVaultPause(false);
