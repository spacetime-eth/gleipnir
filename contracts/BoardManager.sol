// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "hardhat/console.sol";

contract BoardManager {
    enum Status {
        Started,
        Finished
    }
    string constant ERROR_NOT_STARTED = "Board must be started";
    string constant ERROR_MAX_CONCURRENCY = "Max concurrency reached";
    string constant ERROR_NOT_RESERVED = "Need to reserve first";

    mapping(uint => uint256) canvases_info;
    mapping(uint => uint256) canvases;
    uint256 iteration_data;
    uint256 constant EXPIRATION_TIME = 1800; //TODO determine time limit

    Status status = Status.Started;

    function reserveCanvas() public {
        require(status == Status.Started, ERROR_NOT_STARTED);
        uint256 _iteration_data = iteration_data;
        uint256 _firstAssignable = uint256(uint64(_iteration_data));
        uint256 _lastAssignable = uint256(uint64(_iteration_data>>64));

        for (uint i = _firstAssignable; i <= _lastAssignable; i = unchecked_inc(i)) {
            if (_isAssignable(i)) {
                uint256 info = uint256(uint160(msg.sender));
                info |= block.timestamp<<160;
                canvases_info[i] = info;
                return;
            }
        }

        revert(ERROR_MAX_CONCURRENCY);
    }

    function getMyNeighbors() view public returns (uint256[4] memory) {
        require(status == Status.Started, ERROR_NOT_STARTED);
        uint256 currentIndex = getMyCanvasIndex();
        return _getNeighbors(currentIndex);
    }

    function getCanvas(uint256 index) view public returns (uint256) {
        return canvases[index];
    }

    function draw(uint256 drawing) public {
        require(status == Status.Started, ERROR_NOT_STARTED);
        require(drawing != 0, "Drawing shouldn't be empty");

        uint256 i = _getMyIndex();
        canvases[i] = drawing;
        uint256 _iteration_data = iteration_data;
        if (_iteration_data == 0) {
            // Handle first drawing special case
            _iteration_data = 1;       //first
            _iteration_data |= 4<<64;  //last
            _iteration_data |= 1<<128; //ring
            _iteration_data |= 4<<192; //breakpoint
            iteration_data = _iteration_data;
            return;
        }

        uint256 _firstAssignable = uint256(uint64(_iteration_data));
        if (i == _firstAssignable) {
            uint256 _lastAssignable = uint256(uint64(_iteration_data>>64));
            uint256 _ring = uint256(uint64(_iteration_data>>128));
            uint256 _breakpoint = uint256(uint64(_iteration_data>>192));
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

            _iteration_data = _firstAssignable;
            _iteration_data |= _lastAssignable<<64;
            _iteration_data |= _ring<<128;
            _iteration_data |= _breakpoint<<192;
            iteration_data = _iteration_data;
        }
    }

    function finish() public {
        require(status == Status.Started, ERROR_NOT_STARTED);
        status = Status.Finished;
    }

    function getMyCanvasIndex() public view returns (uint256) {
        return _getMyIndex();
    }

    function _getMyIndex() private view returns (uint256) {
        uint256 _iteration_data = iteration_data;
        uint256 _firstAssignable = uint256(uint64(_iteration_data));
        uint256 _lastAssignable = uint256(uint64(_iteration_data>>64));

        for (uint i = _firstAssignable; i <= _lastAssignable; i = unchecked_inc(i))
            if (address(uint160(canvases_info[i])) == msg.sender && _isEmptyDrawingStorage(i))
                return i;
        revert(ERROR_NOT_RESERVED);
    }

    function unchecked_inc(uint256 i) private pure returns(uint256) { unchecked { return i + 1; } }

    function _isAssignable(uint256 i) private view returns (bool) {
        uint256 info = canvases_info[i];
        address owner = address(uint160(info));
        if (owner == address(0x0)) return true;
        if (!_isEmptyDrawingStorage(i)) return false;
        uint256 timestamp = uint256(uint40(info>>160));
        return _hasExpired(timestamp) || msg.sender == owner;
    }

    function _hasExpired(uint256 timestamp) private view returns (bool) {
        return timestamp + EXPIRATION_TIME < block.timestamp;
    }

    function _isEmptyDrawing(uint256 drawing) private pure returns (bool) {
        return drawing == 0;
    }

    function _isEmptyDrawingStorage(uint256 index) private view returns (bool) {
        return canvases[index] == 0;
    }

    function _getNeighbors(uint256 index) private view returns (uint256[4] memory) {
        uint256[4] memory result;
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

        // ring 1 is a special case
        uint256 primaryValue = index - side - (ring == 1 ? 1 : (ring - 1) * 4);

        uint256 magic = (side + 2) % 4;

        if (lineIndex == 0)
            result[magic] = canvases[primaryValue];
        else {
            bool isLastRingIndex = ringIndex == (ring * 4) - 1;
            result[(magic + 1) % 4] = canvases[primaryValue - 1];
            result[magic] = canvases[primaryValue - (isLastRingIndex ? (ring - 1) * 4 : 0)];
        }

        return result;
    }
}
