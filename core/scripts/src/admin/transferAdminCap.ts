import { Transaction } from '@mysten/sui/transactions';
import * as dotenv from 'dotenv';
import getExecStuff from '../../utils/execStuff';
import { AdminCap, packageId  } from '../../utils/packageInfo';
dotenv.config();

async function transferAdminCap(recipient: string) {

    const { keypair, client } = getExecStuff();
    const tx = new Transaction();

    tx.moveCall({
        target: `0x2::transfer::public_transfer`,
        arguments: [
          tx.object(AdminCap), 
          tx.pure.address(recipient),

        ],
        typeArguments: [`${packageId}::satlayer_pool::AdminCap`],
    });
    const result = await client.signAndExecuteTransaction({
        signer: keypair,
        transaction: tx,
    });
    console.log(result); 
}

transferAdminCap('0x821febff0631744c231a0f696f62b72576f2634b2ade78c74ff20f1df97fc9bf');