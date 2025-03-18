import { Transaction, UpgradePolicy } from '@mysten/sui/transactions';
import getExecStuff from './execStuff';
import { packageId, UpgradeCap } from './packageInfo';

const { execSync } = require('child_process');

const getPackageId = async (packageId: string, capId: string) => {
    try {
        const { keypair, client } = getExecStuff();
        const packagePath = process.cwd();
        const { modules, dependencies, digest } = JSON.parse(
            execSync(`sui move build --dump-bytecode-as-base64 --path ${packagePath}`, {
                encoding: "utf-8",
            })
        );
        const tx = new Transaction();

        const cap = tx.object(capId);
        const ticket = tx.moveCall({
            target: '0x2::package::authorize_upgrade',
            arguments: [cap, tx.pure.u8(UpgradePolicy.COMPATIBLE), tx.pure.vector('u8', digest)],
        });
        const receipt = tx.upgrade({
            modules,
            dependencies,
            package: packageId,
            ticket,
        });
        tx.moveCall({
		    target: '0x2::package::commit_upgrade',
		    arguments: [cap, receipt],
	    });

        const result = await client.signAndExecuteTransaction({
            transaction: tx,
            signer: keypair,
            options: {
                showEffects: true,
                showObjectChanges: true,
            },
        });
        console.log(result); 
        return { result};
    } catch (error) {
        // Handle potential errors if the promise rejects
        console.error(error);
        return {result: ''};
    }
};

// Call the async function and handle the result.
getPackageId(packageId, UpgradeCap)
    .then((result) => {
        console.log(result);
    })
    .catch((error) => {
        console.error(error);
    });

export default getPackageId;