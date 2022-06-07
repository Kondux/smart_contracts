// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./types/AccessControlled.sol";

contract Treasury is AccessControlled {

    /* ========== EVENTS ========== */

    event Deposit(address indexed token, uint256 amount);
    event DepositEther(uint256 amount);
    event EtherDeposit(uint256 amount);
    event Withdrawal(address indexed token, uint256 amount);
    event EtherWithdrawal(uint256 amount);

    /* ========== DATA STRUCTURES ========== */

    enum STATUS {
        RESERVEDEPOSITOR,
        RESERVESPENDER,
        RESERVETOKEN
    }

    /* ========== STATE VARIABLES ========== */

    IERC20 public immutable Kondux;


    string internal notAccepted = "Treasury: not accepted";
    string internal notApproved = "Treasury: not approved";
    string internal invalidToken = "Treasury: invalid token";

    mapping(STATUS => mapping(address => bool)) public permissions;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _authority,
        address _kondux
    ) AccessControlled(IAuthority(_authority)) {
        require(_kondux != address(0), "Zero address: Kondux");
        Kondux = IERC20(_kondux);
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

        IERC20(_token).transferFrom(msg.sender, address(this), _amount);      

        emit Deposit(_token, _amount);
    }

    function depositEther (
        uint256 _amount
    ) external payable {
        require(permissions[STATUS.RESERVEDEPOSITOR][msg.sender], notApproved);                
                
        emit DepositEther(_amount);
    }

    /**
     * @notice allow approved address to withdraw Kondux from reserves
     * @param _amount uint256
     * @param _token address
     */
    function withdraw(uint256 _amount, address _token) external {
        require(permissions[STATUS.RESERVETOKEN][_token], notAccepted); // Only reserves can be used for redemptions
        require(permissions[STATUS.RESERVESPENDER][msg.sender], notApproved);

        IERC20(_token).transferFrom(address(this), msg.sender, _amount);

        emit Withdrawal(_token, _amount);
    }

    receive() external payable {
        require(permissions[STATUS.RESERVEDEPOSITOR][msg.sender], notApproved);
        emit EtherDeposit(msg.value);
    }
    
    function withdrawEther(uint _amount) external {
        require(permissions[STATUS.RESERVESPENDER][msg.sender], notApproved);
        require(payable(msg.sender).send(_amount));

        emit EtherWithdrawal(_amount);
    }

    function setPermission(
        STATUS _status,
        address _address,
        bool _permission
    ) public onlyGovernor {
        permissions[_status][_address] = _permission;
    }
}