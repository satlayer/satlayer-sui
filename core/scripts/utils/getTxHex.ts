import { toHex } from "@mysten/bcs";
import { SuiClient } from "@mysten/sui/dist/cjs/client";
import { Transaction } from "@mysten/sui/dist/cjs/transactions";

const getTxHex = async ({tx, client, gasBudget = 50000000}: { tx: Transaction, client: SuiClient, gasBudget?: number }) => {
  const multisigAddress = process.env.MULTISIG_ADDRESS;
  if (!multisigAddress) throw new Error("MULTISIG_ADDRESS not set in .env");

  tx.setGasBudget(gasBudget);
  tx.setSender(multisigAddress);
  const txBytes = await tx.build({client});
  return toHex(txBytes)
}

export default getTxHex;
