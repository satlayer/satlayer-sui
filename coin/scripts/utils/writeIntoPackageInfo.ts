import { promises as fs } from 'fs';
import * as path from 'path';

const writeIntoPackageInfo = async (dataName:String, writeData: String) => {
    // Read the contents of packageInfo.ts
    const packageInfoPath = path.join(__dirname, './packageInfo.ts');
    let packageInfoContent = await fs.readFile(packageInfoPath, 'utf8');

    // Replace or append writeData
    const DataLine = `export const ${dataName} = '${writeData}';\n`;
    const DataRegex = new RegExp(`^export const ${dataName} = '.*';\\n`, 'm');

    if (DataRegex.test(packageInfoContent)) {
        packageInfoContent = packageInfoContent.replace(DataRegex, DataLine);
    } else {
        packageInfoContent += DataLine;
    }

    // Write the updated content back to packageInfo.ts
    await fs.writeFile(packageInfoPath, packageInfoContent);
    console.log('packageInfo.ts updated successfully with '+ dataName +'.');
}
export default writeIntoPackageInfo;