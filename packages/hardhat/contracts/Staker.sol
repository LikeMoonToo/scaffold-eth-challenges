// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {

  ExampleExternalContract public exampleExternalContract;

  mapping(address => uint256) public userBals;
  mapping(address => uint256) public userDepositTimeStamps;

  uint256 public constant rewardRatePerSecond = 0.01 ether;
  uint256 public withdrawalDeadline = block.timestamp + 5 minutes;
  uint256 public claimDeadline = block.timestamp + 10 minutes;
  uint256 public currentBlock = 0;


  event Stake(address indexed sender, uint256 amount);
  event Received(address, uint);
  event Execute(address indexed sender, uint256 amount);


  modifier isReachedWithdrawalDeadline( bool requireReached ) {
    uint256 timeLeft = withdrawalTimeLeft();
    if( requireReached ) {
      require(timeLeft == 0, "It's not time to allow withdrawals yet");
    } else {
      require(timeLeft > 0, "It's time to withdraw money");
    }
    _;
  }


  modifier isReachedClaimDeadline( bool requireReached ) {
    uint256 timeLeft = claimPeriodLeft();
    if( requireReached ) {
      require(timeLeft == 0, "It's not time to allow claiming yet");
    } else {
      require(timeLeft > 0, "It's time to claiming");
    }
    _;
  }

  
  modifier notCompleted() {
    bool completed = exampleExternalContract.completed();
    require(!completed, "The pledge campaign has ended!");
    _;
  }

  constructor(address exampleExternalContractAddress){
      exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
  }

  
  function stake() public payable isReachedWithdrawalDeadline(false) isReachedClaimDeadline(false){
    userBals[msg.sender] = userBals[msg.sender] + msg.value;
    userDepositTimeStamps[msg.sender] = block.timestamp;
    emit Stake(msg.sender, msg.value);
  }

  
  function withdraw() public isReachedWithdrawalDeadline(true) isReachedClaimDeadline(false) notCompleted{
    require(userBals[msg.sender] > 0, "You haven't deposited or withdrawn!");
    uint256 individualBalance = userBals[msg.sender];
    uint256 indBalanceRewards = individualBalance + ((block.timestamp-userDepositTimeStamps[msg.sender])*rewardRatePerSecond);
    userBals[msg.sender] = 0;

   
    (bool sent, bytes memory data) = msg.sender.call{value: indBalanceRewards}("");
    require(sent, "RIP; withdrawal failed :( ");
  }

 
  function execute() public isReachedClaimDeadline(true) notCompleted {
    uint256 contractBalance = address(this).balance;
    exampleExternalContract.complete{value: address(this).balance}();
  }

 
  function withdrawalTimeLeft() public view returns (uint256 withdrawalTimeLeft) {
    if( block.timestamp >= withdrawalDeadline) {
      return (0);
    } else {
      return (withdrawalDeadline - block.timestamp);
    }
  }

 
  function claimPeriodLeft() public view returns (uint256 claimPeriodLeft) {
    if( block.timestamp >= claimDeadline) {
      return (0);
    } else {
      return (claimDeadline - block.timestamp);
    }
  }

  
  function killTime() public {
    currentBlock = block.timestamp;
  }

  
  receive() external payable {
      emit Received(msg.sender, msg.value);
  }

}
