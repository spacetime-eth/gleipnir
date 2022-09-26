// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "hardhat/console.sol";

struct Drawing {
    address owner;
    uint256 timestamp;
    uint256[16] image;
}

contract BoardManager {
    enum Status {
        Idle,
        Started,
        Finished
    }

    uint256[16] NO_DRAWING;

    mapping(uint => Drawing) drawings;
    uint256 first_assignable;
    uint256 last_assignable;
    uint256 first_assignable_ring;
    uint256 breakpoint;
    uint256 EXPIRATION_TIME = 1800; //TODO determine time limit

    Status status = Status.Idle;

    function start() public {
        require(status == Status.Idle, "Can't start an already started board");
        status = Status.Started;
    }

    function reserveCanvas() public {
        // TODO: check status?
        for (uint i = first_assignable; i <= last_assignable; i++) {
            if (_isAssignable(drawings[i])) {
                drawings[i] = Drawing(msg.sender, block.timestamp, NO_DRAWING);
                return;
            }
        }
        // TODO ERROR, NO PLACE FOR A NEW ONE
    }

    function getMyCanvas() view public returns (uint256[16][4] memory) {
        require(status == Status.Started, "Board must be started before getting a canvas");
        uint256 currentIndex = _getMyIndex();
        (uint256[16] memory me, uint256[16][4] memory neighbors) = getCanvas(currentIndex);
        return neighbors;
    }

    function getCanvas(uint256 index) view public returns (uint256[16] memory, uint256[16][4] memory) {
        uint256[16] memory drawing = drawings[index].image;
        uint256[16][4] memory neighbors = _getNeighbors(index);

        return (drawing, neighbors);
    }

    function draw(uint256[16] calldata drawing) public {
        require(status == Status.Started, "Board must be started before drawing");
        require(!_isEmptyDrawing(drawing), "Drawing shouldn't be empty");

        uint256 i = _getMyIndex();
        drawings[i].image = drawing;

        if (first_assignable_ring == 0) {
            // Handle first drawing special case
            first_assignable = 1;
            last_assignable = 4;
            first_assignable_ring = 1;
            breakpoint = 4;
            return;
        }

        if (i == first_assignable) {
            // Update first and last assignable
            uint256 first = first_assignable;
            uint256 last = last_assignable;
            while (!_isEmptyDrawingStorage(drawings[first].image)) {//change for do while
                first += 1;
                last += 1;
                uint256 ringIndex = first - (breakpoint - first_assignable_ring * 4) - 1;

                uint256 threshold_1 = first_assignable_ring;
                uint256 threshold_2 = first_assignable_ring * 2;
                uint256 threshold_3 = first_assignable_ring * 3;
                uint256 threshold_4 = first_assignable_ring * 4 - 1;

                if (ringIndex == threshold_1) last += 1;
                if (ringIndex == threshold_2) last += 1;
                if (ringIndex == threshold_3) last += 1;
                if (ringIndex == threshold_4) last += 1;

                if (first_assignable > breakpoint) {
                    // update current ring
                    first_assignable_ring += 1;
                    breakpoint += first_assignable_ring * 4;
                }
            }
            first_assignable = first;
            last_assignable = last;
            //TODO calculate last assignable
        }
    }

    function finish() public {
        require(status == Status.Started, "Board must be started in order to be finished");
        status = Status.Finished;
    }

    function _getMyIndex() private view returns (uint256) {
        for (uint i = first_assignable; i <= last_assignable;) {
            if (drawings[i].owner == msg.sender)
                return i;
        unchecked {i += 1;}
        }
        return 0; // TODO throw error or something
    }

    function _isAssignable(Drawing storage drawing) private view returns (bool) {
        return drawing.owner == address(0x0) || (_hasExpired(drawing.timestamp) && _isEmptyDrawingStorage(drawing.image));
    }

    function _hasExpired(uint256 timestamp) private view returns (bool) {
        return timestamp + EXPIRATION_TIME < block.timestamp;
    }

    function _isEmptyDrawing(uint256[16] calldata drawing) private pure returns (bool) {
        for (uint i = 0; i < 16;) {
            if (drawing[i] > 0)
                return false;
        unchecked {i += 1;}
        }
        return true;
    }

    function _isEmptyDrawingStorage(uint256[16] storage drawing) private view returns (bool) {
        for (uint i = 0; i < 16;) {
            if (drawing[i] > 0)
                return false;
        unchecked {i += 1;}
        }
        return true;
    }

    function _getNeighbors(uint256 index) private view returns (uint256[16][4] memory) {
        uint256[16][4] memory result;
        if (index == 0) return result;
        uint256 ringIndex = index;

        uint256 ring = 1;
        while (ringIndex > ring * 4) {
            ringIndex -= ring * 4;
            ring++;
        }
        ringIndex--;
        uint256 lineIndex = ringIndex % ring;

        uint256 threshold_1 = ring;
        uint256 threshold_2 = ring * 2;
        uint256 threshold_3 = ring * 3;

        uint256 side = ringIndex < threshold_1 ? 0 : ringIndex < threshold_2 ? 1 : ringIndex < threshold_3 ? 2 : 3;

        // ring 1 is a special case for some reason
        uint256 primaryValue = index - side - (ring == 1 ? 1 : (ring - 1) * 4);

        uint256 magic = (side + 2) % 4;

        if (lineIndex == 0)
            result[magic] = drawings[primaryValue].image;
        else {
            bool isLastRingIndex = ringIndex == (ring * 4) - 1;
            result[(magic + 1) % 4] = drawings[primaryValue - 1].image;
            result[magic] = drawings[primaryValue - (isLastRingIndex ? (ring - 1) * 4 : 0)].image;
        }

        return result;
    }
}
