// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract BoardManager {
    enum Status {
        Idle,
        Started,
        Finished
    }

    uint32 ZERO = uint32(0);
    uint32[] board;
    Status status = Status.Idle;

    function start() public returns (uint32) {
        require(status == Status.Idle, "Can't start an already started board");
        status = Status.Started;
        return 0;
    }

    function getCanvas() view public returns (uint32[] memory) {
        require(status == Status.Started, "Board must be started before getting a canvas");
        uint32[] memory result = new uint32[](4);
        uint32 last = board.length > 0 ? board[board.length - 1] : ZERO;
        result[0] = ZERO;
        result[1] = ZERO;
        result[2] = ZERO;
        result[3] = last;
        return result;
    }

    function draw(uint32 drawing) public returns (uint32) {
        require(drawing > 0, "Drawing shouldn't be empty");
        board.push(drawing);
        return 0;
    }

    function finish() public returns (uint32) {
        require(status == Status.Started, "Board must be started in order to be finished");
        status = Status.Finished;
        return 0;
    }
}