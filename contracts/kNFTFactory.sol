// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./Kondux_NFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IFactoryConfig.sol";


/* ---------- minimal Authority interface (vault lookup only) ------------- */
interface IAuthority {
    function vault() external view returns (address);
}

/**
 * @title kNFTFactoryV2 ‑ tiny deploy‑only factory
 * @dev All mutable knobs live in kNFTFactoryConfig.
 */
contract kNFTFactoryV2 is Ownable {
    /* --------------------------------------------------------------------- */
    /*  immutable constructor params (packed once into byte‑code, not storage)*/
    /* --------------------------------------------------------------------- */
    IAuthority public immutable authority;
    address    public immutable foundersPass;
    address    public immutable WETH;
    address    public immutable KNDX;
    address    public immutable uniswapV2Pair;

    IFactoryConfig public config;          // upgradable pointer (1 storage slot)

    /* -------------------------------- events ----------------------------- */
    event KonduxDeployed(address indexed collection, address indexed creator);
    event ConfigUpgraded(address indexed newConfig);

    /* ------------------------------ errors ------------------------------- */
    error FactoryOff();
    error NotOwner();
    error FeeLow();
    error FeeForward();
    error FeeNotRequired();
    error ZeroAddress();

    /* --------------------------- constructor ----------------------------- */
    constructor(
        IAuthority      _authority,
        IFactoryConfig  _config,
        address         _weth,
        address         _kndx,
        address         _foundersPass,
        address         _uniswapV2Pair
    ) Ownable(msg.sender) {
        if (
            address(_authority)    == address(0) ||
            address(_config)       == address(0) ||
            _weth                  == address(0) ||
            _kndx                  == address(0) ||
            _foundersPass          == address(0) ||
            _uniswapV2Pair         == address(0)
        ) revert ZeroAddress();

        authority      = _authority;
        config         = _config;
        WETH           = _weth;
        KNDX           = _kndx;
        foundersPass   = _foundersPass;
        uniswapV2Pair  = _uniswapV2Pair;
    }

    /* ------------------------- main entry‑point -------------------------- */
    function createKondux(string calldata name, string calldata symbol)
        external
        payable
        returns (address)
    {
        /* 1) basic gates */
        if (!config.factoryActive()) revert FactoryOff();
        if (config.restricted() && msg.sender != owner()) revert NotOwner();

        /* 2) fee logic */
        if (config.feeEnabled() && !config.freeCreators(msg.sender)) {
            uint256 fee = config.creationFee();
            if (msg.value < fee) revert FeeLow();
            (bool ok, ) = authority.vault().call{value: msg.value}("");
            if (!ok) revert FeeForward();
        } else if (msg.value != 0) {
            revert FeeNotRequired();
        }

        /* 3) deploy collection */
        Kondux collection = new Kondux(
            name,
            symbol,
            uniswapV2Pair,
            WETH,
            KNDX,
            foundersPass,
            authority.vault(),
            0                // maxSupply = infinite
        );

        /* 4) hand roles to creator, revoke factory */
        collection.setRole(collection.DEFAULT_ADMIN_ROLE(), msg.sender, true);
        collection.setRole(collection.MINTER_ROLE(),        msg.sender, true);
        collection.setRole(collection.DNA_MODIFIER_ROLE(),  msg.sender, true);

        collection.setRole(collection.DEFAULT_ADMIN_ROLE(), address(this), false);
        collection.setRole(collection.MINTER_ROLE(),        address(this), false);
        collection.setRole(collection.DNA_MODIFIER_ROLE(),  address(this), false);

        emit KonduxDeployed(address(collection), msg.sender);
        return address(collection);
    }

    /* -------------------------- config upgrade --------------------------- */
    function upgradeConfig(IFactoryConfig newCfg) external onlyOwner {
        if (address(newCfg) == address(0)) revert ZeroAddress();
        config = newCfg;
        emit ConfigUpgraded(address(newCfg));
    }

    /* --------------- refuse stray ether & unknown selectors -------------- */
    receive() external payable { revert(); }
    fallback() external payable { revert(); }
}
