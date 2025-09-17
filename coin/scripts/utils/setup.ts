import { SuiObjectChangePublished } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";
import { execSync } from "child_process";
import { promises as fs } from "fs";
import getExecStuff from "../../../core/scripts/utils/execStuff";

const getPackageId = async () => {
    let packageId = "";
    let TreasuryCap = "";

    try {
        const { keypair, client } = getExecStuff();
        const packagePath = process.cwd();
        const { modules, dependencies } = JSON.parse(
            execSync(
                `sui move build --dump-bytecode-as-base64 --path ${packagePath}`,
                {
                    encoding: "utf-8",
                }
            )
        );

        const tx = new Transaction();
        const [upgradeCap] = tx.publish({
            modules,
            dependencies,
        });
        tx.transferObjects([upgradeCap], keypair.getPublicKey().toSuiAddress());

        const result = await client.signAndExecuteTransaction({
            signer: keypair,
            transaction: tx,
            options: {
                showEffects: true,
                showObjectChanges: true,
            },
            requestType: "WaitForLocalExecution"
        });
        console.log(result.digest);
        const digest_ = result.digest;
        if (result.effects?.status?.status !== "success") {
			console.log("\n\nPublishing failed");
            return;
        }

        packageId = ((result.objectChanges?.filter(
            (a) => a.type === "published"
        ) as SuiObjectChangePublished[]) ?? [])[0].packageId.replace(
            /^(0x)(0+)/,
            "0x"
        ) as string;

        //await sleep(1000);

        if (!digest_) {
            console.log("Digest is not available");
            return { packageId };
        }

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

        for (const item of txn.objectChanges || []) {
            if (item.type === "created") {
                   if (item.objectType === `0x2::coin::TreasuryCap<${packageId}::template::TEMPLATE>`)
                    TreasuryCap = String(item.objectId);

            }
        }
        const content = `export const packageId = '${packageId}';
export const TreasuryCap = '${TreasuryCap}';
export const TYPENAME = '${packageId}::template::TEMPLATE';\n`;

        await fs.writeFile(`${packagePath}/scripts/utils/packageInfo.ts`, content);

        return {
            packageId,
            TreasuryCap,
        };
}
    catch (error) {
        console.error(error);
    }
};
// Call the async function and handle the result
getPackageId()
    .then((result) => {
        console.log(result);
    })
    .catch((error) => {
        console.error(error);
    });
export default getPackageId;
