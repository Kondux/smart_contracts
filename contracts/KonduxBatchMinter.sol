// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// ────────────────────────────────────────────────────────────
// OpenZeppelin helpers
// ────────────────────────────────────────────────────────────
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IKondux.sol";
import "./interfaces/IAuthority.sol";

// ────────────────────────────────────────────────────────────
// Minimal interfaces
// ────────────────────────────────────────────────────────────

/** 
 * @title  KonduxBatchMinter
 * @notice Helper that validates an EIP‑712 authorisation, mints the requested
 *         kNFTs and **forwards all ETH to the current vault returned by an
 *         Authority contract**.
 *
 *         ‑ Signature must come from an address holding `BATCH_MINTER_ROLE`
 *           *inside this contract* (not in Kondux).
 */
contract KonduxBatchMinter is
    EIP712,
    AccessControl,
    ReentrancyGuard
{
    using Address for address payable;

    /*════════════════════════ STATE ════════════════════════*/

    bytes32 public constant BATCH_MINTER_ROLE = keccak256("BATCH_MINTER_ROLE");

    IKondux    public immutable kondux;
    IAuthority public immutable authority;

    bool public paused;

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
     * @notice Initializes the contract with the Kondux collection address and authority.
     * @param konduxAddr   Address of the Kondux collection contract.
     * @param authorityAddr Address of the authority contract.
     */
    constructor(address konduxAddr, address authorityAddr)
        EIP712("Kondux kNFT", "1")
    {
        require(konduxAddr    != address(0), "Kondux addr zero");
        require(authorityAddr != address(0), "Authority addr zero");

        kondux    = IKondux(konduxAddr);
        authority = IAuthority(authorityAddr);

        /* AccessControl bootstrap */
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BATCH_MINTER_ROLE,  msg.sender);
    }

    /*═══════════════════════ MODIFIERS ═════════════════════*/
    /**
     * @notice Guard to ensure the contract is not paused.
     * @dev    This modifier checks the `paused` state variable and reverts
     *         if the contract is paused.
     */
    modifier _pausedGuard() {
        require(!paused, "kNFT: paused");
        _;        
    }

    /*══════════════════════ PUBLIC API ════════════════════*/

    /**
     * @notice Mint a batch of kNFTs with a signed authorisation.
     * @dev    This function allows a recipient to mint multiple kNFTs in a single
     *         transaction, provided they have a valid EIP‑712 signature authorising
     *         them.
     *         The signature must be signed by an address that holds the `BATCH_MINTER_ROLE`
     *         in this contract, not in the Kondux collection contract.
     *         The function checks that the provided `deadline` has not passed, and that
     *         the `priceWei` matches the amount of ETH sent with the transaction.
     *         The `nonce` is used to prevent replay attacks; it must match the current
     *         nonce for the recipient, which is incremented after a successful mint.
     * @param recipient  Address to mint the kNFTs to.
     * @param dnas       Array of kNFT DNAs to mint.
     * @param deadline   Timestamp after which the authorisation is invalid.
     * @param priceWei   Price in wei to pay for the minting.
     * @param nonce      Anti‑replay nonce for this recipient.
     * @param signature  EIP‑712 signature of the authorisation.
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
        _pausedGuard
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

        /* ── Signature check (LOCAL role) ───────────────── */
        address signer = ECDSA.recover(digest, signature);
        require(
            hasRole(BATCH_MINTER_ROLE, signer),
            "kNFT: signer lacks BATCH_MINTER_ROLE"
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

    function previewDigest(
        address recipient,
        uint256[] calldata dnas,
        uint256 nonce,
        uint256 deadline,
        uint256 priceWei
    ) external view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(abi.encode(
                _MINT_TYPEHASH,
                recipient,
                keccak256(abi.encodePacked(dnas)),
                nonce,
                deadline,
                priceWei
            ))
        );
    }

    function previewSigner(
        address recipient,
        uint256[] calldata dnas,
        uint256 nonce,
        uint256 deadline,
        uint256 priceWei,
        bytes calldata signature
    ) external view returns (address signer, bool hasBatchRole) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(
                _MINT_TYPEHASH,
                recipient,
                keccak256(abi.encodePacked(dnas)),
                nonce,
                deadline,
                priceWei
            ))
        );
        signer = ECDSA.recover(digest, signature);
        hasBatchRole = hasRole(BATCH_MINTER_ROLE, signer);
    }

    function previewDnasHash(uint256[] calldata dnas) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(dnas));
    }


    // ── Admin functions ────────────────────────────── */
    /**
     * @notice Set the paused state of the contract.
     * @param _paused  New paused state.
     */
    function setPaused(bool _paused) external onlyRole(DEFAULT_ADMIN_ROLE) {
        paused = _paused;
    }
}
