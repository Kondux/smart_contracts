// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.30;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import "./KonduxRoyaltySplitter.sol";
import "./interfaces/IKonduxRoyaltySplitter.sol";

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
