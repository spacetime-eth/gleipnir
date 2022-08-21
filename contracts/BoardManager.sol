// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract BoardManager {
    uint256 ZERO = uint256(0);

    function start() pure public returns (int) {
        return 0;
    }

    function getCanvas() pure public returns (uint32[] memory) {
        uint32[] memory result = new uint32[](4);
        result[0] = 0;
        result[1] = 0;
        result[2] = 0;
        result[3] = 0;
        return result;
    }
}