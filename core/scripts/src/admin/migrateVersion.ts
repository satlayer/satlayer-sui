import { Transaction } from '@mysten/sui/transactions';
import * as dotenv from 'dotenv';
import getExecStuff from '../../utils/execStuff';
import { packageId, VAdminCap, Version,  } from '../../utils/packageInfo';
dotenv.config();

async function migrateVersion(new_version: number) {
    const { keypair, client } = getExecStuff();
    const tx = new Transaction();

    tx.moveCall({
        target: `${packageId}::version::migrate`,
        arguments: [
          tx.object(VAdminCap), 
          tx.object(Version),  
          tx.pure.u64(new_version),
        ],
    });
    const result = await client.signAndExecuteTransaction({
        signer: keypair,
        transaction: tx,
    });
    console.log(result); 
}
migrateVersion(2);