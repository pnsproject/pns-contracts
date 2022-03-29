const fs = require('fs')

function dump(varname, filepath) {
	let data = fs.readFileSync(filepath)
	return varname + JSON.stringify(JSON.parse(data.toString('utf8')).abi)
}

function exportAbi() {
	const string1 = dump('export const PnsAbi: any =', 'artifacts/contracts/pns/IPNS.sol/IPNS.json') + '\n'
	const string2 = dump('export const ControllerAbi: any =', 'artifacts/contracts/pns/PNSController.sol/Controller.json') + '\n'
	const string3 = dump('export const ResolverAbi: any =', 'artifacts/contracts/pns/PNSResolver.sol/PNSResolver.json')

	const fWrite = fs.createWriteStream('./abi.ts');
  fWrite.write(string1 + string2 + string3);
}

/**
 * Create a file named abi.ts in root directory
 * Replace the file with the same name in pns-sdk
 */

exportAbi()
