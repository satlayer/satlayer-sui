import { Transaction } from '@mysten/sui/transactions';
import * as dotenv from 'dotenv';
import getExecStuff from '../../utils/execStuff';
import { AdminCap, COIN_B_TYPE, COIN_A_TYPE, packageId, Vault, Version,  } from '../../utils/packageInfo';
dotenv.config();

async function updateWithdrawalTime() {

    const { keypair, client } = getExecStuff();
    const tx = new Transaction();
    
    const withdrawaltimestamp = 5 * 60 * 1000;

    tx.moveCall({
        target: `${packageId}::satlayer_pool::update_withdrawal_time`,
        arguments: [
          tx.object(AdminCap), 
          tx.object(Vault),  
          tx.pure.u64(withdrawaltimestamp), // limit 
          tx.object(Version),
        ],
        typeArguments: [COIN_A_TYPE, COIN_B_TYPE ],
    });
    const result = await client.signAndExecuteTransaction({
        signer: keypair,
        transaction: tx,
    });
    console.log(result); 
}
updateWithdrawalTime();