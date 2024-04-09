import { ethers } from 'ethers';
import * as fs from 'fs';

function extractABI(artifactPath: string, artifactDirectory: string): any {
	artifactPath = artifactPath.replace(":", "/");

    const filePath = `${artifactDirectory}${artifactPath}.json`;

    try {
        const jsonData = fs.readFileSync(filePath, 'utf-8');
        const contractJSON = JSON.parse(jsonData);
        
        return contractJSON.abi;
    } catch (error) {
        throw new Error(`ABI not found on path.`);
    }
}

// Recursive function to traverse and generate type array
function traverseInputs(inputs: any, depth: number): any {
	if (depth == 0) {
		return inputs.map((input: any) => {
			if (input.type === 'tuple[]') {
				return `tuple(${traverseInputs(input.components, depth + 1)})[]`
			}
			if (input.type === 'tuple') {
				return `tuple(${traverseInputs(input.components, depth + 1)})`;
			} else {
				return input.type;
			}
		});
	}
	return inputs.map((input: any) => {
		if (input.type === 'tuple[]') {
			return `tuple(${traverseInputs(input.components, depth + 1)})[]`
		}
		else if (input.type === 'tuple') {
			return `tuple(${traverseInputs(input.components, depth + 1)})`;
		} else {
			return input.type;
		}
	}).join(', ');
}

// Function to generate type array based on the ABI format
function generateTypeArray(abi: any[]): string[] {
	const constructorAbi = abi.find(item => item.type === 'constructor');
	if (!constructorAbi) {
		throw new Error(`Constructor not found in ABI.`);
	}

	const inputs = constructorAbi.inputs;
	
	const typeArray: string[] = traverseInputs(inputs, 0);
	return typeArray;
}

// Function to encode data based on the ABI format
function encodeData(abi: any[], constructorInputs: any[]): string {

    const types = generateTypeArray(abi);

  console.log(types);
  console.log(constructorInputs);

    return ethers.utils.defaultAbiCoder.encode(types, constructorInputs);
}

// Gets command line arguments
const args = process.argv;

// Removes '\' from command line args
const cleanedArg = args[2].replace(/\\/g, "");

const constructorInputs = JSON.parse(cleanedArg);

const artifactPath = args[3];

const artifactDirectory = args[4];

const abi = extractABI(artifactPath, artifactDirectory);

// Encode the constructor inputs
const encodedData = encodeData(abi, constructorInputs);
process.stdout.write(encodedData);
