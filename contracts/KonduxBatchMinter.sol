// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// ────────────────────────────────────────────────────────────
// OpenZeppelin helpers
// ────────────────────────────────────────────────────────────
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Address.sol";

// ────────────────────────────────────────────────────────────
// Minimal interfaces
// ────────────────────────────────────────────────────────────
interface IKondux {
    function MINTER_ROLE() external view returns (bytes32);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function safeMint(address to, uint256 dna) external returns (uint256);
}

interface IAuthority {
    function vault() external view returns (address);
}

/**
 * @title  KonduxBatchMinter
 * @notice Helper that validates an EIP‑712 authorisation, mints the requested
 *         kNFTs and **forwards all ETH to the current vault returned by an
 *         Authority contract**.
 */
contract KonduxBatchMinter is EIP712, ReentrancyGuard {
    using Address for address payable;

    /*════════════════════════ STATE ════════════════════════*/

    IKondux   public immutable kondux;
    IAuthority public immutable authority;

    /// Anti‑replay nonce per recipient
    mapping(address => uint256) public mintNonces;

    /// Type‑hash of the signed struct
    bytes32 private constant _MINT_TYPEHASH =
        keccak256(
            "MintAuthorisation(address recipient,bytes32 dnasHash,uint256 nonce,uint256 deadline,uint256 priceWei)"
        );

    /*═══════════════════════ EVENTS ═══════════════════════*/

    event AuthorisedMint(
        address indexed signer,
        address indexed recipient,
        uint256[] dnas,
        uint256 priceWei
    );

    /*════════════════════ CONSTRUCTOR ═════════════════════*/

    /**
     * @param konduxAddr    Address of the deployed Kondux contract
     * @param authorityAddr Address of the Authority contract that owns the vault
     */
    constructor(address konduxAddr, address authorityAddr)
        EIP712("Kondux kNFT", "1")
    {
        require(konduxAddr    != address(0), "Kondux addr zero");
        require(authorityAddr != address(0), "Authority addr zero");
        kondux    = IKondux(konduxAddr);
        authority = IAuthority(authorityAddr);
    }

    /*══════════════════════ PUBLIC API ════════════════════*/

    /**
     * @dev Payable, batch‑mint with EIP‑712 authorisation.
     *      Detailed docs are unchanged; only ETH forwarding differs.
     */
    function mintBatchWithSignature(
        address           recipient,
        uint256[] calldata dnas,
        uint256           deadline,
        uint256           priceWei,
        uint256           nonce,
        bytes   calldata  signature
    )
        external
        payable
        nonReentrant
    {
        /* ── Guards ──────────────────────────────────────── */
        require(dnas.length > 0,                 "kNFT: no DNAs");
        require(block.timestamp <= deadline,     "kNFT: auth expired");
        require(msg.value == priceWei,           "kNFT: wrong ETH");
        require(nonce == mintNonces[recipient],  "kNFT: bad nonce");

        /* ── EIP‑712 digest ─────────────────────────────── */
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    _MINT_TYPEHASH,
                    recipient,
                    keccak256(abi.encodePacked(dnas)),
                    nonce,
                    deadline,
                    priceWei
                )
            )
        );

        /* ── Signature check ────────────────────────────── */
        address signer = ECDSA.recover(digest, signature);
        require(
            kondux.hasRole(kondux.MINTER_ROLE(), signer),
            "kNFT: signer lacks MINTER_ROLE"
        );

        /* ── Burn nonce ─────────────────────────────────── */
        unchecked { mintNonces[recipient] = nonce + 1; }

        /* ── Mint loop ──────────────────────────────────── */
        for (uint256 i; i < dnas.length; ) {
            kondux.safeMint(recipient, dnas[i]);
            unchecked { ++i; }
        }

        /* ── Forward ETH to the vault ───────────────────── */
        address vault = authority.vault();
        require(vault != address(0), "kNFT: vault zero");
        payable(vault).sendValue(msg.value);

        emit AuthorisedMint(signer, recipient, dnas, priceWei);
    }
}
