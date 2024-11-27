// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { UUPSUpgradeable } from '@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol';
import { OwnableUpgradeable } from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

/// @title Contract for Cellula miner staking
/// @author Cellula Team
contract MinerStaking is OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;
    // ======================== Variables ========================
    bool public status;
    address public devAddress;
    address public riskControlAddress;
    address public cellTokenAddress;

    uint256 public totalAmount;
    uint256 public minDepositValue;
    mapping(address => bool) public minerList;
    mapping(address => uint256) public minerDepositAmount;

    // ======================== Events ========================
    event SetMinerList(uint256 miners);
    event CancelMinerList(uint256 miners);
    event Deposit(address indexed miner, uint256 deposit_timestamp, uint256 amount);
    event Withdraw(address indexed miner, uint256 withdraw_timestamp, uint256 amount);
    event ChangeClaimable(bool old_status, bool new_status);
    event ChangeMinDepositValue(uint256 old_limit, uint256 new_limit);
    event ChangeDevAddress(address old_address, address new_address);
    event ChangeRiskControlAddress(address old_address, address new_address);
    event UnknownError(address caller, bytes data);

    // ======================== Constructor ========================
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner_, address dev_, address risk_control_, address cell_token_) external initializer {
        status = true;
        require(owner_ != address(0), 'invalid owner_ address');
        __Ownable_init(owner_);

        require(dev_ != address(0), 'invalid dev address');
        emit ChangeDevAddress(address(0), dev_);
        devAddress = dev_;

        require(risk_control_ != address(0), 'invalid risk_control address');
        emit ChangeRiskControlAddress(address(0), risk_control_);
        riskControlAddress = risk_control_;

        require(cell_token_ != address(0), 'invalid cell token address');
        cellTokenAddress = cell_token_;

        minDepositValue = 200_000e18;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    // ======================== MODIFIER ========================
    modifier onlyDev() {
        require(msg.sender == devAddress, 'not devAddress');
        _;
    }
    modifier onlyRiskControl() {
        require(msg.sender == riskControlAddress, 'not riskControlAddress');
        _;
    }

    // ======================== Limit Functions: For Owner ========================
    function setDevAddress(address dev_) public onlyOwner {
        require(dev_ != address(0), 'invalid address');
        emit ChangeDevAddress(devAddress, dev_);
        devAddress = dev_;
    }

    function setRiskControlAddress(address risk_control_) public onlyOwner {
        require(risk_control_ != address(0), 'invalid address');
        emit ChangeRiskControlAddress(riskControlAddress, risk_control_);
        riskControlAddress = risk_control_;
    }

    // ======================== Limit Functions: For Dev   ========================
    function setStatus(bool new_status) public onlyDev {
        if (status == new_status) return;
        emit ChangeClaimable(status, new_status);
        status = new_status;
    }

    function setMinDepositValue(uint256 new_limit) public onlyDev {
        if (minDepositValue == new_limit) return;
        emit ChangeMinDepositValue(minDepositValue, new_limit);
        minDepositValue = new_limit;
    }

    // ======================== Limit Functions: For Risk Control   ========================
    function setMinerList(address[] calldata _miners) public onlyRiskControl {
        uint256 leng = _miners.length;
        for (uint256 i; i < leng; ++i) {
            require(minerList[_miners[i]] == false, 'invalid address');
            minerList[_miners[i]] = true;
        }
        emit SetMinerList(leng);
    }

    function cancelMinerList(address[] calldata _miners) public onlyRiskControl {
        uint256 leng = _miners.length;
        for (uint256 i; i < leng; ++i) {
            require(minerList[_miners[i]] == true, 'invalid address');
            minerList[_miners[i]] = false;
        }
        emit CancelMinerList(leng);
    }

    // ======================== Functions ========================
    function deposit(uint256 amount) public {
        require(status, 'paused');
        require(minerList[msg.sender] == true, 'sender not in the minerList');
        require(amount >= minDepositValue, 'wrong amount');
        require(IERC20(cellTokenAddress).balanceOf(msg.sender) >= amount, 'insufficient balance');

        totalAmount += amount;
        minerDepositAmount[msg.sender] += amount;

        IERC20(cellTokenAddress).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, block.timestamp, amount);
    }

    function withdraw() public {
        require(status, 'paused');
        require(minerList[msg.sender] == false, 'sender needs to exit the minerList');
        require(minerDepositAmount[msg.sender] > 0, 'no amount to withdraw');

        uint256 amount = minerDepositAmount[msg.sender];
        minerDepositAmount[msg.sender] = 0;
        totalAmount -= amount;

        IERC20(cellTokenAddress).safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, block.timestamp, amount);
    }

    function isMiner(address miner_address) public view returns (bool) {
        return minerList[miner_address] && (minerDepositAmount[miner_address] >= minDepositValue);
    }

    // ======================== Fallback ========================
    fallback() external {
        emit UnknownError(msg.sender, msg.data);
    }
}
