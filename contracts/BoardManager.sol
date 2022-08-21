// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract BoardManager {
    uint256 ZERO = uint256(0);

    function start() pure public returns (int) {
        return 0;
    }

    function getCanvas() public returns (uint256[] memory) {
        uint256[] memory coso = new uint256[](4);
        coso[0] = 0;
        coso[1] = 0;
        coso[2] = 0;
        coso[3] = 0;
        return coso;
    }
}