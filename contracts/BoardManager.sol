// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract BoardManager {
    uint32 ZERO = uint32(0);
    uint32[] board;

    function start() pure public returns (uint32) {
        return 0;
    }

    function getCanvas() view public returns (uint32[] memory) {
        uint32[] memory result = new uint32[](4);
        uint32 last = board.length > 0 ? board[board.length - 1] : ZERO;
        result[0] = ZERO;
        result[1] = ZERO;
        result[2] = ZERO;
        result[3] = last;
        return result;
    }

    function draw(uint32 drawing) public returns (uint32) {
        board.push(drawing);
        return 0;
    }

    function finish() public pure returns (uint32) {
        return 0;
    }
}