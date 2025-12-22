// SPDX‑License‑Identifier: GPL‑3.0
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import "./KonduxRoyaltySplitter.sol";
import "./interfaces/IKonduxRoyaltySplitter.sol";

/**
 * @title  KonduxBeaconFactory
 * @notice Deploy once, then mint BeaconProxy clones whose implementation address
 *         is stored in a single UpgradeableBeacon.
 *
 *         • `publicDeployment` flag:  
 *           – `true`  (default) ⇒ anyone can call `deployClone()`  
 *           – `false`           ⇒ only `CLONE_DEPLOYER_ROLE` addresses can.  
 *
 *         • `upgradeImplementation()` (admin‑only) changes the beacon’s
 *           implementation, upgrading every past and future clone at once.
 */
contract KonduxBeaconFactory is AccessControl {
    /*-------------------------------------------------------------*/
    /* Roles & storage                                             */
    /*-------------------------------------------------------------*/
    bytes32 public constant CLONE_DEPLOYER_ROLE = keccak256("CLONE_DEPLOYER");
    bytes32 public constant FEE_ADMIN_ROLE = keccak256("FEE_ADMIN_ROLE");

    UpgradeableBeacon public immutable beacon;
    bool public publicDeployment = true;   // open by default

    /// @notice Seaport 1.6 contract address (mainnet)
    address public constant SEAPORT = 0x0000000000000068F116a894984e2DB1123eB395;

    /// @notice OpenSea Conduit address (mainnet)
    address public constant OPENSEA_CONDUIT = 0x1E0049783F008A0085193E00003D00cd54003c71;

    /// @notice Maps collection addresses to their deployed splitters
    mapping(address => address) public collectionToSplitter;

    /// @notice List of all deployed splitters for enumeration
    address[] public deployedSplitters;

    /*-------------------------------------------------------------*/
    /* Constructor                                                 */
    /*-------------------------------------------------------------*/
    /**
     * @dev Deploys a new UpgradeableBeacon with the given implementation address.
     *       The factory itself is the owner of the beacon, so it can upgrade it later.
     * @notice The `impl` address must be a contract.
     *         This contract does not check that, so it is the caller's responsibility.
     * @param impl The address of the implementation contract.
     */
    constructor(address impl) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(FEE_ADMIN_ROLE, msg.sender);

        // Two‑arg constructor since OZ v5.x
        beacon = new UpgradeableBeacon(impl, address(this));
        // owner of the beacon == this factory (no transferOwnership needed)
    }

    /*-------------------------------------------------------------*/
    /* Admin functions                                             */
    /*-------------------------------------------------------------*/

    /**
     * @dev Toggle open/gated clone deployment.
     * * If `open` is `true`, anyone can call `deployClone()`.
     * * If `open` is `false`, only addresses with the `CLONE_DEPLOYER_ROLE` can call `deployClone()`.
     * @param open Whether to allow public deployment or not
     */
    function setPublicDeployment(bool open)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        publicDeployment = open;
        emit PublicDeploymentChanged(open);
    }

    /**
     * @dev Upgrades the beacon's implementation to a new address.
     *       This will affect all past and future clones created with this beacon.
     * @param newImpl The address of the new implementation contract.
     */
    function upgradeImplementation(address newImpl)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        beacon.upgradeTo(newImpl);           // owner is the factory → OK
        emit GlobalUpgrade(newImpl);
    }

    /*-------------------------------------------------------------*/
    /* Clone deployment                                            */
    /*-------------------------------------------------------------*/
    /**
     * @dev Deploys a new BeaconProxy clone with the given initialization calldata.
     *      The clone will use the current implementation address stored in the beacon.
     *      If `publicDeployment` is `false`, only addresses with the `CLONE_DEPLOYER_ROLE`
     *      can call this function.
     * @notice The `initCalldata` is used to initialize the clone after deployment.
     *         It should be the calldata for a initialize function in the implementation contract.
     *         Automatically configures marketplace security (whitelists Seaport & conduit,
     *         restricts other secondary markets).
     * @param initCalldata The initialization calldata to pass to the clone.
     */
    function deployClone(bytes calldata initCalldata)
        external
        returns (address proxy)
    {
        if (!publicDeployment) {
            _checkRole(CLONE_DEPLOYER_ROLE, msg.sender);
        }

        proxy = address(new BeaconProxy(address(beacon), initCalldata));

        // Configure marketplace security (whitelist Seaport & conduit, restrict other markets)
        _configureMarketplaceSecurity(proxy);

        emit CloneDeployed(proxy, msg.sender);
    }

    /**
     * @notice Deploys a BeaconProxy clone with an optional KonduxRoyaltySplitter.
     * @param initCalldata Initialization data for KonduxImplementation.
     * @param deploySplitter If true, also deploy a splitter for this collection.
     * @param partnerWallet Partner address for royalty splits (can be zero).
     * @param manufacturerCutBP Manufacturer cut in basis points (e.g., 400 = 4%).
     * @param partnerCutBP Partner cut in basis points (e.g., 300 = 3%).
     * @param defaultCreatorCutBP Default creator cut in basis points (e.g., 300 = 3%).
     * @param defaultCreatorWallet Fallback wallet for unregistered creators.
     * @return proxy The deployed collection proxy address.
     * @return splitter The deployed splitter address (zero if not deployed).
     */
    function deployCloneWithSplitter(
        bytes calldata initCalldata,
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

        // 1. Deploy the NFT collection clone
        proxy = address(new BeaconProxy(address(beacon), initCalldata));

        // 2. Configure marketplace security (whitelist Seaport & conduit, restrict other markets)
        _configureMarketplaceSecurity(proxy);

        if (deploySplitter) {
            // 3. Get manufacturer wallet from collection's first DEFAULT_ADMIN_ROLE member
            address manufacturerWallet = _getCollectionManufacturer(proxy);

            // 4. Deploy splitter with factory as the admin
            splitter = address(new KonduxRoyaltySplitter(
                proxy,                      // collection
                manufacturerWallet,         // manufacturer wallet
                partnerWallet,              // partner wallet
                manufacturerCutBP,
                partnerCutBP,
                defaultCreatorCutBP,
                defaultCreatorWallet,       // fallback wallet for unregistered creators
                address(this)               // Factory is initial admin
            ));

            // 5. Grant COLLECTION_ROLE to the NFT contract
            IKonduxRoyaltySplitter(splitter).grantRole(
                IKonduxRoyaltySplitter(splitter).COLLECTION_ROLE(),
                proxy
            );

            // 6. Configure the NFT collection to use the splitter
            // Note: This requires the collection to have setRoyaltySplitter function
            (bool success,) = proxy.call(
                abi.encodeWithSignature("setRoyaltySplitter(address)", splitter)
            );
            require(success, "Failed to set splitter on collection");

            // 7. Track the deployment
            collectionToSplitter[proxy] = splitter;
            deployedSplitters.push(splitter);

            emit SplitterDeployed(proxy, splitter, msg.sender);
        }

        emit CloneDeployed(proxy, msg.sender);
    }

    /**
     * @dev Configures default marketplace security on a newly deployed collection.
     *      Creates a whitelist with Seaport 1.6, applies Operator Whitelist mode (level 4),
     *      then adds the OpenSea conduit to the whitelist.
     *      If the transfer validator is not set on the collection, this is a no-op.
     * @param collection The collection address to configure.
     */
    function _configureMarketplaceSecurity(address collection) internal {
        // 1. Set default security policy (whitelists Seaport, sets level 4)
        // Note: This will fail silently if transfer validator is not set on the collection
        (bool success1,) = collection.call(
            abi.encodeWithSignature("setToDefaultSecurityPolicy()")
        );

        // 2. Only add conduit to whitelist if security policy was successfully set
        if (success1) {
            address[] memory conduit = new address[](1);
            conduit[0] = OPENSEA_CONDUIT;
            (bool success2,) = collection.call(
                abi.encodeWithSignature("addAccountsToWhitelist(address[])", conduit)
            );
            // Emit event if security was configured
            if (success2) {
                emit MarketplaceSecurityConfigured(collection);
            }
        }
    }

    /**
     * @dev Reads the first DEFAULT_ADMIN_ROLE member from a deployed collection.
     */
    function _getCollectionManufacturer(address collection) internal view returns (address) {
        // DEFAULT_ADMIN_ROLE is always bytes32(0) in OpenZeppelin AccessControl
        bytes32 adminRole = 0x00;
        uint256 memberCount = IAccessControlEnumerable(collection).getRoleMemberCount(adminRole);
        require(memberCount > 0, "Factory: collection has no admin");
        return IAccessControlEnumerable(collection).getRoleMember(adminRole, 0);
    }

    /*-------------------------------------------------------------*/
    /* FEE_ADMIN functions                                         */
    /*-------------------------------------------------------------*/

    /**
     * @notice Allows FEE_ADMIN to update cuts on any factory-deployed splitter.
     * @param splitter The splitter address.
     * @param _manufacturerCutBP New manufacturer cut.
     * @param _partnerCutBP New partner cut.
     * @param _defaultCreatorCutBP New default creator cut.
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
     * @notice Allows FEE_ADMIN to update wallets on any factory-deployed splitter.
     * @param splitter The splitter address.
     * @param manufacturerWallet New manufacturer wallet.
     * @param partnerWallet New partner wallet.
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
     * @param splitter The splitter address.
     * @param tokenId The token ID.
     * @param creator The creator address.
     * @param creatorCutBP The creator's cut in basis points.
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
     * @notice Grant a role on a splitter to an account.
     * @dev Only callable by DEFAULT_ADMIN_ROLE.
     * @param splitter The splitter contract address.
     * @param role The role to grant.
     * @param account The account to receive the role.
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
     * @dev Only callable by FEE_ADMIN_ROLE.
     * @param splitter The splitter contract address.
     * @param tokenId The token ID to attribute the sweep to.
     */
    function sweepSplitterETH(
        address splitter,
        uint256 tokenId
    ) external onlyRole(FEE_ADMIN_ROLE) {
        // This requires the factory to have ADMIN_ROLE on the splitter
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
    /* Events                                                      */
    /*-------------------------------------------------------------*/
    event GlobalUpgrade(address newImplementation);
    event CloneDeployed(address proxy, address indexed creator);
    event PublicDeploymentChanged(bool open);
    event SplitterDeployed(address indexed collection, address indexed splitter, address indexed creator);
    event MarketplaceSecurityConfigured(address indexed collection);
}
