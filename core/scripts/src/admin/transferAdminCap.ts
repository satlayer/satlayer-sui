import { Transaction } from '@mysten/sui/transactions';
import * as dotenv from 'dotenv';
import getExecStuff from '../../utils/execStuff';
import { AdminCap, packageId  } from '../../utils/packageInfo';
import getTxHex from '../../utils/getTxHex';
dotenv.config();

async function transferAdminCap({recipient, useMultiSig}: {recipient: string, useMultiSig: boolean}) {

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

    if (useMultiSig) {
        console.log('Transfer admin cap raw tx hex:', await getTxHex({
            tx,
            client
        }));
        return
    }

    // To execute transaction
    const result = await client.signAndExecuteTransaction({
        signer: keypair,
        transaction: tx,
    });
    console.log(result);
}

transferAdminCap({
    recipient: '', // add new admin address here
    useMultiSig: true
});
