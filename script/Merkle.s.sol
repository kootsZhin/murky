// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console.sol";
import "../src/Merkle.sol";
import "./common/ScriptHelper.sol";

contract MerkleScript is Script, ScriptHelper {
    using stdJson for string;

    function getValuesByIndex(uint256 i, uint256 j) internal pure returns (string memory) {
        return string.concat(".values.", vm.toString(i), ".", vm.toString(j));
    }

    function generateJsonEntries(string memory inputs, string memory proof, string memory root, string memory leaf) internal pure returns (string memory) {
        string memory result = string.concat(
            "{",
            "\"inputs\":", inputs, ",",
            "\"proof\":", proof, ",",
            "\"root\":\"", root, "\",",
            "\"leaf\":\"", leaf, "\"",
            "}"
        );

        return result;
    }

    function run() public {
        Merkle m = new Merkle();

        string memory inputPath = "/script/target/input.json";
        string memory outputPath = "/script/target/output.json";

        console.log("Generating Merkle Proof for %s", inputPath);

        string memory elements = vm.readFile(string.concat(vm.projectRoot(), inputPath));

        string[] memory types = elements.readStringArray(".types");
        uint256 count = elements.readUint(".count");

        bytes32[] memory leafs = new bytes32[](count);
        string[] memory inputs = new string[](count);

        string[] memory outputs = new string[](count);
        string memory output;

        for (uint256 i = 0; i < count; ++i) {
            string[] memory input = new string[](types.length);
            bytes32[] memory data = new bytes32[](types.length);

            for (uint256 j = 0; j < types.length; ++j) {
                if (compareStrings(types[j], "address")) {
                    address value = elements.readAddress(getValuesByIndex(i, j));
                    data[j] = bytes32(uint256(uint160(value)));
                    input[j] = vm.toString(value);
                } else if (compareStrings(types[j], "uint")) {
                    uint256 value = vm.parseUint(elements.readString(getValuesByIndex(i, j)));
                    data[j] = bytes32(value);
                    input[j] = vm.toString(value);
                }
            }

            leafs[i] = keccak256(bytes.concat(keccak256(ltrim64(abi.encode(data)))));
            inputs[i] = stringArrayToString(input);
        }

        for (uint256 i = 0; i < count; ++i) {
            string memory proof = bytes32ArrayToString(m.getProof(leafs, i));
            string memory root = vm.toString(m.getRoot(leafs));
            string memory leaf = vm.toString(leafs[i]);
            string memory input = inputs[i];

            outputs[i] = generateJsonEntries(input, proof, root, leaf);
        }

        output = stringArrayToArrayString(outputs);
        vm.writeFile(string.concat(vm.projectRoot(), outputPath), output);

        console.log("DONE: The output is found at %s", inputPath);
    }
}
