import { Transaction } from '@mysten/sui/transactions';
import * as dotenv from 'dotenv';
import getExecStuff from '../utils/execStuff';
import {COIN_A_TYPE, CoinLBTCTreasuryCap } from '../utils/packageInfo';
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
    
}
mintLBTC(
    '0x821febff0631744c231a0f696f62b72576f2634b2ade78c74ff20f1df97fc9bf', 
    5_000_000_000
);