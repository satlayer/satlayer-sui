import { Transaction } from '@mysten/sui/transactions';
import * as dotenv from 'dotenv';
import getExecStuff from '../utils/execStuff';
import {COIN_A_TYPE, CoinLBTCTreasuryCap, packageId } from '../utils/packageInfo';
import writeIntoPackageInfo from '../utils/writeIntoPackageInfo';
dotenv.config();

async function mintLBTC(recipient: string, mint_amount: number,) {
    const { keypair, client } = getExecStuff();
    const tx = new Transaction();

    let coin_lbtc = tx.moveCall({
        target: `0x2::coin::mint`,
        arguments: [
            tx.object(CoinLBTCTreasuryCap),
            tx.pure.u64(mint_amount),
        ],
        typeArguments: [
            COIN_A_TYPE
        ]
    });
    tx.transferObjects([coin_lbtc], tx.pure.address(recipient));
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
        let lbtc_coin_object_id: any;

        for (let item of output) {
            //  NOTE NEED TO FIX With TYPE
            if (item.type === 'created' && item.objectType === `0x2::coin::Coin<${packageId}::lbtc::LBTC>`) {
                lbtc_coin_object_id = String(item.objectId);
            }
        }

        console.log(`Lbtc_coin_object_id: ${lbtc_coin_object_id}`);

    
}
mintLBTC(
    '0x821febff0631744c231a0f696f62b72576f2634b2ade78c74ff20f1df97fc9bf', 
    5_000_000_000
);