// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interfaces/IKonduxERC20.sol";
import "./types/AccessControlled.sol";

// import "hardhat/console.sol";

contract Treasury is AccessControlled {

    /* ========== EVENTS ========== */

    event Deposit(address indexed token, uint256 amount);
    event DepositEther(uint256 amount);
    event EtherDeposit(uint256 amount);
    event Withdrawal(address indexed token, uint256 amount);
    event EtherWithdrawal(address to, uint256 amount);

    /* ========== DATA STRUCTURES ========== */

    enum STATUS {
        RESERVEDEPOSITOR,
        RESERVESPENDER,
        RESERVETOKEN
    }

    /* ========== STATE VARIABLES ========== */

    string internal notAccepted = "Treasury: not accepted";
    string internal notApproved = "Treasury: not approved";
    string internal invalidToken = "Treasury: invalid token";

    mapping(STATUS => mapping(address => bool)) public permissions;
    mapping(address => bool) public isTokenApprooved;
    mapping(address => IKonduxERC20) public approvedTokens;

    address[] public approvedTokensList;
    uint256 public approvedTokensCount;

    address public stakingContract;

    /* ========== CONSTRUCTOR ========== */

    constructor(address _authority) AccessControlled(IAuthority(_authority)) {
        approvedTokensCount = 0;
    }


    /**
     * @notice allow approved address to deposit an asset for Kondux
     * @param _amount uint256
     * @param _token address
     */
    function deposit(
        uint256 _amount,
        address _token
    ) external {
        if (permissions[STATUS.RESERVETOKEN][_token]) {
            require(permissions[STATUS.RESERVEDEPOSITOR][msg.sender], notApproved);
        } else {
            revert(invalidToken);
        }

        // console.log(msg.sender);
        // console.log(tx.origin);
        IKonduxERC20(_token).transferFrom(tx.origin, address(this), _amount);
        IKonduxERC20(_token).increaseAllowance(stakingContract, _amount);
        uint256 allowance = IKonduxERC20(_token).allowance(address(this), stakingContract);
        // console.log("Allowance (deposit): %s", allowance);  

        emit Deposit(_token, _amount);
    }

    function depositEther () external payable {
        require(permissions[STATUS.RESERVEDEPOSITOR][msg.sender], notApproved);  
        // console.log("Deposit Ether: %s", msg.value);              
                
        emit DepositEther(msg.value);
    }

    /**
     * @notice allow approved address to withdraw Kondux from reserves
     * @param _amount uint256
     * @param _token address
     */
    function withdraw(uint256 _amount, address _token) external {
        require(permissions[STATUS.RESERVETOKEN][_token], notAccepted); // Only reserves can be used for redemptions
        require(permissions[STATUS.RESERVESPENDER][msg.sender], notApproved);

        IKonduxERC20(_token).transferFrom(address(this), msg.sender, _amount);

        emit Withdrawal(_token, _amount);
    }

    function withdrawTo(uint256 _amount, address _token, address _to) external  {
        require(permissions[STATUS.RESERVETOKEN][_token], notAccepted); // Only reserves can be used for redemptions
        require(permissions[STATUS.RESERVESPENDER][msg.sender], notApproved);

        // console.log("WithdrawTo: ", _to);
        // console.log("Msg.sender: ", msg.sender);
        // console.log("Tx.origin: ", tx.origin);
        uint256 allowance = IKonduxERC20(_token).allowance(address(this), msg.sender);
        // console.log("WithdrawTo Allowance: %s", allowance);
        // console.log("balanceOf: %s", IKonduxERC20(_token).balanceOf(address(this)));
        // console.log("amount: %s", _amount);
        // console.log("address this: %s", address(this));  

        IKonduxERC20(_token).transferFrom(address(this), _to, _amount);
        // console.log("balanceOf after: %s", IKonduxERC20(_token).balanceOf(address(this)));

        emit Withdrawal(_token, _amount);
    }

    receive() external payable {
        // console.log("Received Ether: %s", msg.value);
        emit EtherDeposit(msg.value);
    }

    fallback() external payable { 
        // console.log("Fallback Ether: %s", msg.value);
        emit EtherDeposit(msg.value); 
    }
    
    function withdrawEther(uint _amount) external {
        require(permissions[STATUS.RESERVESPENDER][msg.sender], notApproved);
        require(payable(msg.sender).send(_amount));

        emit EtherWithdrawal(msg.sender, _amount);
    }

    function setPermission(
        STATUS _status,
        address _address,
        bool _permission
    ) public onlyGovernor {
        permissions[_status][_address] = _permission;
        if (_status == STATUS.RESERVETOKEN) {
            isTokenApprooved[_address] = _permission;
            if (_permission) {
                approvedTokens[_address] = IKonduxERC20(_address);
                approvedTokensList.push(_address);
                approvedTokensCount++;                
            }
        }
    }

    function setStakingContract(address _stakingContract) public onlyGovernor {
        stakingContract = _stakingContract;
    }

    function erc20ApprovalSetup(address _token, uint256 _amount) public onlyGovernor {
        IKonduxERC20(_token).approve(address(this), _amount);
    }
}