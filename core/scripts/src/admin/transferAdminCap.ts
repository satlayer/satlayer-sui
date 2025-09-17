import { Transaction } from '@mysten/sui/transactions';
import * as dotenv from 'dotenv';
import getExecStuff from '../../utils/execStuff';
import { AdminCap, packageId  } from '../../utils/packageInfo';
import getTxHex from '../../utils/getTxHex';
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
    // To execute transaction
    // const result = await client.signAndExecuteTransaction({
    //     signer: keypair,
    //     transaction: tx,
    // });
    // console.log(result);

    // To get the raw transaction bytes
    console.log('Transfer admin cap raw tx hex:', await getTxHex({
        tx,
        client
    }));
}

transferAdminCap('0x28e2822f5d5ae714299e664ab1739667f65240263c70f26afce3cf086c67c7ec');
