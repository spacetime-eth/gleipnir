// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;


struct Drawing {
    address owner;
    uint256 timestamp;
    uint256[16] image;
}

contract BoardManager {
    uint256[16] NO_DRAWING;

    mapping(uint => Drawing) drawings;
    uint256 first_assignable;
    uint256 last_assignable;
    uint256 ring;
    uint256 breakpoint;
    uint256 EXPIRATION_TIME = 1800;//TODO investigar tolerancia

    function reserveCanvas() public {
        for (uint i = first_assignable; i <= last_assignable; i++) {
            if (isAssignable(drawings[i])) {
                drawings[i] = Drawing(msg.sender, block.timestamp, NO_DRAWING);
                return;
            }
        }
        //TODO ERROR, NO PLACE FOR A NEW ONE
    }

    function getMyCanvas() view public returns (uint256[16] memory) {
        for (uint i = first_assignable; i <= last_assignable; i++) {
            if (drawings[i].owner == msg.sender) {
                return drawings[i].image;
            }
        }
        return NO_DRAWING;//TODO maybe fail instead?
    }

    function getCanvas() view public returns (uint256[16][4] memory) {
        uint256[16] memory last = NO_DRAWING;
        uint256[16][4] memory result = [NO_DRAWING, NO_DRAWING, NO_DRAWING, last];
        return result;
    }

    function draw(uint256[16] calldata drawing) public {
        require(!isEmptyDrawing(drawing), "Drawing shouldn't be empty");

        uint256 i = getMyIndex();

        drawings[i].image = drawing;

        if (i == first_assignable) {
            uint256 first = first_assignable;
            uint256 last = last_assignable;
            while (!isEmptyDrawingStorage(drawings[first].image)) {
                first += 1;
                last += 1;
                uint256 ringIndex = first - breakpoint - 1;

                uint256 threshold_1 = ringIndex;
                uint256 threshold_2 = ringIndex * 2;
                uint256 threshold_3 = ringIndex * 3;
                uint256 threshold_4 = ringIndex * 4 - 1;

                if (first == threshold_1) last += 1;
                if (first == threshold_2) last += 1;
                if (first == threshold_3) last += 1;
                if (first == threshold_4) last += 1;

                if (first_assignable > breakpoint) {
                    // update current ring
                    ring += 1;
                    breakpoint += ring * 4;
                }
            }
            first_assignable = first;
            last_assignable = last;
            //TODO calculate last assignable
        }
    }

    function getMyIndex() private view returns(uint256) {
        for (uint i = first_assignable; i <= last_assignable; i++) {
            if (drawings[i].owner == msg.sender)
                return i;
            unchecked { i += 1; }
        }
        return 0; //TODO throw error or something
    }

    function isAssignable(Drawing storage drawing) private view returns(bool) {
        return drawing.owner == address(0x0) || (hasExpired(drawing.timestamp) && isEmptyDrawingStorage(drawing.image)); 
    }

    function hasExpired(uint256 timestamp) private view returns(bool) {
        return timestamp + EXPIRATION_TIME < block.timestamp;
    }

    function isEmptyDrawing(uint256[16] calldata drawing) private pure returns(bool) {
        for (uint i = 0; i < 16;) {
            if (drawing[i] > 0)
                return false;
            unchecked { i += 1; }
        }
        return true;
    }

    function isEmptyDrawingStorage(uint256[16] storage drawing) private view returns(bool) {
        for (uint i = 0; i < 16;) {
            if (drawing[i] > 0)
                return false;
            unchecked { i += 1; }
        }
        return true;
    }
}