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
    uint256 constant EXPIRATION_TIME = 1800;

    Status status = Status.Started;

    constructor(uint256 seed) {
        _setCanvasInfo(0);
        _setIterationData(1, 4, 1, 4);
        canvases[0] = seed;
    }

    function reserveCanvas() public {
        require(status == Status.Started, ERROR_NOT_STARTED);
        uint256 _iteration_data = iteration_data;
        uint256 _firstAssignable = uint256(uint64(_iteration_data));
        uint256 _lastAssignable = uint256(uint64(_iteration_data>>64));

        for (uint i = _firstAssignable; i <= _lastAssignable; i = unchecked_inc(i)) {
            if (_isAssignable(i)) {
                _setCanvasInfo(i);
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
        uint256 _firstAssignable = uint256(uint64(_iteration_data));
        if (i == _firstAssignable) {
            uint256 _lastAssignable = uint256(uint64(_iteration_data>>64));
            uint256 _ring = uint256(uint64(_iteration_data>>128));
            uint256 _breakpoint = uint256(uint64(_iteration_data>>192));
            do {
                // Update first and last assignable
                unchecked { _firstAssignable += 1; }
                unchecked { _lastAssignable += 1; }

                uint256 ringSize;
                unchecked { ringSize = _ring * 4; }
                uint256 ringIndex;
                unchecked { ringIndex = _firstAssignable - (_breakpoint - ringSize) - 1; }

                if (ringIndex == 0) continue;

                bool turn = ringIndex % _ring == 0;
                if (turn) {
                    unchecked { _lastAssignable += 1; }
                }

                if (ringIndex == ringSize - 1) {
                    unchecked { _lastAssignable += 1; }
                }

                if (_firstAssignable > _breakpoint) {
                    // update current ring
                    unchecked { _ring += 1; }
                    unchecked { _breakpoint += ringSize; }
                }
            } while (!_isEmptyDrawingStorage(_firstAssignable));

            _setIterationData(_firstAssignable, _lastAssignable, _ring, _breakpoint);
        }
    }

    function finish() public {
        require(status == Status.Started, ERROR_NOT_STARTED);
        status = Status.Finished;
    }

    function getMyCanvasIndex() public view returns (uint256) {
        return _getMyIndex();
    }

    function _setCanvasInfo(uint256 i) private {
        canvases_info[i] = uint256(uint160(msg.sender)) | block.timestamp<<160;
    }

    function _setIterationData(uint256 first, uint256 last, uint256 ring, uint256 breakpoint) private {
        iteration_data = first | last<<64 | ring<<128 | breakpoint<<192;
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

    function unchecked_inc(uint256 i) private pure returns(uint256) { unchecked { return i + 1; } }
}
