import { ethers } from 'ethers';
import * as fs from 'fs';

const args = process.argv;
const contract = args[2];
const constructorInputs = Array(JSON.parse(args[3]));

function extractABI(contractName: string): any {
	contractName = contractName.replace(":", "/");

	// TODO: take artifact path directly from foundry.toml
    const filePath = `out/${contractName}.json`;

    try {
        const jsonData = fs.readFileSync(filePath, 'utf-8');
        const contractJSON = JSON.parse(jsonData);
        
        return contractJSON.abi;
    } catch (error) {
        console.error('Error reading or parsing JSON file:', error);
        return null;
    }
}

const abi = extractABI(contract);

// Function to encode data based on the ABI format
function encodeData(abi: any[], constructorInputs: any[]): string {

    // Function to generate type array based on the ABI format
    function generateTypeArray(abi: any[]): string[] {
        const constructorAbi = abi.find(item => item.type === 'constructor');
        if (!constructorAbi) {
            throw new Error(`Constructor not found in ABI.`);
        }

        const inputs = constructorAbi.inputs;

        // Recursive function to traverse and generate type array
        function traverseInputs(inputs: any, depth: number): any {
            if (depth == 0) {
                return inputs.map((input: any) => {
                    if (input.type === 'tuple') {
                        return `tuple(${traverseInputs(input.components, depth + 1)})`;
                    } else {
                        return input.type;
                    }
                });
            }
            return inputs.map((input: any) => {
                if (input.type === 'tuple') {
                    return `tuple(${traverseInputs(input.components, depth + 1)})`;
                } else {
                    return input.type;
                }
            }).join(', ');
        }
        
        const typeArray: string[] = traverseInputs(inputs, 0);
        return typeArray;
    }

    const types = generateTypeArray(abi);

    return ethers.utils.defaultAbiCoder.encode(types, constructorInputs[0]);
}

// Example usage
// const constructorInputs = [["0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5", 2, ["0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5", 2, ["0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5", 2]]], 2, 3];

// Encode the constructor inputs
const encodedData = encodeData(abi, constructorInputs);
process.stdout.write(encodedData);
