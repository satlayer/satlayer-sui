import { normalizeSuiObjectId } from "@mysten/sui/utils";
import { SuiObjectChangePublished } from '@mysten/sui/client';
import { Transaction } from "@mysten/sui/transactions";
import { fromHex } from "@mysten/bcs";
import { CompiledModule, getByteCode } from "./bytecode-template";
import init, * as wasm from "move-binary-format-wasm"
import { bytecode as genesis_bytecode } from "./genesis_bytecode";
import getExecStuff from "./execStuff";
import { promises as fs } from 'fs';

// Helper delay function
const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

const publishNewAsset = async (
  moduleName: string,
  name: string,
  symbol: string,
  description: string,
  icon_url: string,
) => {
  let packageId = '';
  let CoinMetadata = '';
  let UpgradeCap = '';
  let TreasuryCap = '';
  let typename = '';

  try {
    const { keypair, client } = getExecStuff();
    const packagePath = process.cwd();
    if (!keypair || !client) throw new Error("Invalid keypair or client");
    
    const signer = keypair;
    const template = genesis_bytecode;
    let deserializedTemplate: any;
    try {
      deserializedTemplate = JSON.parse(wasm.deserialize(template));
      console.log(`deserializedTemplate: ${deserializedTemplate}`);
    } catch (e) {
      throw new Error(`Failed to deserialize template: ${e.message}`);
    }

    const compiledModule = new CompiledModule(deserializedTemplate)
      .updateConstant(0, symbol, "Symbol", "string")
      .updateConstant(1, name, "Name", "string")
      .updateConstant(2, description, "Description", "string")
      .updateConstant(3, icon_url, "Icon_url", "string")
      .changeIdentifiers({
        template: moduleName,
        TEMPLATE: moduleName.toUpperCase(),
      });

    const bytesToPublish = wasm.serialize(JSON.stringify(compiledModule));
    console.log(bytesToPublish);

    // Construct and validate transaction
    const tx = new Transaction();
    const [upgradeCap] = tx.publish({
      modules: [[...fromHex(bytesToPublish)]],
      dependencies: [
        normalizeSuiObjectId("0x1"),
        normalizeSuiObjectId("0x2"),
      ],
    });

    tx.transferObjects([upgradeCap], signer.getPublicKey().toSuiAddress());
    tx.setGasBudget(100000000);

    // Execute transaction
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

    packageId = ((result.objectChanges?.filter(
      (a) => a.type === "published"
    ) as SuiObjectChangePublished[]) ?? [])[0]
      .packageId.replace(/^(0x)(0+)/, "0x") as string;

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
    
    // Introduce a delay to ensure that all object changes, including TreasuryCap, are available
    await sleep(3000); // waits for 3 seconds

    const output: any = txn.objectChanges;

    for (let i = 0; i < output.length; i++) {
      const item = output[i];
      // Remove unnecessary awaits on simple property accesses
      if (item.type === 'created') {
        if (item.objectType === `0x2::coin::CoinMetadata<${packageId}::${moduleName}::${moduleName.toUpperCase()}>`) {
          CoinMetadata = String(item.objectId);
        }
        if (item.objectType === `0x2::package::UpgradeCap`) {
          UpgradeCap = String(item.objectId);
        }
        if (item.objectType === `0x2::coin::TreasuryCap<${packageId}::${moduleName}::${moduleName.toUpperCase()}>`) {
          TreasuryCap = String(item.objectId);
        }
      }
    }

    typename = `${packageId}::${moduleName}::${moduleName.toUpperCase()}`;

    // Write the results to files
    const content = `export const packageId = '${packageId}';
export const CoinMetadata= '${CoinMetadata}';
export const UpgrdeCap = '${UpgradeCap}';
export const TreasuryCap = '${TreasuryCap}';
export const typename = '${packageId}::${moduleName}::${moduleName.toUpperCase()}';\n`;

    await fs.writeFile(`${packagePath}/scripts/utils/packageInfo.ts`, content);
    await fs.writeFile(`${packagePath}/coin_info/coin.txt`, content);

    return { packageId, CoinMetadata, UpgradeCap, TreasuryCap, typename };
  } catch (error) {
    console.error(error);
    return { packageId, CoinMetadata, UpgradeCap, TreasuryCap , typename};
  }
};

publishNewAsset("sat_btc", "SAT BTC", "SAT_LBTC", "satlayer", "data:image/webp;base64,UklGRogDAABXRUJQVlA4WAoAAAAQAAAAPwAAPwAAQUxQSJoBAAABgJr9/9Po94/ClmsLhKwAmYCbBHBIJriOx0dmgKIi2wi9uiY7ye8q5f/N+Yhw5LaRI0kzs/HYwe4nUEaFZnpRc7A5MB82g2bkmpogeQrdDturmBONl63Q1iV9UTCC7o4zuesGRkHCP4pP4wtn9jJ5LoqcaH6fc9r31VzfWo2YcxvXzexfKs6CpbhwlIyo4ZYluQ3VTDxUzizNc+Uhy11lqVbTL7XCkq2k/ah8nGVzDpVk3C1Ld+skYs0Z4LycNNprDLGu/cWPMcT+H4weg+wZv2fbM8N8Ej+UxjhGv14CBhp8o3eRdHQie4tkaxOFDDUkvYWlpVtLLEvLi7HEXsRgoyaa5gBNf4Nmc0Bz4H8v/gP+LwM0A/y4xc8b/LzFrxv4dQu+bsLX7UcivYOkq1/BvkVkjHCMS0RE4gnHs4DnhmvJLaTVMdQ0+msZk9ssStJB5EY3JbeG8nPrhwLPzfDcDu8N8N6C701ZFWZdRm9rWIJyqMrojVru3vo8ydNbx09Fge7N8np7K7W3r9qZe3uOcwM3+dzAy35uQFZQOCDIAQAAsAoAnQEqQABAAD6dPptJNCunJjAUDACwE4ljAM0N3i2MKNY+29Yc0CqvSYK0SpMxOMPAF3xL8Y59jg2ID9HPRbpe6uZpprOMHuzxoSuvxJKv8VZI95Nt/F6p0tmp2AD+/dtHFHpoKitlt9Q8f0mZUF8jwPRZ2PaZdQv5Cx5Y/NOsRn+TKZ243X6OOuGyKXk5NE9zrrn7d5Yd4rawn1ClQ6qojXMLkZBd+CTntW/TQJYJiea6Jbvrn2mq2jSjTRjMn6CR94FW7/WcM0nYAAD5VlGnuzyXJ3RTpruQzt7sPq2c9sTlY7DMmj+13dFmezi0YEHXUh7Mk019atDYy2Q5uiLPQFakj7KQHACodeMG6WGIjcefkmasrLidBXr6jz+lRvgHKlNlY9NWvHI3SfIw72dzMfs4ZvI4qL6ilKAPl9gR1VQ1F5earGvDUNJZffp28G/HzfObqdtbDis/ay/008pFfgHsd9ognfybZIdSvrsWHsyu52Q98kFlJm7PBpBmq9R7UOuC30X0dvLb1868BTUW7T5XJejAtA3/BwkD63icjQ5pvkWQe/JP8b1Zlxq2m+f3B2WKRGVaEYw0lfze/7GVcddNvaAA")
  .then((result) => {
    console.log(result);
  })
  .catch((error) => {
    console.error(error);
  });
