// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IUsageOracle
 * @notice Now has only getUsage(address user).
 */
interface IUsageOracle {
    /**
     * @notice Returns the total usage for a given user (all providers combined).
     * @param user The user address.
     * @return The total usage for the user.
     */
    function getUsage(address user) external view returns (uint256);
}

/**
 * @title Chainlink Functions Imports
 */
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

/**
 * @title KonduxOracle
 * @dev A Chainlink Functions-based oracle that implements the new single-argument IUsageOracle (per user).
 *
 * - We store total usage in usageByUser[user].
 * - We no longer track a provider dimension. The usage is presumably for "all providers" combined.
 * - We have a single request function, requestUsageForUser, which calls out to the Chainlink Functions DON
 *   to get the user's new usage value. Then we store it on-chain in usageByUser[user].
 */
contract KonduxOracle is FunctionsClient, ConfirmedOwner, IUsageOracle {
    using FunctionsRequest for FunctionsRequest.Request;

    // usageByUser[user] = total usage for that user
    mapping(address => uint256) public usageByUser;

    // Each request must store which user is being updated
    mapping(bytes32 => address) public requestIdToUser;

    // Events
    event RequestSent(bytes32 indexed requestId, address indexed user);
    event RequestFulfilled(bytes32 indexed requestId, bytes response, bytes err);
    event UsageUpdated(address indexed user, uint256 newUsage);

    // -------------------------------------------------------------------------
    // CONSTRUCTOR
    // -------------------------------------------------------------------------
    constructor(address functionsRouter)
        FunctionsClient(functionsRouter)
        ConfirmedOwner(msg.sender)
    {}

    // -------------------------------------------------------------------------
    // 1) REQUEST USAGE FROM OFF-CHAIN (CHAINLINK FUNCTIONS)
    // -------------------------------------------------------------------------
    /**
     * @notice Builds and sends a Chainlink Functions request to update usage for a user.
     * @param user The user address.
     * @param source Inline JavaScript source code that returns usage as a string (e.g. "123").
     * @param args Optional string arguments for the JS code.
     * @param bytesArgs Optional bytes arguments for the JS code.
     * @param secretsUrlsOrSlot Optional reference to secrets. (Encrypted or DON-hosted)
     * @param subscriptionId The subscription ID (Chainlink Functions).
     * @param gasLimit The maximum gas for the request fulfillment.
     * @param donId The DON ID (job ID) to run.
     */
    function requestUsageForUser(
        address user,
        string calldata source,
        string[] calldata args,
        bytes[] calldata bytesArgs,
        bytes memory secretsUrlsOrSlot, 
        uint64 subscriptionId,
        uint32 gasLimit,
        bytes32 donId
    ) external onlyOwner returns (bytes32 requestId) {
        require(user != address(0), "Invalid user");

        // Build the request
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source);

        if (secretsUrlsOrSlot.length > 0) {
            req.addSecretsReference(secretsUrlsOrSlot);
        }
        if (args.length > 0) {
            req.setArgs(args);
        }
        if (bytesArgs.length > 0) {
            req.setBytesArgs(bytesArgs);
        }

        // Send request
        requestId = _sendRequest(req.encodeCBOR(), subscriptionId, gasLimit, donId);

        // Map the request ID to the user
        requestIdToUser[requestId] = user;

        emit RequestSent(requestId, user);
        return requestId;
    }

    // -------------------------------------------------------------------------
    // 2) FULFILLMENT: Chainlink DON calls back here with the usage data
    // -------------------------------------------------------------------------
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        address user = requestIdToUser[requestId];
        if (user == address(0)) {
            revert("Unknown requestId");
        }

        // Optionally clear out the storage for that request ID
        delete requestIdToUser[requestId];

        emit RequestFulfilled(requestId, response, err);

        // If there's an error, revert
        if (err.length > 0) {
            revert(string(err));
        }

        // Parse usage from the response (ASCII digits => uint256)
        uint256 newUsage = _bytesToUint(response);

        // Update usageByUser
        usageByUser[user] = newUsage;

        emit UsageUpdated(user, newUsage);
    }

    // -------------------------------------------------------------------------
    // IUsageOracle Implementation
    // -------------------------------------------------------------------------
    /**
     * @notice Returns the total usage for a given user.
     */
    function getUsage(address user)
        external
        view
        override
        returns (uint256)
    {
        return usageByUser[user];
    }

    // -------------------------------------------------------------------------
    // HELPER to parse ASCII digits in `response` into a uint256
    // -------------------------------------------------------------------------
    function _bytesToUint(bytes memory b) internal pure returns (uint256) {
        uint256 number;
        for (uint i = 0; i < b.length; i++) {
            require(b[i] >= 0x30 && b[i] <= 0x39, "Non-digit in response");
            number = number * 10 + (uint8(b[i]) - 48);
        }
        return number;
    }
}
