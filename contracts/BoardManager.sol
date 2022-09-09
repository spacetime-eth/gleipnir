// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract BoardManager {
    enum Status {
        Idle,
        Started,
        Finished
    }

    uint256[16] NO_DRAWING = [
        0x0, 0x0, 0x0, 0x0,
        0x0, 0x0, 0x0, 0x0,
        0x0, 0x0, 0x0, 0x0,
        0x0, 0x0, 0x0, 0x0
    ];
    uint256[16][] board;
    Status status = Status.Idle;

    function start() public {
        require(status == Status.Idle, "Can't start an already started board");
        status = Status.Started;
    }

    function getCanvas() view public returns (uint256[16][4] memory) {
        require(status == Status.Started, "Board must be started before getting a canvas");
        uint256[16] memory last = board.length > 0 ? board[board.length - 1] : NO_DRAWING;
        uint256[16][4] memory result = [NO_DRAWING, NO_DRAWING, NO_DRAWING, last];
        return result;
    }

    function draw(uint256[16] calldata drawing) public {
        require(status == Status.Started, "Board must be started before drawing");
        require(isNotEmpty(drawing), "Drawing shouldn't be empty");
        board.push(drawing);
    }

    function finish() public {
        require(status == Status.Started, "Board must be started in order to be finished");
        status = Status.Finished;
    }

    function isNotEmpty(uint256[16] calldata drawing) private pure returns(bool) {
        for (uint i = 0; i < 16;) {
            if (drawing[i] > 0)
                return true;
            unchecked { i += 1; }
        }
        return false;
    }
}