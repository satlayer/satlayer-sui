import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';
import { Ed25519Keypair, } from '@mysten/sui/keypairs/ed25519';
import * as dotenv from 'dotenv';
dotenv.config();

type network_type = "mainnet" | "testnet" | "devnet" | "localnet";

const MNEMONICS = process.env.MNEMONICS || "";
const NETWORK  = process.env.NETWORK as network_type;
const ACCOUNT_INDEX = process.env.ACCOUNT_INDEX || "0";

const getExecStuff = () => {
    const keypair = Ed25519Keypair.deriveKeypair(MNEMONICS, `m/44'/784'/${ACCOUNT_INDEX}'/0'/0'`);
    console.log('keypair address', keypair.toSuiAddress())
    const client = new SuiClient({
        url: getFullnodeUrl(NETWORK),
    });
    //console.log(keypair, client)
    return { keypair, client };
}
export default getExecStuff;
