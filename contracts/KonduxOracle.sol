// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IUsageOracle
 * @notice This interface requires the oracle to return total usage for a user+provider pair.
 */
interface IUsageOracle {
    /**
     * @notice Returns the total usage for a given user and provider.
     * @param provider The provider address.
     * @param user The user address.
     * @return The total usage for the user and provider.
     */
    function getUsage(address provider, address user) external view returns (uint256);
}

/**
 * @title Chainlink Functions Imports
 */
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

/**
 * @title KonduxOracle
 * @dev A Chainlink Functions-based oracle that implements the IUsageOracle interface.
 *
 * It stores usage in a double-mapping: usageByProviderUser[provider][user].
 * When you want to update usage for (provider,user), you call `requestUsageFor()`.
 * After the DON calls `fulfillRequest` with the new usage, it is stored on-chain.
 * KonduxTieredPayments can then call getUsage(provider,user) to retrieve it.
 */
contract KonduxOracle is FunctionsClient, ConfirmedOwner, IUsageOracle {
    using FunctionsRequest for FunctionsRequest.Request;

    // Maps (provider => (user => usageValue))
    mapping(address => mapping(address => uint256)) public usageByProviderUser;

    // Each request must store which (provider, user) it is updating
    struct ProviderUserPair {
        address provider;
        address user;
    }

    // Track which (provider,user) each request ID corresponds to
    mapping(bytes32 => ProviderUserPair) public requestIdToProviderUser;

    // We no longer store lastResponse / lastError in contract storage
    // to reduce local variable usage in fulfillRequest. If you want them,
    // you can re-add them carefully or rely on events.

    // For reference / debugging:
    // bytes32 public lastRequestId;

    // --------- EVENTS ---------
    event RequestSent(bytes32 indexed requestId, address indexed provider, address indexed user);
    event RequestFulfilled(bytes32 indexed requestId, bytes response, bytes err);
    event UsageUpdated(address indexed provider, address indexed user, uint256 newUsage);

    // --------- CONSTRUCTOR ---------
    /**
     * @param functionsRouter The address of the Chainlink Functions Router (see Chainlink docs).
     */
    constructor(address functionsRouter)
        FunctionsClient(functionsRouter)
        ConfirmedOwner(msg.sender)
    {}

    // -------------------------------------------------------------------------
    // 1) REQUEST USAGE FROM OFF-CHAIN (CHAINLINK FUNCTIONS)
    // -------------------------------------------------------------------------
    /**
     * @notice Builds and sends a Chainlink Functions request to update usage for (provider,user).
     * @param _provider The provider address.
     * @param _user The user address.
     * @param source JavaScript source code that returns usage as a string (e.g. "123").
     * @param args String arguments (if needed).
     * @param bytesArgs Bytes arguments (if needed).
     * @param secretsUrlsOrSlot If you're using encrypted or DON-hosted secrets, pass them here.
     * @param subscriptionId The subscription ID used to pay for Chainlink Functions calls.
     * @param gasLimit The maximum gas for the request fulfillment.
     * @param donId The DON ID (job ID) to run.
     * @return requestId The Chainlink Functions request ID.
     */
    function requestUsageFor(
        address _provider,
        address _user,
        string calldata source,
        string[] calldata args,
        bytes[] calldata bytesArgs,
        bytes memory secretsUrlsOrSlot, 
        uint64 subscriptionId,
        uint32 gasLimit,
        bytes32 donId
    ) external onlyOwner returns (bytes32 requestId) {
        require(_provider != address(0), "Invalid provider"); 
        require(_user != address(0), "Invalid user");

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

        requestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donId
        );

        requestIdToProviderUser[requestId] = ProviderUserPair({
            provider: _provider,
            user: _user
        });

        emit RequestSent(requestId, _provider, _user);

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
        ProviderUserPair memory pair = requestIdToProviderUser[requestId];
        if (pair.provider == address(0) || pair.user == address(0)) {
            revert("Unknown requestId");
        }

        // Clear out the storage for that request ID if you want to
        delete requestIdToProviderUser[requestId];

        emit RequestFulfilled(requestId, response, err);

        // If there's an error, revert
        if (err.length > 0) {
            revert(string(err));
        }

        // No local variable "newUsage" needed; parse and store directly
        usageByProviderUser[pair.provider][pair.user] = _bytesToUint(response);

        emit UsageUpdated(
            pair.provider,
            pair.user,
            usageByProviderUser[pair.provider][pair.user]
        );
    }

    // -------------------------------------------------------------------------
    // IUsageOracle Implementation
    // -------------------------------------------------------------------------
    /**
     * @notice Returns the total usage for (provider, user) as stored on-chain.
     */
    function getUsage(address provider, address user)
        external
        view
        override
        returns (uint256)
    {
        return usageByProviderUser[provider][user];
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
