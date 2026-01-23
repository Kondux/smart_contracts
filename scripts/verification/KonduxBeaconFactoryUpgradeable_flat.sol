// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.11 >=0.4.16 >=0.6.2 >=0.8.4 ^0.8.20 ^0.8.21 ^0.8.22 ^0.8.30;

// node_modules/@openzeppelin/contracts/utils/Context.sol

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// node_modules/@openzeppelin/contracts/utils/Errors.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/Errors.sol)

/**
 * @dev Collection of common custom errors used in multiple contracts
 *
 * IMPORTANT: Backwards compatibility is not guaranteed in future versions of the library.
 * It is recommended to avoid relying on the error API for critical functionality.
 *
 * _Available since v5.1._
 */
library Errors {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error InsufficientBalance(uint256 balance, uint256 needed);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedCall();

    /**
     * @dev The deployment failed.
     */
    error FailedDeployment();

    /**
     * @dev A necessary precompile is missing.
     */
    error MissingPrecompile(address);
}

// node_modules/@openzeppelin/contracts/access/IAccessControl.sol

// OpenZeppelin Contracts (last updated v5.4.0) (access/IAccessControl.sol)

/**
 * @dev External interface of AccessControl declared to support ERC-165 detection.
 */
interface IAccessControl {
    /**
     * @dev The `account` is missing a role.
     */
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    /**
     * @dev The caller of a function is not the expected one.
     *
     * NOTE: Don't confuse with {AccessControlUnauthorizedAccount}.
     */
    error AccessControlBadConfirmation();

    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted to signal this.
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call. This account bears the admin role (for the granted role).
     * Expected in cases where the role was granted using the internal {AccessControl-_grantRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     */
    function renounceRole(bytes32 role, address callerConfirmation) external;
}

// node_modules/@openzeppelin/contracts/proxy/beacon/IBeacon.sol

// OpenZeppelin Contracts (last updated v5.4.0) (proxy/beacon/IBeacon.sol)

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {UpgradeableBeacon} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// node_modules/@openzeppelin/contracts/utils/introspection/IERC165.sol

// OpenZeppelin Contracts (last updated v5.4.0) (utils/introspection/IERC165.sol)

/**
 * @dev Interface of the ERC-165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[ERC].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// node_modules/@openzeppelin/contracts/interfaces/IERC1967.sol

// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC1967.sol)

/**
 * @dev ERC-1967: Proxy Storage Slots. This interface contains the events defined in the ERC.
 */
interface IERC1967 {
    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Emitted when the beacon is changed.
     */
    event BeaconUpgraded(address indexed beacon);
}

// node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// contracts/interfaces/IKonduxRoyaltySplitter.sol

/**
 * @title IKonduxRoyaltySplitter
 * @notice Interface for the Kondux royalty splitter contract
 */
interface IKonduxRoyaltySplitter {
    /*//////////////////////////////////////////////////////////////
                            ROLE CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the ADMIN_ROLE identifier
    function ADMIN_ROLE() external view returns (bytes32);

    /// @notice Returns the DISTRIBUTOR_ROLE identifier
    function DISTRIBUTOR_ROLE() external view returns (bytes32);

    /// @notice Returns the COLLECTION_ROLE identifier
    function COLLECTION_ROLE() external view returns (bytes32);

    /// @notice Returns the FEE_ADMIN_ROLE identifier
    function FEE_ADMIN_ROLE() external view returns (bytes32);

    /*//////////////////////////////////////////////////////////////
                         ROLE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Grant a role to an account
    function grantRole(bytes32 role, address account) external;

    /// @notice Revoke a role from an account
    function revokeRole(bytes32 role, address account) external;

    /// @notice Check if an account has a role
    function hasRole(bytes32 role, address account) external view returns (bool);
    /**
     * @notice Called by the NFT contract during a transfer to atomically distribute royalties
     * @param tokenId The token being transferred
     * @param from The seller
     * @param salePrice The sale price
     */
    function onTransferWithValue(
        uint256 tokenId,
        address from,
        uint256 salePrice
    ) external payable;

    /**
     * @notice Register a pending sale for atomic distribution
     * @param tokenId The token about to be sold
     * @return saleId A unique identifier for this sale
     */
    function registerSale(uint256 tokenId) external returns (bytes32 saleId);

    /**
     * @notice Receive payment for a specific sale and distribute immediately
     * @param saleId The unique sale identifier from registerSale()
     */
    function receivePaymentForSale(bytes32 saleId) external payable;

    /**
     * @notice Receive payment with tokenId directly specified
     * @param tokenId The token that was sold
     */
    function receivePaymentForToken(uint256 tokenId) external payable;

    /**
     * @notice Register creator info for a token
     * @param tokenId The token ID
     * @param creator The creator's address
     * @param creatorCutBP The creator's royalty cut in basis points
     */
    function registerCreator(
        uint256 tokenId,
        address creator,
        uint96 creatorCutBP
    ) external;

    /**
     * @notice Batch register creators
     */
    function registerCreatorsBatch(
        uint256[] calldata tokenIds,
        address[] calldata creators,
        uint96[] calldata creatorCutsBP
    ) external;

    /**
     * @notice Get the split breakdown for a token
     */
    function getSplit(uint256 tokenId, uint256 amount) 
        external 
        view 
        returns (
            uint256 manufacturerAmount,
            uint256 partnerAmount,
            uint256 creatorAmount,
            address creator,
            uint96 creatorCutBP
        );

    /**
     * @notice Get creator info for a token
     */
    function getCreatorInfo(uint256 tokenId)
        external
        view
        returns (address creator, uint96 cutBP);

    /**
     * @notice Check if a token has creator info registered
     */
    function hasCreatorInfo(uint256 tokenId) external view returns (bool);

    /**
     * @notice Get pending ETH for an address
     */
    function getPendingETH(address recipient) external view returns (uint256);

    /**
     * @notice Withdraw accumulated ETH
     */
    function withdrawETH() external;

    /**
     * @notice Withdraw accumulated ERC20 tokens
     */
    function withdrawERC20(address token) external;

    /*//////////////////////////////////////////////////////////////
                         ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Enable or disable push (immediate) distribution mode
     */
    function setPushMode(bool enabled) external;

    /**
     * @notice Update wallet addresses
     */
    function setWallets(address manufacturerWallet, address partnerWallet) external;

    /**
     * @notice Update cut percentages
     */
    function setCuts(
        uint96 manufacturerCutBP,
        uint96 partnerCutBP,
        uint96 defaultCreatorCutBP
    ) external;

    /**
     * @notice Allows a registered creator to change their own receiving wallet
     * @param tokenId The token ID for which they are the creator
     * @param newWallet The new wallet address to receive royalties
     */
    function updateCreatorWallet(uint256 tokenId, address newWallet) external;

    /**
     * @notice Admin/Distributor can override creator registration
     * @param tokenId The token ID
     * @param creator The new creator address
     * @param creatorCutBP The creator's royalty cut in basis points
     */
    function overrideCreator(
        uint256 tokenId,
        address creator,
        uint96 creatorCutBP
    ) external;

    /**
     * @notice Set the collection address (can only be called once if initially zero)
     * @dev Used by factory to set collection after deployment in splitter-first pattern
     * @param _collection The NFT collection address
     */
    function setCollection(address _collection) external;
}

// node_modules/@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol

// OpenZeppelin Contracts (last updated v5.3.0) (proxy/utils/Initializable.sol)

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Storage of the initializable contract.
     *
     * It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions
     * when using with upgradeable contracts.
     *
     * @custom:storage-location erc7201:openzeppelin.storage.Initializable
     */
    struct InitializableStorage {
        /**
         * @dev Indicates that the contract has been initialized.
         */
        uint64 _initialized;
        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool _initializing;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    /**
     * @dev The contract is already initialized.
     */
    error InvalidInitialization();

    /**
     * @dev The contract is not initializing.
     */
    error NotInitializing();

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint64 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that in the context of a constructor an `initializer` may be invoked any
     * number of times. This behavior in the constructor can be useful during testing and is not expected to be used in
     * production.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        // Cache values to avoid duplicated sloads
        bool isTopLevelCall = !$._initializing;
        uint64 initialized = $._initialized;

        // Allowed calls:
        // - initialSetup: the contract is not in the initializing state and no previous version was
        //                 initialized
        // - construction: the contract is initialized at version 1 (no reinitialization) and the
        //                 current contract is just being deployed
        bool initialSetup = initialized == 0 && isTopLevelCall;
        bool construction = initialized == 1 && address(this).code.length == 0;

        if (!initialSetup && !construction) {
            revert InvalidInitialization();
        }
        $._initialized = 1;
        if (isTopLevelCall) {
            $._initializing = true;
        }
        _;
        if (isTopLevelCall) {
            $._initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: Setting the version to 2**64 - 1 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint64 version) {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing || $._initialized >= version) {
            revert InvalidInitialization();
        }
        $._initialized = version;
        $._initializing = true;
        _;
        $._initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        _checkInitializing();
        _;
    }

