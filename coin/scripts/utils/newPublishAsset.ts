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
  decimal: number,
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
      .updateConstant(4, decimal, 9, "u8")
      .changeIdentifiers({
        template: moduleName,
        TEMPLATE: moduleName.toUpperCase(),
      });

    const bytesToPublish = wasm.serialize(JSON.stringify(compiledModule));
    console.log(`bytesToPublish: ${bytesToPublish}`);

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
    console.log(`Digest: ${result.digest}`);
    const digest_ = result.digest;

    console.log(`result: ${JSON.stringify(result, null, 2)}`);
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
    console.log(`output: ${JSON.stringify(output, null, 2)}`);
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

    await fs.writeFile(`${packagePath}/coin/scripts/utils/packageInfo.ts`, content);
    // await fs.writeFile(`${packagePath}/coin_info/coin.txt`, content);

    return { packageId, CoinMetadata, UpgradeCap, TreasuryCap, typename };
  } catch (error) {
    console.error(error);
    return { packageId, CoinMetadata, UpgradeCap, TreasuryCap , typename};
  }
};

// publishNewAsset("satxbtc", "SATXBTC", "satxBTC", "SatLayer XBTC", "data:image/webp;base64,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", 8)
publishNewAsset("satybtc", "SATYBTC.B", "satYBTC.B", "SatLayer Yield BTC.B", "data:image/webp;base64,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", 8)
// publishNewAsset("sat_btc", "SAT BTC", "SAT_LBTC", "satlayer", "data:image/webp;base64,UklGRogDAABXRUJQVlA4WAoAAAAQAAAAPwAAPwAAQUxQSJoBAAABgJr9/9Po94/ClmsLhKwAmYCbBHBIJriOx0dmgKIi2wi9uiY7ye8q5f/N+Yhw5LaRI0kzs/HYwe4nUEaFZnpRc7A5MB82g2bkmpogeQrdDturmBONl63Q1iV9UTCC7o4zuesGRkHCP4pP4wtn9jJ5LoqcaH6fc9r31VzfWo2YcxvXzexfKs6CpbhwlIyo4ZYluQ3VTDxUzizNc+Uhy11lqVbTL7XCkq2k/ah8nGVzDpVk3C1Ld+skYs0Z4LycNNprDLGu/cWPMcT+H4weg+wZv2fbM8N8Ej+UxjhGv14CBhp8o3eRdHQie4tkaxOFDDUkvYWlpVtLLEvLi7HEXsRgoyaa5gBNf4Nmc0Bz4H8v/gP+LwM0A/y4xc8b/LzFrxv4dQu+bsLX7UcivYOkq1/BvkVkjHCMS0RE4gnHs4DnhmvJLaTVMdQ0+msZk9ssStJB5EY3JbeG8nPrhwLPzfDcDu8N8N6C701ZFWZdRm9rWIJyqMrojVru3vo8ydNbx09Fge7N8np7K7W3r9qZe3uOcwM3+dzAy35uQFZQOCDIAQAAsAoAnQEqQABAAD6dPptJNCunJjAUDACwE4ljAM0N3i2MKNY+29Yc0CqvSYK0SpMxOMPAF3xL8Y59jg2ID9HPRbpe6uZpprOMHuzxoSuvxJKv8VZI95Nt/F6p0tmp2AD+/dtHFHpoKitlt9Q8f0mZUF8jwPRZ2PaZdQv5Cx5Y/NOsRn+TKZ243X6OOuGyKXk5NE9zrrn7d5Yd4rawn1ClQ6qojXMLkZBd+CTntW/TQJYJiea6Jbvrn2mq2jSjTRjMn6CR94FW7/WcM0nYAAD5VlGnuzyXJ3RTpruQzt7sPq2c9sTlY7DMmj+13dFmezi0YEHXUh7Mk019atDYy2Q5uiLPQFakj7KQHACodeMG6WGIjcefkmasrLidBXr6jz+lRvgHKlNlY9NWvHI3SfIw72dzMfs4ZvI4qL6ilKAPl9gR1VQ1F5earGvDUNJZffp28G/HzfObqdtbDis/ay/008pFfgHsd9ognfybZIdSvrsWHsyu52Q98kFlJm7PBpBmq9R7UOuC30X0dvLb1868BTUW7T5XJejAtA3/BwkD63icjQ5pvkWQe/JP8b1Zlxq2m+f3B2WKRGVaEYw0lfze/7GVcddNvaAA", 6)
  .then((result) => {
    console.log(result);
  })
  .catch((error) => {
    console.error(error);
  });
