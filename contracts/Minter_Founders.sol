// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interfaces/IKonduxFounders.sol";
import "./interfaces/ITreasury.sol";
import "./types/AccessControlled.sol";

contract MinterFounders is AccessControlled {

    uint256 public price;
    uint256 public priceOG;
    uint256 public priceWL1;
    uint256 public priceWL2;
    uint256 public pricePublic;

    bytes32 public root;
    bytes32 public rootOG;
    bytes32 public rootWL1;
    bytes32 public rootWL2;

    bool public pausedWhitelist;
    bool public pausedOG;
    bool public pausedWL1;
    bool public pausedWL2;
    bool public pausedPublic;

    IKonduxFounders public immutable konduxFounders;
    ITreasury public immutable treasury;

    constructor(address _authority, address _konduxFounders, address _vault) 
        AccessControlled(IAuthority(_authority)) {        
            require(_konduxFounders != address(0), "Kondux address is not set");
            konduxFounders = IKonduxFounders(_konduxFounders);
            treasury = ITreasury(_vault);
            pausedWhitelist = false;
            pausedOG = false;
            pausedWL1 = false;
            pausedWL2 = false;
            pausedPublic = false;
    }      

    function setPrice(uint256 _price) public onlyGovernor {
        price = _price;
    }

    function setPriceOG(uint256 _price) public onlyGovernor {
        priceOG = _price;
    }

    function setPriceWL1(uint256 _price) public onlyGovernor {
        priceWL1 = _price;
    }

    function setPriceWL2(uint256 _price) public onlyGovernor {
        priceWL2 = _price;
    }

    function setPricePublic(uint256 _price) public onlyGovernor {
        priceWL2 = _price;
    }

    function setPausedWhitelist(bool _paused) public onlyGovernor {
        pausedWhitelist = _paused;
    }

    function setPausedOG(bool _paused) public onlyGovernor {
        pausedOG = _paused;
    }

    function setPausedWL1(bool _paused) public onlyGovernor {
        pausedWL1 = _paused;
    }

    function setPausedWL2(bool _paused) public onlyGovernor {
        pausedWL2 = _paused;
    }

    function setPausedPublic(bool _paused) public onlyGovernor {
        pausedPublic = _paused;
    }

    function whitelistMint(bytes32[] calldata _merkleProof) public payable isWhitelistActive returns (uint256) {
        require(msg.value >= price, "Not enought ether");
        treasury.depositEther{ value: msg.value }();
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_merkleProof, root, leaf), "Incorrect proof");
        return _mint();
    }

    function whitelistMintOG(bytes32[] calldata _merkleProof) public payable isOGActive returns (uint256) {
        require(msg.value >= priceOG, "Not enought ether");
        treasury.depositEther{ value: msg.value }();
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_merkleProof, rootOG, leaf), "Incorrect proof");
        return _mint();
    }

    function whitelistMintWL1(bytes32[] calldata _merkleProof) public payable isWL1Active returns (uint256) {
        require(msg.value >= priceWL1, "Not enought ether");
        treasury.depositEther{ value: msg.value }();
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_merkleProof, rootWL1, leaf), "Incorrect proof");
        return _mint();
    }

    function whitelistMintWL2(bytes32[] calldata _merkleProof) public payable isWL2Active returns (uint256) {
        require(msg.value >= priceWL2, "Not enought ether");
        treasury.depositEther{ value: msg.value }();
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_merkleProof, rootWL2, leaf), "Incorrect proof");
        return _mint();
    }

    function publicMint() public payable isPublicActive returns (uint256) {
        require(msg.value >= pricePublic, "Not enought ether");
        treasury.depositEther{ value: msg.value }();
        return _mint();
    }

    function setRoot(bytes32 _root) public onlyGovernor {
        root = _root;
    }

    function setRootOG(bytes32 _rootOG) public onlyGovernor {
        rootOG = _rootOG;
    }

    function setRootWL1(bytes32 _rootWL1) public onlyGovernor {
        rootWL1 = _rootWL1;
    }

    function setRootWL2(bytes32 _rootWL2) public onlyGovernor {
        rootWL2 = _rootWL2;
    }

    // ** INTERNAL FUNCTIONS **

    function _mint() internal returns (uint256) {
        uint256 id = konduxFounders.automaticMint(msg.sender);
        return id;
    }

    // ** MODIFIERS **

    modifier isWhitelistActive() {
        require(!pausedWhitelist, "Whitelist minting is paused");
        _;
    }

    modifier isOGActive() {
        require(!pausedOG, "OG minting is paused");
        _;
    }

    modifier isWL1Active() {
        require(!pausedWL1, "WL1 minting is paused");
        _;
    }

    modifier isWL2Active() {
        require(!pausedWL2, "WL2 minting is paused");
        _;
    }

    modifier isPublicActive() {
        require(!pausedPublic, "Public minting is paused");
        _;
    }

}