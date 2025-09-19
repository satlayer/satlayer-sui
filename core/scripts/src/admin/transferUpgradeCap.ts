import { Transaction } from '@mysten/sui/transactions';
import * as dotenv from 'dotenv';
import getExecStuff from '../../utils/execStuff';
import { ReceiptTokenUpgradeCap, UpgradeCap  } from '../../utils/packageInfo';
import getTxHex from '../../utils/getTxHex';
dotenv.config();

async function transferUpgradeCap({recipient, useMultiSig}: {recipient: string, useMultiSig: boolean}) {

    const { keypair, client } = getExecStuff();
    const tx = new Transaction();

    tx.moveCall({
        target: `0x2::transfer::public_transfer`,
        arguments: [
          tx.object(ReceiptTokenUpgradeCap),
          tx.pure.address(recipient),

        ],
        typeArguments: ['0x2::package::UpgradeCap'],
    });

    if (useMultiSig) {
        console.log('Transfer upgrade cap raw tx hex:', await getTxHex({
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

transferUpgradeCap({
    recipient: '0xb6df3b6477a23b4c071f0441429a3e7bba630604a1aaf7dd7342f7e268fa0c9c', // add new address here
    useMultiSig: false
});
