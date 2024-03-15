import { ethers } from 'ethers';

// ABI format specified
const abi = [
	{
		"inputs": [
			{
				"components": [
					{
						"internalType": "address",
						"name": "a",
						"type": "address"
					},
					{
						"internalType": "uint256",
						"name": "b",
						"type": "uint256"
					},
					{
						"components": [
							{
								"internalType": "bytes",
								"name": "c",
								"type": "bytes"
							},
							{
								"internalType": "uint256",
								"name": "d",
								"type": "uint256"
							},
							{
								"components": [
									{
										"internalType": "string",
										"name": "c",
										"type": "string"
									},
									{
										"internalType": "uint256",
										"name": "d",
										"type": "uint256"
									}
								],
								"internalType": "struct Encoder.StructC",
								"name": "structC",
								"type": "tuple"
							}
						],
						"internalType": "struct Encoder.StructB",
						"name": "structB",
						"type": "tuple"
					}
				],
				"internalType": "struct Encoder.structA",
				"name": "simpleStruct",
				"type": "tuple"
			},
			{
				"internalType": "uint256",
				"name": "a",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "b",
				"type": "uint256"
			}
		],
		"stateMutability": "nonpayable",
		"type": "constructor"
	},
	{
		"inputs": [
			{
				"components": [
					{
						"internalType": "address",
						"name": "a",
						"type": "address"
					},
					{
						"internalType": "uint256",
						"name": "b",
						"type": "uint256"
					},
					{
						"components": [
							{
								"internalType": "bytes",
								"name": "c",
								"type": "bytes"
							},
							{
								"internalType": "uint256",
								"name": "d",
								"type": "uint256"
							},
							{
								"components": [
									{
										"internalType": "string",
										"name": "c",
										"type": "string"
									},
									{
										"internalType": "uint256",
										"name": "d",
										"type": "uint256"
									}
								],
								"internalType": "struct Encoder.StructC",
								"name": "structC",
								"type": "tuple"
							}
						],
						"internalType": "struct Encoder.StructB",
						"name": "structB",
						"type": "tuple"
					}
				],
				"internalType": "struct Encoder.structA",
				"name": "someStruct",
				"type": "tuple"
			},
			{
				"internalType": "uint256",
				"name": "a",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "b",
				"type": "uint256"
			}
		],
		"name": "encode",
		"outputs": [
			{
				"internalType": "bytes",
				"name": "",
				"type": "bytes"
			}
		],
		"stateMutability": "pure",
		"type": "function"
	}
];

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

    return ethers.utils.defaultAbiCoder.encode(types, constructorInputs);
}

// Example usage
const constructorInputs = [["0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5", 2, ["0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5", 2, ["0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5", 2]]], 2, 3];

// Encode the constructor inputs
const encodedData = encodeData(abi, constructorInputs);
console.log("Encoded data:", encodedData);
