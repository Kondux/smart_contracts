// SPDX‑License‑Identifier: GPL‑3.0
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

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

    UpgradeableBeacon public immutable beacon;
    bool public publicDeployment = true;   // open by default

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
        emit CloneDeployed(proxy, msg.sender);
    }

    /*-------------------------------------------------------------*/
    /* Events                                                      */
    /*-------------------------------------------------------------*/
    event GlobalUpgrade(address newImplementation);
    event CloneDeployed(address proxy, address indexed creator);
    event PublicDeploymentChanged(bool open);
}
