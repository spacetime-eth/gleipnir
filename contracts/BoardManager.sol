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

    mapping(uint => uint256) drawings_info;
    mapping(uint => uint256[16]) drawings_images;
    uint256 iterationData;
    uint256 constant EXPIRATION_TIME = 1800; //TODO determine time limit

    Status status = Status.Idle;

    function start() public {
        require(status == Status.Idle, "Can't start an already started board");
        status = Status.Started;
    }

    function reserveCanvas() public {
        // TODO: check status?
        uint256 _iterationData = iterationData;
        uint256 _firstAssignable = uint256(uint64(_iterationData));
        uint256 _lastAssignable = uint256(uint64(_iterationData>>64));

        for (uint i = _firstAssignable; i <= _lastAssignable;) {
            if (_isAssignable(i)) {
                uint256 info = uint256(uint160(msg.sender));
                info |= block.timestamp<<160;
                drawings_info[i] = info;
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
        uint256 _iterationData = iterationData;
        if (_iterationData == 0) {
            // Handle first drawing special case
            _iterationData = 1;       //first
            _iterationData |= 4<<64;  //last
            _iterationData |= 1<<128; //ring
            _iterationData |= 4<<192; //breakpoint
            iterationData = _iterationData;
            return;
        }

        uint256 _firstAssignable = uint256(uint64(_iterationData));
        if (i == _firstAssignable) {
            // Update first and last assignable
            uint256 _lastAssignable = uint256(uint64(_iterationData>>64));
            uint256 _ring = uint256(uint64(_iterationData>>128));
            uint256 _breakpoint = uint256(uint64(_iterationData>>192));
            do {
                unchecked { _firstAssignable += 1; }
                unchecked { _lastAssignable += 1; }
                uint256 ringIndex;
                unchecked {ringIndex = _firstAssignable - (_breakpoint - _ring * 4) - 1; }

                if (ringIndex == _ring ||
                    ringIndex == _ring * 2 ||
                    ringIndex == _ring * 3) {
                    unchecked { _lastAssignable += 1; }
                }
                if (ringIndex == _ring * 4 - 1) {
                    unchecked { _lastAssignable += 1; }
                }

                if (_firstAssignable > _breakpoint) {
                    // update current ring
                    unchecked { _ring += 1; }
                    unchecked { _breakpoint += _ring * 4; }
                }
            } while (!_isEmptyDrawingStorage(drawings_images[_firstAssignable]));


            _iterationData = _firstAssignable;
            _iterationData |= _lastAssignable<<64;
            _iterationData |= _ring<<128;
            _iterationData |= _breakpoint<<192;
            iterationData = _iterationData;
        }
    }

    function finish() public {
        require(status == Status.Started, "Board must be started in order to be finished");
        status = Status.Finished;
    }

    function _getMyIndex() private view returns (uint256) {
        //mapping(uint256 => Drawing) memory _drawings_info = drawings_info;
        uint256 _iterationData = iterationData;
        uint256 _firstAssignable = uint256(uint64(_iterationData));
        uint256 _lastAssignable = uint256(uint64(_iterationData>>64));

        for (uint i = _firstAssignable; i <= _lastAssignable;) {
            if (address(uint160(drawings_info[i])) == msg.sender)
                return i;
            unchecked {i += 1;}
        }
        return 0; // TODO throw error or something
    }

    function _isAssignable(uint256 i) private view returns (bool) {
        uint256 info = drawings_info[i];
        address owner = address(uint160(info));
        if (owner == address(0x0)) return true;
        uint256 timestamp = uint256(uint40(info>>160));
        return _hasExpired(timestamp) && _isEmptyDrawingStorage(drawings_images[i]);
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

    //We may save 34k if we validate all sections separately instead of full drawing
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