    /**
     * @dev Reverts if the contract is not in an initializing state. See {onlyInitializing}.
     */
    function _checkInitializing() internal view virtual {
        if (!_isInitializing()) {
            revert NotInitializing();
        }
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing) {
            revert InvalidInitialization();
        }
        if ($._initialized != type(uint64).max) {
            $._initialized = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint64) {
        return _getInitializableStorage()._initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _getInitializableStorage()._initializing;
    }

    /**
     * @dev Pointer to storage slot. Allows integrators to override it with a custom storage location.
     *
     * NOTE: Consider following the ERC-7201 formula to derive storage locations.
     */
    function _initializableStorageSlot() internal pure virtual returns (bytes32) {
        return INITIALIZABLE_STORAGE;
    }

    /**
     * @dev Returns a pointer to the storage namespace.
     */
    // solhint-disable-next-line var-name-mixedcase
    function _getInitializableStorage() private pure returns (InitializableStorage storage $) {
        bytes32 slot = _initializableStorageSlot();
        assembly {
            $.slot := slot
        }
    }
}

// node_modules/@openzeppelin/contracts/proxy/Proxy.sol

// OpenZeppelin Contracts (last updated v5.0.0) (proxy/Proxy.sol)

/**
 * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM
 * instruction `delegatecall`. We refer to the second contract as the _implementation_ behind the proxy, and it has to
 * be specified by overriding the virtual {_implementation} function.
 *
 * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a
 * different contract through the {_delegate} function.
 *
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
abstract contract Proxy {
    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev This is a virtual function that should be overridden so it returns the address to which the fallback
     * function and {_fallback} should delegate.
     */
    function _implementation() internal view virtual returns (address);

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _fallback() internal virtual {
        _delegate(_implementation());
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable virtual {
        _fallback();
    }
}

// node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

// node_modules/@openzeppelin/contracts/utils/StorageSlot.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC-1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     // Define the slot. Alternatively, use the SlotDerivation library to derive the slot.
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(newImplementation.code.length > 0);
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * TIP: Consider using this library along with {SlotDerivation}.
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    struct Int256Slot {
        int256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Int256Slot` with member `value` located at `slot`.
     */
    function getInt256Slot(bytes32 slot) internal pure returns (Int256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns a `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }
}

// node_modules/@openzeppelin/contracts/interfaces/draft-IERC1822.sol

// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/draft-IERC1822.sol)

/**
 * @dev ERC-1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}

// node_modules/@openzeppelin/contracts/utils/Address.sol

// OpenZeppelin Contracts (last updated v5.4.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert Errors.InsufficientBalance(address(this).balance, amount);
        }

        (bool success, bytes memory returndata) = recipient.call{value: amount}("");
        if (!success) {
            _revert(returndata);
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {Errors.FailedCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert Errors.InsufficientBalance(address(this).balance, value);
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {Errors.FailedCall}) in case
     * of an unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {Errors.FailedCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {Errors.FailedCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            assembly ("memory-safe") {
                revert(add(returndata, 0x20), mload(returndata))
            }
        } else {
            revert Errors.FailedCall();
        }
    }
}

// node_modules/@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// node_modules/@openzeppelin/contracts/utils/introspection/ERC165.sol

// OpenZeppelin Contracts (last updated v5.4.0) (utils/introspection/ERC165.sol)

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC-165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 */
abstract contract ERC165 is IERC165 {
    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// node_modules/@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol

// OpenZeppelin Contracts (last updated v5.4.0) (access/extensions/IAccessControlEnumerable.sol)

/**
 * @dev External interface of AccessControlEnumerable declared to support ERC-165 detection.
 */
interface IAccessControlEnumerable is IAccessControl {
    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index) external view returns (address);

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
}

// node_modules/@openzeppelin/contracts/interfaces/IERC165.sol

// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC165.sol)

// node_modules/@openzeppelin/contracts/interfaces/IERC20.sol

// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC20.sol)

// node_modules/@openzeppelin/contracts/access/Ownable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// node_modules/@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol

