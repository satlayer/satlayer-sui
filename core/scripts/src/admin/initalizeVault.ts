import { Transaction } from '@mysten/sui/transactions';
import * as dotenv from 'dotenv';
import getExecStuff from '../../utils/execStuff';
import { packageId, ReceiptTokenTreasuryCap, AdminCap, COIN_A_TYPE, COIN_B_TYPE, Version } from '../../utils/packageInfo';
import writeIntoPackageInfo from '../../utils/writeIntoPackageInfo';
dotenv.config();

async function intializeVault() {
    try {
    const { keypair, client } = getExecStuff();
    const tx = new Transaction();
    let withdrawaltimestamp = 5 * 60 * 1000;
    
    tx.moveCall({
        target: `${packageId}::satlayer_pool::initialize_vault`,
        arguments: [
            tx.object(AdminCap),
            tx.object(ReceiptTokenTreasuryCap), 
            tx.pure.u64(10_000_000_000),
            tx.pure.u64(withdrawaltimestamp),
            tx.object(Version),
        ],
        typeArguments: [
            COIN_A_TYPE,
            COIN_B_TYPE,
        ]
    });

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
        const txn = await client.waitForTransaction({
            digest: result.digest,
            options: {
                showEffects: true,
                showInput: false,
                showEvents: false,
                showObjectChanges: true,
                showBalanceChanges: false,
            },
        });

        let output: any = txn.objectChanges;
        let Vault;

        for (let item of output) {
            //  NOTE NEED TO FIX With TYPE
            if (item.type === 'created' && item.objectType === `${packageId}::satlayer_pool::Vault<${COIN_A_TYPE}, ${COIN_B_TYPE}>`) {
                Vault = String(item.objectId);
            }
        }

        console.log(`Vault: ${Vault}`);

        await writeIntoPackageInfo('Vault', Vault);

    } catch (error) {
        console.error('Error creating  Vault', error);
    }
    
}
intializeVault();