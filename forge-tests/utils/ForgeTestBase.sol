// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface Vm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }

    function warp(uint256) external;
    function roll(uint256) external;
    function prank(address) external;
    function prank(address, address) external;
    function startPrank(address) external;
    function startPrank(address, address) external;
    function stopPrank() external;
    function expectRevert(bytes calldata) external;
    function expectRevert(bytes4) external;
    function expectRevert() external;
    function store(address, bytes32, bytes32) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
    function addr(uint256) external returns (address);
    function createFork(string calldata) external returns (uint256);
    function selectFork(uint256) external;
    function envString(string calldata) external returns (string memory);
    function load(address, bytes32) external returns (bytes32);
}

abstract contract ForgeTestBase {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function assertEq(uint256 a, uint256 b, string memory err) internal pure {
        require(a == b, err);
    }

    function assertEq(uint256 a, uint256 b) internal pure {
        require(a == b, "assertEq failed");
    }

    function assertEq(bool a, bool b, string memory err) internal pure {
        require(a == b, err);
    }

    function assertEq(address a, address b, string memory err) internal pure {
        require(a == b, err);
    }

    function assertEq(address a, address b) internal pure {
        require(a == b, "assertEq failed");
    }

    function assertTrue(bool condition, string memory err) internal pure {
        require(condition, err);
    }

    function assertGt(uint256 a, uint256 b, string memory err) internal pure {
        require(a > b, err);
    }

    function assertApproxEqAbs(uint256 a, uint256 b, uint256 tolerance, string memory err) internal pure {
        if (a > b) {
            require(a - b <= tolerance, err);
        } else {
            require(b - a <= tolerance, err);
        }
    }

    function assertApproxEqAbs(uint256 a, uint256 b, uint256 tolerance) internal pure {
        assertApproxEqAbs(a, b, tolerance, "assertApproxEqAbs failed");
    }
}