// OpenZeppelin Contracts (last updated v5.4.0) (utils/introspection/ERC165.sol)

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC-165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 */
abstract contract ERC165Upgradeable is Initializable, IERC165 {
    function __ERC165_init() internal onlyInitializing {
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// node_modules/@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol

// OpenZeppelin Contracts (last updated v5.0.0) (proxy/beacon/UpgradeableBeacon.sol)

/**
 * @dev This contract is used in conjunction with one or more instances of {BeaconProxy} to determine their
 * implementation contract, which is where they will delegate all function calls.
 *
 * An owner is able to change the implementation the beacon points to, thus upgrading the proxies that use this beacon.
 */
contract UpgradeableBeacon is IBeacon, Ownable {
    address private _implementation;

    /**
     * @dev The `implementation` of the beacon is invalid.
     */
    error BeaconInvalidImplementation(address implementation);

    /**
     * @dev Emitted when the implementation returned by the beacon is changed.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Sets the address of the initial implementation, and the initial owner who can upgrade the beacon.
     */
    constructor(address implementation_, address initialOwner) Ownable(initialOwner) {
        _setImplementation(implementation_);
    }

    /**
     * @dev Returns the current implementation address.
     */
    function implementation() public view virtual returns (address) {
        return _implementation;
    }

    /**
     * @dev Upgrades the beacon to a new implementation.
     *
     * Emits an {Upgraded} event.
     *
     * Requirements:
     *
     * - msg.sender must be the owner of the contract.
     * - `newImplementation` must be a contract.
     */
    function upgradeTo(address newImplementation) public virtual onlyOwner {
        _setImplementation(newImplementation);
    }

    /**
     * @dev Sets the implementation contract address for this beacon
     *
     * Requirements:
     *
     * - `newImplementation` must be a contract.
     */
    function _setImplementation(address newImplementation) private {
        if (newImplementation.code.length == 0) {
            revert BeaconInvalidImplementation(newImplementation);
        }
        _implementation = newImplementation;
        emit Upgraded(newImplementation);
    }
}

// node_modules/@openzeppelin/contracts/access/AccessControl.sol

// OpenZeppelin Contracts (last updated v5.4.0) (access/AccessControl.sol)

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```solidity
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```solidity
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it. We recommend using {AccessControlDefaultAdminRules}
 * to enforce additional security measures for this role.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address account => bool) hasRole;
        bytes32 adminRole;
    }

    mapping(bytes32 role => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with an {AccessControlUnauthorizedAccount} error including the required role.
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual returns (bool) {
        return _roles[role].hasRole[account];
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `_msgSender()`
     * is missing `role`. Overriding this function changes the behavior of the {onlyRole} modifier.
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `account`
     * is missing `role`.
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert AccessControlUnauthorizedAccount(account, role);
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address callerConfirmation) public virtual {
        if (callerConfirmation != _msgSender()) {
            revert AccessControlBadConfirmation();
        }

        _revokeRole(role, callerConfirmation);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Attempts to grant `role` to `account` and returns a boolean indicating if `role` was granted.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual returns (bool) {
        if (!hasRole(role, account)) {
            _roles[role].hasRole[account] = true;
            emit RoleGranted(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Attempts to revoke `role` from `account` and returns a boolean indicating if `role` was revoked.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual returns (bool) {
        if (hasRole(role, account)) {
            _roles[role].hasRole[account] = false;
            emit RoleRevoked(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }
}

// node_modules/@openzeppelin/contracts/interfaces/IERC1363.sol

// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC1363.sol)

/**
 * @title IERC1363
 * @dev Interface of the ERC-1363 standard as defined in the https://eips.ethereum.org/EIPS/eip-1363[ERC-1363].
 *
 * Defines an extension interface for ERC-20 tokens that supports executing code on a recipient contract
 * after `transfer` or `transferFrom`, or code on a spender contract after `approve`, in a single transaction.
 */
interface IERC1363 is IERC20, IERC165 {
    /*
     * Note: the ERC-165 identifier for this interface is 0xb0202a11.
     * 0xb0202a11 ===
     *   bytes4(keccak256('transferAndCall(address,uint256)')) ^
     *   bytes4(keccak256('transferAndCall(address,uint256,bytes)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256,bytes)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256,bytes)'))
     */

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @param data Additional data with no specified format, sent in call to `spender`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);
}

// node_modules/@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol

// OpenZeppelin Contracts (last updated v5.4.0) (access/AccessControl.sol)

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```solidity
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```solidity
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it. We recommend using {AccessControlDefaultAdminRules}
 * to enforce additional security measures for this role.
 */
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable, IAccessControl, ERC165Upgradeable {
    struct RoleData {
        mapping(address account => bool) hasRole;
        bytes32 adminRole;
    }

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /// @custom:storage-location erc7201:openzeppelin.storage.AccessControl
    struct AccessControlStorage {
        mapping(bytes32 role => RoleData) _roles;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.AccessControl")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant AccessControlStorageLocation = 0x02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800;

    function _getAccessControlStorage() private pure returns (AccessControlStorage storage $) {
        assembly {
            $.slot := AccessControlStorageLocation
        }
    }

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with an {AccessControlUnauthorizedAccount} error including the required role.
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    function __AccessControl_init() internal onlyInitializing {
    }

    function __AccessControl_init_unchained() internal onlyInitializing {
    }
    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual returns (bool) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        return $._roles[role].hasRole[account];
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `_msgSender()`
     * is missing `role`. Overriding this function changes the behavior of the {onlyRole} modifier.
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `account`
     * is missing `role`.
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert AccessControlUnauthorizedAccount(account, role);
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual returns (bytes32) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        return $._roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address callerConfirmation) public virtual {
        if (callerConfirmation != _msgSender()) {
            revert AccessControlBadConfirmation();
        }

        _revokeRole(role, callerConfirmation);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        AccessControlStorage storage $ = _getAccessControlStorage();
        bytes32 previousAdminRole = getRoleAdmin(role);
        $._roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Attempts to grant `role` to `account` and returns a boolean indicating if `role` was granted.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual returns (bool) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        if (!hasRole(role, account)) {
            $._roles[role].hasRole[account] = true;
            emit RoleGranted(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Attempts to revoke `role` from `account` and returns a boolean indicating if `role` was revoked.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual returns (bool) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        if (hasRole(role, account)) {
            $._roles[role].hasRole[account] = false;
            emit RoleRevoked(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }
}

// node_modules/@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol

// OpenZeppelin Contracts (last updated v5.4.0) (proxy/ERC1967/ERC1967Utils.sol)

/**
 * @dev This library provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[ERC-1967] slots.
 */
library ERC1967Utils {
    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev The `implementation` of the proxy is invalid.
     */
    error ERC1967InvalidImplementation(address implementation);

    /**
     * @dev The `admin` of the proxy is invalid.
     */
    error ERC1967InvalidAdmin(address admin);

    /**
     * @dev The `beacon` of the proxy is invalid.
     */
    error ERC1967InvalidBeacon(address beacon);

    /**
     * @dev An upgrade function sees `msg.value > 0` that may be lost.
     */
    error ERC1967NonPayable();

    /**
     * @dev Returns the current implementation address.
     */
    function getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the ERC-1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        if (newImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(newImplementation);
        }
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Performs implementation upgrade with additional setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) internal {
        _setImplementation(newImplementation);
        emit IERC1967.Upgraded(newImplementation);

        if (data.length > 0) {
            Address.functionDelegateCall(newImplementation, data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Returns the current admin.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by ERC-1967) using
     * the https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`
     */
    function getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the ERC-1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        if (newAdmin == address(0)) {
            revert ERC1967InvalidAdmin(address(0));
        }
        StorageSlot.getAddressSlot(ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {IERC1967-AdminChanged} event.
     */
    function changeAdmin(address newAdmin) internal {
        emit IERC1967.AdminChanged(getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is the keccak-256 hash of "eip1967.proxy.beacon" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Returns the current beacon.
     */
    function getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the ERC-1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        if (newBeacon.code.length == 0) {
            revert ERC1967InvalidBeacon(newBeacon);
        }

        StorageSlot.getAddressSlot(BEACON_SLOT).value = newBeacon;

        address beaconImplementation = IBeacon(newBeacon).implementation();
        if (beaconImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(beaconImplementation);
        }
    }

    /**
     * @dev Change the beacon and trigger a setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-BeaconUpgraded} event.
     *
     * CAUTION: Invoking this function has no effect on an instance of {BeaconProxy} since v5, since
     * it uses an immutable beacon without looking at the value of the ERC-1967 beacon slot for
     * efficiency.
     */
    function upgradeBeaconToAndCall(address newBeacon, bytes memory data) internal {
        _setBeacon(newBeacon);
        emit IERC1967.BeaconUpgraded(newBeacon);

        if (data.length > 0) {
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Reverts if `msg.value` is not zero. It can be used to avoid `msg.value` stuck in the contract
     * if an upgrade doesn't perform an initialization call.
     */
    function _checkNonPayable() private {
        if (msg.value > 0) {
            revert ERC1967NonPayable();
        }
    }
}

// node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol

// OpenZeppelin Contracts (last updated v5.3.0) (token/ERC20/utils/SafeERC20.sol)

/**
 * @title SafeERC20
 * @dev Wrappers around ERC-20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    /**
     * @dev An operation with an ERC-20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Variant of {safeTransfer} that returns a bool instead of reverting if the operation is not successful.
     */
    function trySafeTransfer(IERC20 token, address to, uint256 value) internal returns (bool) {
        return _callOptionalReturnBool(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Variant of {safeTransferFrom} that returns a bool instead of reverting if the operation is not successful.
     */
    function trySafeTransferFrom(IERC20 token, address from, address to, uint256 value) internal returns (bool) {
        return _callOptionalReturnBool(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     *
     * NOTE: If the token implements ERC-7674, this function will not modify any temporary allowance. This function
     * only sets the "standard" allowance. Any temporary allowance will remain active, in addition to the value being
     * set here.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Performs an {ERC1363} transferAndCall, with a fallback to the simple {ERC20} transfer if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            safeTransfer(token, to, value);
        } else if (!token.transferAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} transferFromAndCall, with a fallback to the simple {ERC20} transferFrom if the target
     * has no code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferFromAndCallRelaxed(
        IERC1363 token,
        address from,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        if (to.code.length == 0) {
            safeTransferFrom(token, from, to, value);
        } else if (!token.transferFromAndCall(from, to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} approveAndCall, with a fallback to the simple {ERC20} approve if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * NOTE: When the recipient address (`to`) has no code (i.e. is an EOA), this function behaves as {forceApprove}.
     * Opposedly, when the recipient address (`to`) has code, this function only attempts to call {ERC1363-approveAndCall}
     * once without retrying, and relies on the returned value to be true.
     *
     * Reverts if the returned value is other than `true`.
     */
    function approveAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            forceApprove(token, to, value);
        } else if (!token.approveAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturnBool} that reverts if call fails to meet the requirements.
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            let success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            // bubble errors
            if iszero(success) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
            returnSize := returndatasize()
            returnValue := mload(0)
        }

        if (returnSize == 0 ? address(token).code.length == 0 : returnValue != 1) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silently catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        bool success;
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0)
        }
        return success && (returnSize == 0 ? address(token).code.length > 0 : returnValue == 1);
    }
}

// node_modules/@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol

// OpenZeppelin Contracts (last updated v5.2.0) (proxy/beacon/BeaconProxy.sol)

/**
 * @dev This contract implements a proxy that gets the implementation address for each call from an {UpgradeableBeacon}.
 *
 * The beacon address can only be set once during construction, and cannot be changed afterwards. It is stored in an
 * immutable variable to avoid unnecessary storage reads, and also in the beacon storage slot specified by
 * https://eips.ethereum.org/EIPS/eip-1967[ERC-1967] so that it can be accessed externally.
 *
 * CAUTION: Since the beacon address can never be changed, you must ensure that you either control the beacon, or trust
 * the beacon to not upgrade the implementation maliciously.
 *
 * IMPORTANT: Do not use the implementation logic to modify the beacon storage slot. Doing so would leave the proxy in
 * an inconsistent state where the beacon storage slot does not match the beacon address.
 */
contract BeaconProxy is Proxy {
    // An immutable address for the beacon to avoid unnecessary SLOADs before each delegate call.
    address private immutable _beacon;

    /**
     * @dev Initializes the proxy with `beacon`.
     *
     * If `data` is nonempty, it's used as data in a delegate call to the implementation returned by the beacon. This
     * will typically be an encoded function call, and allows initializing the storage of the proxy like a Solidity
     * constructor.
     *
     * Requirements:
     *
     * - `beacon` must be a contract with the interface {IBeacon}.
     * - If `data` is empty, `msg.value` must be zero.
     */
    constructor(address beacon, bytes memory data) payable {
        ERC1967Utils.upgradeBeaconToAndCall(beacon, data);
        _beacon = beacon;
    }

    /**
     * @dev Returns the current implementation address of the associated beacon.
     */
    function _implementation() internal view virtual override returns (address) {
        return IBeacon(_getBeacon()).implementation();
    }

    /**
     * @dev Returns the beacon.
     */
    function _getBeacon() internal view virtual returns (address) {
        return _beacon;
    }
}

// node_modules/@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol

// OpenZeppelin Contracts (last updated v5.3.0) (proxy/utils/UUPSUpgradeable.sol)

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 */
abstract contract UUPSUpgradeable is Initializable, IERC1822Proxiable {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address private immutable __self = address(this);

    /**
     * @dev The version of the upgrade interface of the contract. If this getter is missing, both `upgradeTo(address)`
     * and `upgradeToAndCall(address,bytes)` are present, and `upgradeTo` must be used if no function should be called,
     * while `upgradeToAndCall` will invoke the `receive` function if the second argument is the empty byte string.
     * If the getter returns `"5.0.0"`, only `upgradeToAndCall(address,bytes)` is present, and the second argument must
     * be the empty byte string if no function should be called, making it impossible to invoke the `receive` function
     * during an upgrade.
     */
    string public constant UPGRADE_INTERFACE_VERSION = "5.0.0";

    /**
     * @dev The call is from an unauthorized context.
     */
    error UUPSUnauthorizedCallContext();

    /**
     * @dev The storage `slot` is unsupported as a UUID.
     */
    error UUPSUnsupportedProxiableUUID(bytes32 slot);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC-1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC-1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        _checkProxy();
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        _checkNotDelegated();
        _;
    }

    function __UUPSUpgradeable_init() internal onlyInitializing {
    }

    function __UUPSUpgradeable_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Implementation of the ERC-1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate the implementation's compatibility when performing an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual notDelegated returns (bytes32) {
        return ERC1967Utils.IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     *
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) public payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data);
    }

    /**
     * @dev Reverts if the execution is not performed via delegatecall or the execution
     * context is not of a proxy with an ERC-1967 compliant implementation pointing to self.
     */
    function _checkProxy() internal view virtual {
        if (
            address(this) == __self || // Must be called through delegatecall
            ERC1967Utils.getImplementation() != __self // Must be called through an active proxy
        ) {
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Reverts if the execution is performed via delegatecall.
     * See {notDelegated}.
     */
    function _checkNotDelegated() internal view virtual {
        if (address(this) != __self) {
            // Must not be called through delegatecall
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev Performs an implementation upgrade with a security check for UUPS proxies, and additional setup call.
     *
     * As a security check, {proxiableUUID} is invoked in the new implementation, and the return value
     * is expected to be the implementation slot in ERC-1967.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function _upgradeToAndCallUUPS(address newImplementation, bytes memory data) private {
        try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
            if (slot != ERC1967Utils.IMPLEMENTATION_SLOT) {
                revert UUPSUnsupportedProxiableUUID(slot);
            }
            ERC1967Utils.upgradeToAndCall(newImplementation, data);
        } catch {
            // The implementation is not UUPS
            revert ERC1967Utils.ERC1967InvalidImplementation(newImplementation);
        }
    }
}

// contracts/KonduxRoyaltySplitter.sol

/**
 * @title KonduxRoyaltySplitter
 * @notice Receives royalty payments from marketplaces and distributes them according to
 *         the Kondux royalty model:
 *
 *         - Manufacturer cut (m): Fixed %, goes to Kondux treasury
 *         - Partner cut (p): Fixed %, goes to partner/collection owner
 *         - Creator cut (c): Variable %, goes to the original minter of the NFT
 *
 *         Creator receives their cut on ALL sales (including first sale).
 *         OpenSea sees a CONSTANT total royalty (m + p + max_c) going to this contract.
 *         This contract then distributes based on per-token creator data.
 *
 *         Supports two modes:
 *         1. PULL MODE: Royalties accumulate, recipients withdraw later
 *         2. PUSH MODE: Atomic distribution during transfer (via onTransferWithValue)
 *
 * @dev This contract should be set as the ERC2981 royalty receiver for the collection.
 */
contract KonduxRoyaltySplitter is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant COLLECTION_ROLE = keccak256("COLLECTION_ROLE");
    bytes32 public constant FEE_ADMIN_ROLE = keccak256("FEE_ADMIN_ROLE");

    /// @notice The NFT collection this splitter serves
    /// @dev Can be set once after deployment if initially zero (for factory deployment pattern)
    address public collection;
    
    /// @notice Manufacturer (Kondux) treasury address
    address public manufacturerWallet;
    
    /// @notice Partner/collection owner address  
    address public partnerWallet;
    
    /// @notice Basis points for manufacturer (e.g., 400 = 4%)
    uint96 public manufacturerCutBP;
    
    /// @notice Basis points for partner (e.g., 300 = 3%)
    uint96 public partnerCutBP;
    
    /// @notice Default creator cut for tokens without specific override (e.g., 300 = 3%)
    uint96 public defaultCreatorCutBP;

    /// @notice Default creator wallet for tokens without registered creator
    address public defaultCreatorWallet;

    /// @notice Maximum total royalty (what OpenSea sees as creator_fee)
    uint96 public constant MAX_TOTAL_ROYALTY_BP = 1000; // 10%
    
    uint96 public constant DENOMINATOR = 10000;

    /// @notice Whether to use push (immediate) distribution mode
    bool public pushModeEnabled;

    /// @notice Per-token creator info
    struct CreatorInfo {
        address creator;      // The original minter/creator
        uint96 creatorCutBP;  // Their specific cut in basis points
    }
    
    mapping(uint256 => CreatorInfo) public tokenCreators;
    
    /// @notice Accumulated balances for each recipient
    mapping(address => uint256) public pendingETH;
    mapping(address => mapping(address => uint256)) public pendingERC20; // token => recipient => amount

    /// @notice Events
    event RoyaltyReceived(uint256 indexed tokenId, uint256 amount, address indexed token);
    event RoyaltyDistributed(
        uint256 indexed tokenId,
        uint256 manufacturerAmount,
        uint256 partnerAmount,
        uint256 creatorAmount,
        address indexed creator
    );
    event CreatorRegistered(uint256 indexed tokenId, address indexed creator, uint96 cutBP);
    event WalletsUpdated(address manufacturer, address partner);
    event CutsUpdated(uint96 manufacturerBP, uint96 partnerBP, uint96 defaultCreatorBP);
    event Withdrawn(address indexed recipient, uint256 amount, address indexed token);
    event PushModeUpdated(bool enabled);
    event ImmediateDistribution(
        uint256 indexed tokenId,
        uint256 salePrice,
        uint256 royaltyAmount,
        address indexed seller
    );
    event CreatorWalletUpdated(uint256 indexed tokenId, address indexed oldWallet, address indexed newWallet);
    event CreatorOverridden(uint256 indexed tokenId, address indexed creator, uint96 cutBP);
    event DefaultCreatorWalletUpdated(address indexed newDefaultCreator);
    event CollectionSet(address indexed collection);

    error InvalidAddress();
    error NotCreatorOfToken();
    error AlreadyRegistered();
    error InvalidCuts();
    error TokenNotRegistered();
    error NoFundsToWithdraw();
    error OnlyCollection();
    error TransferFailed();

    constructor(
        address _collection,
        address _manufacturerWallet,
        address _partnerWallet,
        uint96 _manufacturerCutBP,
        uint96 _partnerCutBP,
        uint96 _defaultCreatorCutBP,
        address _defaultCreatorWallet,
        address _admin
    ) {
        // Allow _collection to be zero for factory deployment pattern (set later via setCollection)
        if (_manufacturerWallet == address(0) || _admin == address(0)) {
            revert InvalidAddress();
        }
        if (_manufacturerCutBP + _partnerCutBP + _defaultCreatorCutBP > MAX_TOTAL_ROYALTY_BP) {
            revert InvalidCuts();
        }

        collection = _collection;
        manufacturerWallet = _manufacturerWallet;
        partnerWallet = _partnerWallet;
        manufacturerCutBP = _manufacturerCutBP;
        partnerCutBP = _partnerCutBP;
        defaultCreatorCutBP = _defaultCreatorCutBP;
        defaultCreatorWallet = _defaultCreatorWallet;

        // Enable push mode by default
        pushModeEnabled = true;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(FEE_ADMIN_ROLE, _admin);
        _grantRole(DISTRIBUTOR_ROLE, _admin);
        // Only grant COLLECTION_ROLE if collection is set
        if (_collection != address(0)) {
            _grantRole(COLLECTION_ROLE, _collection);
        }
    }

    /**
     * @notice Set the collection address (can only be called once if initially zero)
     * @dev Used by factory to set collection after deployment in splitter-first pattern
     * @param _collection The NFT collection address
     */
    function setCollection(address _collection) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (collection != address(0)) revert InvalidAddress(); // Already set
        if (_collection == address(0)) revert InvalidAddress();
        
        collection = _collection;
        _grantRole(COLLECTION_ROLE, _collection);
        
        emit CollectionSet(_collection);
    }

    /// @notice Receive ETH (royalty payments)
    /// @dev Uses bidirectional same-block matching to handle Seaport execution order
    receive() external payable {
        if (!pushModeEnabled || msg.value == 0) return;

        // BIDIRECTIONAL MATCHING: Check if a sale was registered in this same block
        // Note: pendingSaleBlock != 0 indicates a pending sale exists (tokenId can be 0)
        if (pendingSaleBlock == block.number && pendingSaleBlock != 0) {
            // Sale was registered first in this block - distribute now
            uint256 tokenId = pendingSaleTokenId;
            uint256 amount = msg.value;

            // Clear state BEFORE distribution (reentrancy protection)
            _clearPendingSaleState();

            _distributeETHImmediate(tokenId, amount);
            emit SameBlockDistribution(tokenId, amount, false); // ethFirst=false, sale came first
            return; // Exit after distribution
        }

        // No matching sale in this block yet - record ETH for later matching
        // If registerSale() is called later in this same block, it will distribute
        pendingETHAmount = msg.value;
        pendingETHBlock = block.number;
    }

    /// @notice Track pending sales for atomic distribution
    /// @dev Maps a unique sale ID to the tokenId being sold
    mapping(bytes32 => uint256) public pendingSales;
    
    /// @notice Counter for generating unique sale IDs
    uint256 public saleNonce;

    /// @notice Last sold token ID for automatic distribution in receive()
    /// @dev Set during registerSale, used by receive() to know which token's royalty is being paid
    uint256 public lastSoldTokenId;

    /// @notice Whether there's a pending sale awaiting payment
    bool public hasPendingSale;

    /*//////////////////////////////////////////////////////////////
                    BIDIRECTIONAL SAME-BLOCK MATCHING
    //////////////////////////////////////////////////////////////*/

    /// @notice Pending ETH amount waiting to be matched with a sale
    uint256 public pendingETHAmount;

    /// @notice Block number when pending ETH was received
    uint256 public pendingETHBlock;

    /// @notice Token ID of pending sale waiting to be matched with ETH
    uint256 public pendingSaleTokenId;

    /// @notice Block number when pending sale was registered
    uint256 public pendingSaleBlock;

    /// @notice Emitted when ETH and sale are matched in the same block
    event SameBlockDistribution(uint256 indexed tokenId, uint256 amount, bool ethFirst);

    /// @dev Clear pending sale state after distribution
    function _clearPendingSaleState() internal {
        pendingSaleTokenId = 0;
        pendingSaleBlock = 0;
        // Also clear legacy state
        hasPendingSale = false;
        lastSoldTokenId = 0;
    }

    /// @dev Clear pending ETH state after distribution
    function _clearPendingETHState() internal {
        pendingETHAmount = 0;
        pendingETHBlock = 0;
    }

    /**
     * @notice Called by the collection contract BEFORE the transfer to register a pending sale
     * @param tokenId The token about to be sold
     * @return saleId A unique identifier for this sale (used to match with incoming payment)
     * @dev Uses bidirectional same-block matching to handle Seaport execution order
     */
    function registerSale(uint256 tokenId) external onlyRole(COLLECTION_ROLE) returns (bytes32 saleId) {
        saleId = keccak256(abi.encodePacked(block.timestamp, tokenId, saleNonce++));
        pendingSales[saleId] = tokenId;

        // BIDIRECTIONAL MATCHING: Check if ETH was received in this same block
        if (pendingETHBlock == block.number && pendingETHAmount > 0) {
            // ETH arrived first in this block - distribute now
            uint256 amount = pendingETHAmount;

            // Clear state BEFORE distribution (reentrancy protection)
            _clearPendingETHState();

            _distributeETHImmediate(tokenId, amount);
            emit SameBlockDistribution(tokenId, amount, true); // ethFirst=true
        } else {
            // No matching ETH in this block yet - record sale for later matching
            // If receive() is called later in this same block, it will distribute
            pendingSaleTokenId = tokenId;
            pendingSaleBlock = block.number;

            // Also set legacy state for backwards compatibility
            lastSoldTokenId = tokenId;
            hasPendingSale = true;
        }

        emit SaleRegistered(saleId, tokenId);
    }

    /**
     * @notice Receive payment for a specific sale and distribute immediately
     * @param saleId The unique sale identifier from registerSale()
     * @dev Called by marketplace or wrapper contract with the royalty payment
     */
    function receivePaymentForSale(bytes32 saleId) external payable nonReentrant {
        uint256 tokenId = pendingSales[saleId];
        require(tokenId != 0 || saleId == bytes32(0), "Unknown sale");
        
        if (msg.value > 0) {
            if (pushModeEnabled && tokenId != 0) {
                _distributeETHImmediate(tokenId, msg.value);
            } else {
                _distributeETH(tokenId, msg.value);
            }
        }
        
        // Clear the pending sale
        delete pendingSales[saleId];
    }

    /**
     * @notice Alternative: Receive payment with tokenId directly specified
     * @param tokenId The token that was sold
     * @dev Simpler approach - caller must be trusted (COLLECTION_ROLE or DISTRIBUTOR_ROLE)
     */
    function receivePaymentForToken(uint256 tokenId) external payable nonReentrant {
        require(
            hasRole(COLLECTION_ROLE, msg.sender) || hasRole(DISTRIBUTOR_ROLE, msg.sender),
            "Not authorized"
        );
        
        if (msg.value > 0) {
            if (pushModeEnabled) {
                _distributeETHImmediate(tokenId, msg.value);
            } else {
                _distributeETH(tokenId, msg.value);
            }
        }
    }

    event SaleRegistered(bytes32 indexed saleId, uint256 indexed tokenId);

    /*//////////////////////////////////////////////////////////////
                         TRANSFER HOOK (ATOMIC)
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Called by the NFT contract during a transfer to atomically distribute royalties.
     *         This enables "push mode" where royalties are paid immediately during the sale.
     * @param tokenId The token being transferred
     * @param from The seller
     * @param salePrice The sale price (msg.value sent to this function)
     * @dev Only callable by the collection contract. Expects ETH to be sent with the call.
     */
    function onTransferWithValue(
        uint256 tokenId,
        address from,
        uint256 salePrice
    ) external payable onlyRole(COLLECTION_ROLE) nonReentrant {
        if (msg.value == 0) return;
        
        // Calculate royalty based on sale price
        uint256 royaltyAmount = (salePrice * MAX_TOTAL_ROYALTY_BP) / DENOMINATOR;
        
        // Use actual received value (may differ due to rounding)
        uint256 actualAmount = msg.value;
        if (actualAmount > royaltyAmount) {
            actualAmount = royaltyAmount;
        }

        if (pushModeEnabled) {
            // Immediate distribution
            _distributeETHImmediate(tokenId, actualAmount);
        } else {
            // Accumulate for later withdrawal
            _distributeETH(tokenId, actualAmount);
        }

        emit ImmediateDistribution(tokenId, salePrice, actualAmount, from);
    }

    /**
     * @notice Immediately distribute ETH to recipients (no accumulation)
     */
    function _distributeETHImmediate(uint256 tokenId, uint256 amount) internal {
        (
            uint256 manufacturerAmount,
            uint256 partnerAmount,
            uint256 creatorAmount,
            address creator
        ) = _calculateSplit(tokenId, amount);

        // Immediate transfers
        if (manufacturerAmount > 0) {
            _safeTransferETH(manufacturerWallet, manufacturerAmount);
        }
        
        if (partnerWallet != address(0) && partnerAmount > 0) {
            _safeTransferETH(partnerWallet, partnerAmount);
        } else if (partnerAmount > 0) {
            _safeTransferETH(manufacturerWallet, partnerAmount);
        }
        
        if (creator != address(0) && creatorAmount > 0) {
            _safeTransferETH(creator, creatorAmount);
        } else if (creatorAmount > 0) {
            _safeTransferETH(manufacturerWallet, creatorAmount);
        }

        emit RoyaltyDistributed(tokenId, manufacturerAmount, partnerAmount, creatorAmount, creator);
    }

    /**
     * @notice Safe ETH transfer with fallback to pending balance
     */
    function _safeTransferETH(address to, uint256 amount) internal {
        (bool success, ) = to.call{value: amount, gas: 50000}("");
        if (!success) {
            // If transfer fails (e.g., contract without receive), accumulate instead
            pendingETH[to] += amount;
        }
    }

    /**
     * @notice Enable or disable push (immediate) distribution mode
     */
    function setPushMode(bool enabled) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(FEE_ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        pushModeEnabled = enabled;
        emit PushModeUpdated(enabled);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Register creator info for a token (called by collection on mint or by admin)
     * @param tokenId The token ID
     * @param creator The creator's address
     * @param creatorCutBP The creator's royalty cut in basis points
     * @dev COLLECTION_ROLE can only register new tokens. Admins can override existing.
     */
    function registerCreator(
        uint256 tokenId,
        address creator,
        uint96 creatorCutBP
    ) external {
        // Check authorization
        bool isAdmin = hasRole(ADMIN_ROLE, msg.sender) ||
                       hasRole(DISTRIBUTOR_ROLE, msg.sender) ||
                       hasRole(FEE_ADMIN_ROLE, msg.sender);
        bool isCollection = hasRole(COLLECTION_ROLE, msg.sender);

        require(isAdmin || isCollection, "Not authorized");

        if (creator == address(0)) revert InvalidAddress();
        if (manufacturerCutBP + partnerCutBP + creatorCutBP > MAX_TOTAL_ROYALTY_BP) {
            revert InvalidCuts();
        }

        // If already registered, only admins can override (not collection)
        if (tokenCreators[tokenId].creator != address(0)) {
            require(isAdmin, "Already registered, need admin to override");
        }

        tokenCreators[tokenId] = CreatorInfo({
            creator: creator,
            creatorCutBP: creatorCutBP
        });

        emit CreatorRegistered(tokenId, creator, creatorCutBP);
    }

    /**
     * @notice Batch register creators (gas efficient for minting batches)
     * @dev Only admins can batch register (not collection) to prevent abuse
     */
    function registerCreatorsBatch(
        uint256[] calldata tokenIds,
        address[] calldata creators,
        uint96[] calldata creatorCutsBP
    ) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender) ||
            hasRole(DISTRIBUTOR_ROLE, msg.sender) ||
            hasRole(FEE_ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        require(
            tokenIds.length == creators.length && creators.length == creatorCutsBP.length,
            "Length mismatch"
        );

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (creators[i] == address(0)) revert InvalidAddress();
            if (manufacturerCutBP + partnerCutBP + creatorCutsBP[i] > MAX_TOTAL_ROYALTY_BP) {
                revert InvalidCuts();
            }

            tokenCreators[tokenIds[i]] = CreatorInfo({
                creator: creators[i],
                creatorCutBP: creatorCutsBP[i]
            });

            emit CreatorRegistered(tokenIds[i], creators[i], creatorCutsBP[i]);
        }
    }

    /**
     * @notice Update wallet addresses
     */
    function setWallets(
        address _manufacturerWallet,
        address _partnerWallet
    ) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(FEE_ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        if (_manufacturerWallet == address(0)) revert InvalidAddress();
        manufacturerWallet = _manufacturerWallet;
        partnerWallet = _partnerWallet;
        emit WalletsUpdated(_manufacturerWallet, _partnerWallet);
    }

    /**
     * @notice Update cut percentages
     */
    function setCuts(
        uint96 _manufacturerCutBP,
        uint96 _partnerCutBP,
        uint96 _defaultCreatorCutBP
    ) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(FEE_ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        if (_manufacturerCutBP + _partnerCutBP + _defaultCreatorCutBP > MAX_TOTAL_ROYALTY_BP) {
            revert InvalidCuts();
        }
        manufacturerCutBP = _manufacturerCutBP;
        partnerCutBP = _partnerCutBP;
        defaultCreatorCutBP = _defaultCreatorCutBP;
        emit CutsUpdated(_manufacturerCutBP, _partnerCutBP, _defaultCreatorCutBP);
    }

    /**
     * @notice Set the default creator wallet (used when no creator is registered for a token)
     * @param _defaultCreatorWallet The fallback creator wallet address
     */
    function setDefaultCreatorWallet(address _defaultCreatorWallet) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(FEE_ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        defaultCreatorWallet = _defaultCreatorWallet;
        emit DefaultCreatorWalletUpdated(_defaultCreatorWallet);
    }

    /**
     * @notice Allows a registered creator to change their own receiving wallet
     * @param tokenId The token ID for which they are the creator
     * @param newWallet The new wallet address to receive royalties
     */
    function updateCreatorWallet(uint256 tokenId, address newWallet) external {
        CreatorInfo storage info = tokenCreators[tokenId];
        if (info.creator != msg.sender) revert NotCreatorOfToken();
        if (newWallet == address(0)) revert InvalidAddress();

        address oldWallet = info.creator;
        info.creator = newWallet;

        emit CreatorWalletUpdated(tokenId, oldWallet, newWallet);
    }

    /**
     * @notice Admin/Distributor can override creator registration
     * @param tokenId The token ID
     * @param creator The new creator address
     * @param creatorCutBP The creator's royalty cut in basis points
     */
    function overrideCreator(
        uint256 tokenId,
        address creator,
        uint96 creatorCutBP
    ) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender) ||
            hasRole(DISTRIBUTOR_ROLE, msg.sender) ||
            hasRole(FEE_ADMIN_ROLE, msg.sender),
            "Not authorized to override"
        );

        if (creator == address(0)) revert InvalidAddress();
        if (manufacturerCutBP + partnerCutBP + creatorCutBP > MAX_TOTAL_ROYALTY_BP) {
            revert InvalidCuts();
        }

        tokenCreators[tokenId] = CreatorInfo({
            creator: creator,
            creatorCutBP: creatorCutBP
        });

        emit CreatorOverridden(tokenId, creator, creatorCutBP);
    }

    /*//////////////////////////////////////////////////////////////
                         DISTRIBUTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Distribute ETH royalty for a specific token sale
     * @param tokenId The token that was sold
     * @param amount The royalty amount to distribute
     */
    function distributeETH(uint256 tokenId, uint256 amount) external nonReentrant {
        _distributeETH(tokenId, amount);
    }

    /**
     * @notice Distribute ERC20 royalty for a specific token sale
     * @param tokenId The token that was sold
     * @param token The ERC20 token address
     * @param amount The royalty amount to distribute
     */
    function distributeERC20(
        uint256 tokenId,
        address token,
        uint256 amount
    ) external nonReentrant {
        _distributeERC20(tokenId, token, amount);
    }

    /**
     * @notice Internal ETH distribution logic
     */
    function _distributeETH(uint256 tokenId, uint256 amount) internal {
        (
            uint256 manufacturerAmount,
            uint256 partnerAmount,
            uint256 creatorAmount,
            address creator
        ) = _calculateSplit(tokenId, amount);

        // Accumulate pending balances
        pendingETH[manufacturerWallet] += manufacturerAmount;
        if (partnerWallet != address(0) && partnerAmount > 0) {
            pendingETH[partnerWallet] += partnerAmount;
        } else {
            // If no partner, manufacturer gets their share too
            pendingETH[manufacturerWallet] += partnerAmount;
        }
        if (creator != address(0) && creatorAmount > 0) {
            pendingETH[creator] += creatorAmount;
        } else {
            // If no creator, manufacturer gets their share
            pendingETH[manufacturerWallet] += creatorAmount;
        }

        emit RoyaltyDistributed(tokenId, manufacturerAmount, partnerAmount, creatorAmount, creator);
    }

    /**
     * @notice Internal ERC20 distribution logic
     */
    function _distributeERC20(uint256 tokenId, address token, uint256 amount) internal {
        (
            uint256 manufacturerAmount,
            uint256 partnerAmount,
            uint256 creatorAmount,
            address creator
        ) = _calculateSplit(tokenId, amount);

        pendingERC20[token][manufacturerWallet] += manufacturerAmount;
        if (partnerWallet != address(0) && partnerAmount > 0) {
            pendingERC20[token][partnerWallet] += partnerAmount;
        } else {
            pendingERC20[token][manufacturerWallet] += partnerAmount;
        }
        if (creator != address(0) && creatorAmount > 0) {
            pendingERC20[token][creator] += creatorAmount;
        } else {
            pendingERC20[token][manufacturerWallet] += creatorAmount;
        }

        emit RoyaltyDistributed(tokenId, manufacturerAmount, partnerAmount, creatorAmount, creator);
    }

    /**
     * @notice Calculate the split for a given token and amount
     * @dev Creator receives their cut on ALL sales (no first sale distinction)
     */
    function _calculateSplit(uint256 tokenId, uint256 amount)
        internal
        view
        returns (
            uint256 manufacturerAmount,
            uint256 partnerAmount,
            uint256 creatorAmount,
            address creator
        )
    {
        CreatorInfo memory info = tokenCreators[tokenId];
        bool hasCreator = info.creator != address(0);

        // Determine creator cut and address
        // If no creator registered, fallback to defaultCreatorWallet with defaultCreatorCutBP
        if (hasCreator) {
            creator = info.creator;
        } else if (defaultCreatorWallet != address(0)) {
            creator = defaultCreatorWallet;
        } else {
            creator = address(0);
        }

        uint96 actualCreatorCutBP = hasCreator ? info.creatorCutBP : defaultCreatorCutBP;

        // Calculate amounts
        uint256 totalBP = manufacturerCutBP + partnerCutBP + actualCreatorCutBP;

        if (totalBP == 0) {
            // No splits configured, everything to manufacturer
            return (amount, 0, 0, address(0));
        }

        // Proportional distribution based on the ACTUAL cuts (not max)
        // The received amount is based on MAX_TOTAL_ROYALTY_BP from OpenSea
        // We distribute based on actual cuts, remainder goes to manufacturer

        manufacturerAmount = (amount * manufacturerCutBP) / MAX_TOTAL_ROYALTY_BP;
        partnerAmount = (amount * partnerCutBP) / MAX_TOTAL_ROYALTY_BP;
        creatorAmount = (amount * actualCreatorCutBP) / MAX_TOTAL_ROYALTY_BP;

        // Any remainder (from tokens with lower creator cut) goes to manufacturer
        uint256 distributed = manufacturerAmount + partnerAmount + creatorAmount;
        if (distributed < amount) {
            manufacturerAmount += (amount - distributed);
        }
    }

    /**
     * @notice Get the split breakdown for a token (view function for frontends)
     */
    function getSplit(uint256 tokenId, uint256 amount)
        external
        view
        returns (
            uint256 manufacturerAmount,
            uint256 partnerAmount,
            uint256 creatorAmount,
            address creator,
            uint96 creatorCutBP
        )
    {
        CreatorInfo memory info = tokenCreators[tokenId];
        bool hasCreator = info.creator != address(0);
        creatorCutBP = hasCreator ? info.creatorCutBP : defaultCreatorCutBP;

        (manufacturerAmount, partnerAmount, creatorAmount, creator) = _calculateSplit(tokenId, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          WITHDRAWAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Withdraw accumulated ETH
     */
    function withdrawETH() external nonReentrant {
        uint256 amount = pendingETH[msg.sender];
        if (amount == 0) revert NoFundsToWithdraw();
        
        pendingETH[msg.sender] = 0;
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
        
        emit Withdrawn(msg.sender, amount, address(0));
    }

    /**
     * @notice Withdraw accumulated ERC20 tokens
     */
    function withdrawERC20(address token) external nonReentrant {
        uint256 amount = pendingERC20[token][msg.sender];
        if (amount == 0) revert NoFundsToWithdraw();
        
        pendingERC20[token][msg.sender] = 0;
        
        IERC20(token).safeTransfer(msg.sender, amount);
        
        emit Withdrawn(msg.sender, amount, token);
    }

    /**
     * @notice Admin function to distribute all pending ETH in contract
     *         Useful if royalties were sent without calling distribute()
     */
    function sweepETH(uint256 tokenId) external onlyRole(ADMIN_ROLE) nonReentrant {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            _distributeETH(tokenId, balance);
        }
    }

    /**
     * @notice Admin function to distribute all pending ERC20 in contract
     */
    function sweepERC20(uint256 tokenId, address token) external onlyRole(ADMIN_ROLE) nonReentrant {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            _distributeERC20(tokenId, token, balance);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Check if a token has creator info registered
     */
    function hasCreatorInfo(uint256 tokenId) external view returns (bool) {
        return tokenCreators[tokenId].creator != address(0);
    }

    /**
     * @notice Get creator info for a token
     */
    function getCreatorInfo(uint256 tokenId)
        external
        view
        returns (address creator, uint96 cutBP)
    {
        CreatorInfo memory info = tokenCreators[tokenId];
        return (info.creator, info.creatorCutBP);
    }

    /**
     * @notice Get total pending ETH for an address
     */
    function getPendingETH(address recipient) external view returns (uint256) {
        return pendingETH[recipient];
    }

    /**
     * @notice Get total pending ERC20 for an address
     */
    function getPendingERC20(address token, address recipient) external view returns (uint256) {
        return pendingERC20[token][recipient];
    }
}

// contracts/KonduxBeaconFactoryUpgradeable.sol

/**
 * @title  KonduxBeaconFactoryUpgradeable
 * @notice UUPS-upgradeable factory for deploying Kondux NFT collection clones.
 *         
 * @dev Key features:
 *      - UUPS upgradeable pattern (factory itself can be upgraded)
 *      - Owns an UpgradeableBeacon for implementation upgrades
 *      - Can transfer beacon ownership to new factory versions
 *      - Auto-configures OpenSea marketplace security on clone deployment
 *
 * Upgrade paths:
 *      1. Factory logic: Call upgradeToAndCall() with new implementation
 *      2. NFT Implementation: Call upgradeImplementation() to upgrade all clones
 *      3. Beacon ownership: Call transferBeaconOwnership() to migrate to new factory
 */
contract KonduxBeaconFactoryUpgradeable is 
    Initializable, 
    UUPSUpgradeable, 
    AccessControlUpgradeable 
{
    /*-------------------------------------------------------------*/
    /* Roles & Constants                                           */
    /*-------------------------------------------------------------*/
    bytes32 public constant CLONE_DEPLOYER_ROLE = keccak256("CLONE_DEPLOYER");
    bytes32 public constant FEE_ADMIN_ROLE = keccak256("FEE_ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice Seaport 1.6 contract address (mainnet)
    address public constant SEAPORT = 0x0000000000000068F116a894984e2DB1123eB395;

    /// @notice OpenSea Conduit address (mainnet)
    address public constant OPENSEA_CONDUIT = 0x1E0049783F008A0085193E00003D00cd54003c71;

    /*-------------------------------------------------------------*/
    /* Storage (upgradeable - be careful with ordering!)           */
    /*-------------------------------------------------------------*/
    /// @notice The beacon that all clones point to
    /// @dev Not immutable to allow setting during initialize()
    UpgradeableBeacon public beacon;

    /// @notice Whether anyone can deploy clones or only CLONE_DEPLOYER_ROLE
    bool public publicDeployment;

    /// @notice Maps collection addresses to their deployed splitters
    mapping(address => address) public collectionToSplitter;

    /// @notice List of all deployed splitters for enumeration
    address[] public deployedSplitters;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    /// @notice Version number for tracking upgrades
    uint256 public version;

    /// @dev Gap for future storage variables (50 slots reserved)
    uint256[45] private __gap;

    /*-------------------------------------------------------------*/
    /* Events                                                      */
    /*-------------------------------------------------------------*/
    event GlobalUpgrade(address newImplementation);
    event CloneDeployed(address proxy, address indexed creator);
    event PublicDeploymentChanged(bool open);
    event SplitterDeployed(address indexed collection, address indexed splitter, address indexed creator);
    event MarketplaceSecurityConfigured(address indexed collection);
    event BeaconOwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FactoryUpgraded(uint256 indexed oldVersion, uint256 indexed newVersion, address newImplementation);

    /*-------------------------------------------------------------*/
    /* Constructor & Initializer                                   */
    /*-------------------------------------------------------------*/
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the upgradeable factory with an implementation address.
     * @dev Creates a new UpgradeableBeacon owned by this factory.
     * @param impl The NFT implementation contract address.
     * @param admin The address to receive admin roles.
     */
    function initialize(address impl, address admin) external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(FEE_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        _grantRole(CLONE_DEPLOYER_ROLE, admin);

        // Deploy beacon with this factory as owner
        beacon = new UpgradeableBeacon(impl, address(this));
        
        publicDeployment = false; // Gated by default for security
        version = 1;
    }

    /**
     * @notice Re-initializer for upgrading from V1 to V2+ (example pattern)
     * @dev Can be used to add new state or run migration logic
     * @param newVersion The new version number
     */
    function reinitialize(uint256 newVersion) external reinitializer(uint8(newVersion)) {
        require(newVersion > version, "Factory: version must increase");
        uint256 oldVersion = version;
        version = newVersion;
        emit FactoryUpgraded(oldVersion, newVersion, address(this));
    }

    /*-------------------------------------------------------------*/
    /* UUPS Authorization                                          */
    /*-------------------------------------------------------------*/
    /**
     * @dev Required override for UUPS - only UPGRADER_ROLE can upgrade factory
     */
    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyRole(UPGRADER_ROLE) 
    {
        emit FactoryUpgraded(version, version + 1, newImplementation);
    }

    /*-------------------------------------------------------------*/
    /* Admin functions                                             */
    /*-------------------------------------------------------------*/

    /**
     * @notice Toggle open/gated clone deployment.
     * @param open If true, anyone can deploy clones. If false, requires CLONE_DEPLOYER_ROLE.
     */
    function setPublicDeployment(bool open)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        publicDeployment = open;
        emit PublicDeploymentChanged(open);
    }

    /**
     * @notice Upgrades the beacon's implementation to a new address.
     * @dev This upgrades ALL past and future clones atomically.
     * @param newImpl The new NFT implementation contract address.
     */
    function upgradeImplementation(address newImpl)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        beacon.upgradeTo(newImpl);
        emit GlobalUpgrade(newImpl);
    }

    /**
     * @notice Transfers ownership of the beacon to a new address.
     * @dev Use this to migrate to a new factory version while preserving the beacon.
     *      The new owner must be a contract that can call beacon.upgradeTo().
     *      WARNING: This is irreversible - the old factory loses control of the beacon.
     * @param newOwner The new owner address (typically a new factory contract).
     */
    function transferBeaconOwnership(address newOwner)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newOwner != address(0), "Factory: new owner is zero address");
        require(newOwner != address(this), "Factory: new owner is current factory");
        
        address previousOwner = beacon.owner();
        beacon.transferOwnership(newOwner);
        
        emit BeaconOwnershipTransferred(previousOwner, newOwner);
    }

    /**
     * @notice Accepts beacon ownership from another factory.
     * @dev Call this after the previous owner calls transferBeaconOwnership.
     *      Only needed if beacon uses Ownable2Step (OZ 5.x default is Ownable).
     * @param _beacon The beacon to accept ownership of.
     */
    function acceptBeaconOwnership(address _beacon)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        // Store reference to the beacon
        beacon = UpgradeableBeacon(_beacon);
        // Note: Standard Ownable doesn't require acceptance, but this is here
        // in case the beacon uses Ownable2Step
    }

    /**
     * @notice Sets a pre-existing beacon (for migration scenarios).
     * @dev Only use this when migrating from an old factory that transferred beacon ownership.
     * @param _beacon The beacon address to use.
     */
    function setBeacon(address _beacon)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_beacon != address(0), "Factory: beacon is zero address");
        require(
            UpgradeableBeacon(_beacon).owner() == address(this),
            "Factory: not beacon owner"
        );
        beacon = UpgradeableBeacon(_beacon);
    }

    /*-------------------------------------------------------------*/
    /* Clone deployment                                            */
    /*-------------------------------------------------------------*/

    /**
     * @notice Deploys a new BeaconProxy clone with the given initialization calldata.
     * @param initCalldata The initialization calldata for the clone.
     * @return proxy The deployed proxy address.
     */
    function deployClone(bytes calldata initCalldata)
        external
        returns (address proxy)
    {
        if (!publicDeployment) {
            _checkRole(CLONE_DEPLOYER_ROLE, msg.sender);
        }

        proxy = address(new BeaconProxy(address(beacon), initCalldata));
        _configureMarketplaceSecurity(proxy);

        emit CloneDeployed(proxy, msg.sender);
    }

    /**
     * @notice Deploys a BeaconProxy clone with an optional KonduxRoyaltySplitter.
     * @param name Collection name.
     * @param symbol Collection symbol.
     * @param maxSupply Maximum token supply (0 for unlimited).
     * @param initialAdmin Address to receive admin roles.
     * @param deploySplitter If true, deploy a royalty splitter.
     * @param partnerWallet Partner address for royalty splits.
     * @param manufacturerCutBP Manufacturer cut in basis points.
     * @param partnerCutBP Partner cut in basis points.
     * @param defaultCreatorCutBP Default creator cut in basis points.
     * @param defaultCreatorWallet Fallback wallet for unregistered creators.
     * @return proxy The deployed collection proxy address.
     * @return splitter The deployed splitter address (or zero).
     */
    function deployCloneWithSplitter(
        string calldata name,
        string calldata symbol,
        uint256 maxSupply,
        address initialAdmin,
        bool deploySplitter,
        address partnerWallet,
        uint96 manufacturerCutBP,
        uint96 partnerCutBP,
        uint96 defaultCreatorCutBP,
        address defaultCreatorWallet
    ) external returns (address proxy, address splitter) {
        if (!publicDeployment) {
            _checkRole(CLONE_DEPLOYER_ROLE, msg.sender);
        }

        if (deploySplitter) {
            // 1. Deploy splitter first with placeholder collection address
            splitter = address(new KonduxRoyaltySplitter(
                address(0),                 // placeholder
                initialAdmin,               // manufacturer wallet
                partnerWallet,
                manufacturerCutBP,
                partnerCutBP,
                defaultCreatorCutBP,
                defaultCreatorWallet,
                address(this)               // Factory is initial admin
            ));

            // 2. Deploy the NFT collection clone
            bytes memory initCalldata = abi.encodeWithSignature(
                "initialize(string,string,uint256,address,address,address)",
                name,
                symbol,
                maxSupply,
                initialAdmin,
                address(this),  // factory for security config
                splitter
            );
            proxy = address(new BeaconProxy(address(beacon), initCalldata));

            // 3. Update splitter with actual collection address
            IKonduxRoyaltySplitter(splitter).setCollection(proxy);

            // 4. Grant COLLECTION_ROLE to the NFT contract
            IKonduxRoyaltySplitter(splitter).grantRole(
                IKonduxRoyaltySplitter(splitter).COLLECTION_ROLE(),
                proxy
            );

            // 5. Track the deployment
            collectionToSplitter[proxy] = splitter;
            deployedSplitters.push(splitter);

            emit SplitterDeployed(proxy, splitter, msg.sender);
        } else {
            bytes memory initCalldata = abi.encodeWithSignature(
                "initialize(string,string,uint256,address,address,address)",
                name,
                symbol,
                maxSupply,
                initialAdmin,
                address(this),
                address(0)
            );
            proxy = address(new BeaconProxy(address(beacon), initCalldata));
        }

        // 6. Configure marketplace security
        _configureMarketplaceSecurity(proxy);

        emit CloneDeployed(proxy, msg.sender);
    }

    /**
     * @dev Configures default marketplace security on a newly deployed collection.
     */
    function _configureMarketplaceSecurity(address collection) internal {
        (bool success1,) = collection.call(
            abi.encodeWithSignature("setToDefaultSecurityPolicy()")
        );

        if (success1) {
            address[] memory conduit = new address[](1);
            conduit[0] = OPENSEA_CONDUIT;
            (bool success2,) = collection.call(
                abi.encodeWithSignature("addAccountsToWhitelist(address[])", conduit)
            );
            if (success2) {
                emit MarketplaceSecurityConfigured(collection);
            }
        }
    }

    /**
     * @dev Reads the first DEFAULT_ADMIN_ROLE member from a deployed collection.
     */
    function _getCollectionManufacturer(address collection) internal view returns (address) {
        bytes32 adminRole = 0x00;
        uint256 memberCount = IAccessControlEnumerable(collection).getRoleMemberCount(adminRole);
        require(memberCount > 0, "Factory: collection has no admin");
        return IAccessControlEnumerable(collection).getRoleMember(adminRole, 0);
    }

    /*-------------------------------------------------------------*/
    /* FEE_ADMIN functions                                         */
    /*-------------------------------------------------------------*/

    /**
     * @notice Update cuts on a factory-deployed splitter.
     */
    function setCutsOnSplitter(
        address splitter,
        uint96 _manufacturerCutBP,
        uint96 _partnerCutBP,
        uint96 _defaultCreatorCutBP
    ) external onlyRole(FEE_ADMIN_ROLE) {
        IKonduxRoyaltySplitter(splitter).setCuts(
            _manufacturerCutBP,
            _partnerCutBP,
            _defaultCreatorCutBP
        );
    }

    /**
     * @notice Update wallets on a factory-deployed splitter.
     */
    function setWalletsOnSplitter(
        address splitter,
        address manufacturerWallet,
        address partnerWallet
    ) external onlyRole(FEE_ADMIN_ROLE) {
        IKonduxRoyaltySplitter(splitter).setWallets(manufacturerWallet, partnerWallet);
    }

    /**
     * @notice Register or override a creator on a splitter.
     */
    function registerCreatorOnSplitter(
        address splitter,
        uint256 tokenId,
        address creator,
        uint96 creatorCutBP
    ) external onlyRole(FEE_ADMIN_ROLE) {
        IKonduxRoyaltySplitter(splitter).overrideCreator(tokenId, creator, creatorCutBP);
    }

    /**
     * @notice Grant a role on a splitter.
     */
    function grantSplitterRole(
        address splitter,
        bytes32 role,
        address account
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IKonduxRoyaltySplitter(splitter).grantRole(role, account);
    }

    /**
     * @notice Sweep accumulated ETH from a splitter.
     */
    function sweepSplitterETH(
        address splitter,
        uint256 tokenId
    ) external onlyRole(FEE_ADMIN_ROLE) {
        (bool success, bytes memory data) = splitter.call(
            abi.encodeWithSignature("sweepETH(uint256)", tokenId)
        );
        require(success, string(data));
    }

    /**
     * @notice Returns the number of deployed splitters.
     */
    function deployedSplittersCount() external view returns (uint256) {
        return deployedSplitters.length;
    }

    /*-------------------------------------------------------------*/
    /* View functions                                              */
    /*-------------------------------------------------------------*/

    /**
     * @notice Returns the current NFT implementation address.
     */
    function implementation() external view returns (address) {
        return beacon.implementation();
    }

    /**
     * @notice Returns the beacon owner (should be this factory).
     */
    function beaconOwner() external view returns (address) {
        return beacon.owner();
    }
}
