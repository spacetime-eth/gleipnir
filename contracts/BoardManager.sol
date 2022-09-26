// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "hardhat/console.sol";

struct Drawing {
    address owner;
    uint48 timestamp;
}

contract BoardManager {
    enum Status {
        Idle,
        Started,
        Finished
    }

    uint256[16] NO_DRAWING;

    mapping(uint => Drawing) drawings_info;
    mapping(uint => uint256[16]) drawings_images;
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
        for (uint256 i = first_assignable; i <= last_assignable;) {
            if (_isAssignable(i)) {
                drawings_info[i] = Drawing(msg.sender, uint48(block.timestamp));
                return;
            }
            unchecked {i += 1;}
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
        uint256[16] memory drawing = drawings_images[index];
        uint256[16][4] memory neighbors = _getNeighbors(index);

        return (drawing, neighbors);
    }

    function draw(uint256[16] calldata drawing) public {
        require(status == Status.Started, "Board must be started before drawing");
        require(!_isEmptyDrawing(drawing), "Drawing shouldn't be empty");

        uint256 i = _getMyIndex();
        drawings_images[i] = drawing;

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
            do {
                first += 1;
                last += 1;
                uint256 ringIndex = first - (breakpoint - first_assignable_ring * 4) - 1;

                if (ringIndex == first_assignable_ring ||
                    ringIndex == first_assignable_ring * 2 ||
                    ringIndex == first_assignable_ring * 3) last += 1;
                if (ringIndex == first_assignable_ring * 4 - 1) last += 1;

                if (first_assignable > breakpoint) {
                    // update current ring
                    first_assignable_ring += 1;
                    breakpoint += first_assignable_ring * 4;
                }
            } while (!_isEmptyDrawingStorage(drawings_images[first]));

            first_assignable = first;
            last_assignable = last;
        }
    }

    function finish() public {
        require(status == Status.Started, "Board must be started in order to be finished");
        status = Status.Finished;
    }

    function _getMyIndex() private view returns (uint256) {
        for (uint i = first_assignable; i <= last_assignable;) {
            if (drawings_info[i].owner == msg.sender)
                return i;
            unchecked {i += 1;}
        }
        return 0; // TODO throw error or something
    }

    function _isAssignable(uint256 i) private view returns (bool) {
        return drawings_info[i].owner == address(0x0) ||
            (_hasExpired(drawings_info[i].timestamp) && _isEmptyDrawingStorage(drawings_images[i]));
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
            result[magic] = drawings_images[primaryValue];
        else {
            bool isLastRingIndex = ringIndex == (ring * 4) - 1;
            result[(magic + 1) % 4] = drawings_images[primaryValue - 1];
            result[magic] = drawings_images[primaryValue - (isLastRingIndex ? (ring - 1) * 4 : 0)];
        }

        return result;
    }
}
