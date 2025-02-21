import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';
import { Ed25519Keypair, } from '@mysten/sui/keypairs/ed25519';
import * as dotenv from 'dotenv';
dotenv.config();

type network_type = "mainnet" | "testnet" | "devnet" | "localnet";

const MNEMONICS = process.env.MNEMONICS || "";
const NETWORK  = process.env.NETWORK as network_type;
const ADDRESS = process.env.ADDRESS || "";

const getExecStuff = () => {
    const keypair = Ed25519Keypair.deriveKeypair(MNEMONICS);
    const client = new SuiClient({
        url: getFullnodeUrl(NETWORK),
    });
    //console.log(keypair, client)
    return { keypair, client };
}
export default getExecStuff;