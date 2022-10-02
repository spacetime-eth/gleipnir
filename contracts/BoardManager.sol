// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "hardhat/console.sol";

contract BoardManager {
    enum Status {
        Idle,
        Started,
        Finished
    }
    string constant ERROR_NOT_IDLE = "Board must be idle";
    string constant ERROR_NOT_STARTED = "Board must be started";
    string constant ERROR_MAX_CONCURRENCY = "Max concurrency reached";

    uint256 constant CHUNK_AMOUNT = 16;
    mapping(uint => uint256) drawings_info;
    mapping(uint => uint256[CHUNK_AMOUNT]) drawings_images;
    uint256 iterationData;
    uint256 constant EXPIRATION_TIME = 1800; //TODO determine time limit

    Status status = Status.Idle;

    function start() public {
        require(status == Status.Idle, ERROR_NOT_IDLE);
        status = Status.Started;
    }


    function reserveCanvas() public {
        require(status == Status.Started, ERROR_NOT_STARTED);
        uint256 _iterationData = iterationData;
        uint256 _firstAssignable = uint256(uint64(_iterationData));
        uint256 _lastAssignable = uint256(uint64(_iterationData>>64));

        for (uint i = _firstAssignable; i <= _lastAssignable; i = unchecked_inc(i)) {
            if (_isAssignable(i)) {
                uint256 info = uint256(uint160(msg.sender));
                info |= block.timestamp<<160;
                drawings_info[i] = info;
                return;
            }
        }

        revert(ERROR_MAX_CONCURRENCY);
    }

    function getMyCanvas() view public returns (uint256[CHUNK_AMOUNT][4] memory) {
        require(status == Status.Started, ERROR_NOT_STARTED);
        uint256 currentIndex = _getMyIndex();
        (uint256[CHUNK_AMOUNT] memory me, uint256[CHUNK_AMOUNT][4] memory neighbors) = getCanvas(currentIndex);
        return neighbors;
    }

    function getCanvas(uint256 index) view public returns (uint256[CHUNK_AMOUNT] memory, uint256[CHUNK_AMOUNT][4] memory) {
        uint256[CHUNK_AMOUNT] memory drawing = drawings_images[index];
        uint256[CHUNK_AMOUNT][4] memory neighbors = _getNeighbors(index);

        return (drawing, neighbors);
    }

    function draw(uint256[CHUNK_AMOUNT] calldata drawing) public {
        require(status == Status.Started, ERROR_NOT_STARTED);
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
            uint256 _lastAssignable = uint256(uint64(_iterationData>>64));
            uint256 _ring = uint256(uint64(_iterationData>>128));
            uint256 _breakpoint = uint256(uint64(_iterationData>>192));
            do {
                // Update first and last assignable
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
            } while (!_isEmptyDrawingStorage(_firstAssignable));

            _iterationData = _firstAssignable;
            _iterationData |= _lastAssignable<<64;
            _iterationData |= _ring<<128;
            _iterationData |= _breakpoint<<192;
            iterationData = _iterationData;
        }
    }

    function finish() public {
        require(status == Status.Started, ERROR_NOT_STARTED);
        status = Status.Finished;
    }

    //TODO check if should be merged with _getMyIndex
    function getMyCanvasIndex() public view returns (uint256) {
        return _getMyIndex();
    }

    function _getMyIndex() private view returns (uint256) {
        uint256 _iterationData = iterationData;
        uint256 _firstAssignable = uint256(uint64(_iterationData));
        uint256 _lastAssignable = uint256(uint64(_iterationData>>64));

        for (uint i = _firstAssignable; i <= _lastAssignable; i = unchecked_inc(i))
            if (address(uint160(drawings_info[i])) == msg.sender && _isEmptyDrawingStorage(i))
                return i;
        return 0; // TODO throw error or something
    }

    function unchecked_inc(uint256 i) private pure returns(uint256) { unchecked { return i + 1; } }

    function _isAssignable(uint256 i) private view returns (bool) {
        uint256 info = drawings_info[i];
        address owner = address(uint160(info));
        if (owner == address(0x0)) return true;
        if (!_isEmptyDrawingStorage(i)) return false;
        uint256 timestamp = uint256(uint40(info>>160));
        return _hasExpired(timestamp) || msg.sender == owner;
    }

    function _hasExpired(uint256 timestamp) private view returns (bool) {
        return timestamp + EXPIRATION_TIME < block.timestamp;
    }

    function _isEmptyDrawing(uint256[CHUNK_AMOUNT] calldata drawing) private pure returns (bool) {
        for (uint i = 0; i < CHUNK_AMOUNT; i = unchecked_inc(i))
            if (drawing[i] == 0)
                return true;
        return false;
    }

    function _isEmptyDrawingStorage(uint256 index) private view returns (bool) {
        return drawings_images[index][0] == 0;
    }

    function _getNeighbors(uint256 index) private view returns (uint256[CHUNK_AMOUNT][4] memory) {
        uint256[CHUNK_AMOUNT][4] memory result;
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
