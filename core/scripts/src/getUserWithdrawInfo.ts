import { Transaction } from '@mysten/sui/transactions';
import { COIN_A_TYPE, COIN_B_TYPE, packageId, Vault } from '../utils/packageInfo';
import { bcs } from '@mysten/sui/bcs';
import getExecStuff from '../utils/execStuff';

async function getUserWithdrawInfo() {
    // Define keyValMap with the correct keys based on the Move function
    const keyValMap = {
        "withdrawalRequests": 0,
        "withdrawAmount": 0
    };
    
    const { keypair, client } = getExecStuff();
    const tx = new Transaction();

    tx.moveCall({
        target: `${packageId}::satlayer_pool::get_user_withdraw_info`,
        arguments: [
           tx.object(Vault), 
        ],
        typeArguments: [
            COIN_A_TYPE,
            COIN_B_TYPE,
        ]
    });

    const txResults = (
        await client.devInspectTransactionBlock({
            transactionBlock: tx,
            sender: keypair.getPublicKey().toSuiAddress(),
        })
    );

    if (!txResults.results?.length) {
      throw Error(
        `transaction didn't return any values: ${JSON.stringify(txResults, null, 2)}`,
      );
    }

    txResults.results![0].returnValues.forEach((result, index) => {
        const val = bcs.u64().parse(Uint8Array.from(result[0]));
        keyValMap[Object.keys(keyValMap)[index]] = Number(val);
    });

    console.log("withdraw info:", keyValMap);

}

getUserWithdrawInfo();