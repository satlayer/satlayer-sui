import { Transaction } from '@mysten/sui/transactions';
import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';
import { toHex } from '@mysten/bcs';
import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui/utils";

const NETWORK = 'mainnet'
const DEPOSIT_COIN_TYPE = '0xa03ab7eee2c8e97111977b77374eaf6324ba617e7027382228350db08469189e::ybtc::YBTC'
const RECEIPT_COIN_TYPE = '0x9e998601660bba48e7fabefa97de5b6c80c970f2a18ee31a028c7fc02a4e97f5::satybtc::SATYBTC'
const PACKAGE_ID = '0x25646e1cac13d6198e821aac7a94cbb74a8e49a2b3bed2ffd22346990811fcc6'
const VAULT_ADDRESS = '0x828dcef43c2c0ecf3720d26136aab40e819688b96bad0e262fbaa3672110d2d9'
const VERSION_ADDRESS = '0xb912d253b44aba319b568f87cf7bf730be6f73964350f16fa4b9ddd46929f8da'
const SIGNER_ADDRESS = '0xYourSignerAddress'; // Replace with your actual signer address

async function claimWithdrawal() {
    const client = new SuiClient({
        url: getFullnodeUrl(NETWORK),
    });
    const tx = new Transaction();

    const coinToWithdraw = tx.moveCall({
        target: `${PACKAGE_ID}::satlayer_pool::withdraw`,
        arguments: [
            tx.object(VAULT_ADDRESS),
            tx.object(SUI_CLOCK_OBJECT_ID),
            tx.object(VERSION_ADDRESS),
        ],
        typeArguments: [
            DEPOSIT_COIN_TYPE,
            RECEIPT_COIN_TYPE,
        ]
    });

    tx.transferObjects([coinToWithdraw], SIGNER_ADDRESS);
    tx.setGasBudget(50000000);
    tx.setSender(SIGNER_ADDRESS);
    const txBytes = await tx.build({client});
    return toHex(txBytes)
}

claimWithdrawal().then((txHex) => {
    console.log("Raw transaction hex:\n", txHex);
}).catch((error) => {
    console.error("Error generating transaction hex:", error);
});
