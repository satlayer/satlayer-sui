import { toHex } from "@mysten/bcs";
import { SuiClient } from "@mysten/sui/dist/cjs/client";
import { Transaction } from "@mysten/sui/dist/cjs/transactions";

const getTxHex = async ({tx, client}: { tx: Transaction, client: SuiClient }) => {
  const multisigAddress = process.env.MULTISIG_ADDRESS;
  if (!multisigAddress) throw new Error("MULTISIG_ADDRESS not set in .env");

  tx.setGasBudget(50000000);
  tx.setSender(multisigAddress);
  const txBytes = await tx.build({client});
  return toHex(txBytes)
}

export default getTxHex;
