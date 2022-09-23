// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;


struct Drawing {
    address owner;
    uint256[] image;
}

contract BoardManager {
    enum Status {
        Idle,
        Started,
        Finished
    }

    uint256[16] NO_DRAWING;

    Drawing[] drawings;
    uint32 first_assignable;
    uint32 last_assignable;
    uint32 ring;
    uint32 rings_offset;

    Status status = Status.Idle;

    function start() public {
        require(status == Status.Idle, "Can't start an already started board");
        status = Status.Started;
    }

    function reserveCanvas() {
        for (uint i = first_assignable; i < last_assignable; i++) {
            Drawing drawing = drawings[i];
            if (drawings.owner == address(0x0) && isEmptyDrawing(drawing.image)) {
                drawings[i] = Drawing(msg.sender, timestamp, NO_DRAWING);

                    //TODO timestamp
                break;
            }
        }
    }

    function getMyCanvas() view public returns (uint256[16] memory) {
        for (uint i = first_assignable; i < last_assignable; i++) {
            if (drawings[i].owner == msg.sender) {
                return drawings[i].image;
            }
        }
        return NO_DRAWING;//TODO maybe fail instead?
    }

    function getCanvas() view public returns (uint256[16][4] memory) {
        require(status == Status.Started, "Board must be started before getting a canvas");
        uint256[16] memory last = drawings.length > 0 ? drawings[drawings.length - 1].image : NO_DRAWING;
        uint256[16][4] memory result = [NO_DRAWING, NO_DRAWING, NO_DRAWING, last];
        return result;
    }

    function draw(uint256[16] calldata drawing) public {
        require(status == Status.Started, "Board must be started before drawing");
        require(!isEmptyDrawing(drawing), "Drawing shouldn't be empty");

        for (uint i = first_assignable; i < last_assignable; i++) {
            if (drawings[i].owner == msg.sender) {
                drawing[i].image = drawing;
                if (i == first_assignable) {
                    //TODO calculate first assignable
                }
                break;
            }
        }
        return NO_DRAWING;
    }

    function finish() public {
        require(status == Status.Started, "Board must be started in order to be finished");
        status = Status.Finished;
    }

    function isEmptyDrawing(uint256[16] calldata drawing) private pure returns(bool) {
        for (uint i = 0; i < 16;) {
            if (drawing[i] > 0)
                return false;
            unchecked { i += 1; }
        }
        return true;
    }
}
