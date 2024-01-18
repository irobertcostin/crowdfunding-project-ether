// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract CrowdfundingEther is ReentrancyGuard {
    address public owner;
    uint256 public fundTarget = 0.1 ether;
    uint256 public startTime = 1705608000;
    uint256 public endTime = 1705611600;

    mapping(address => uint256) public contributions;

    event Contribution(address indexed contributor, uint256 amount);
    event RefundClaimed(address indexed contributor, uint256 amount);
    event Withdrawal(uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    modifier isValidPhase() {
        require(
            block.timestamp >= startTime && block.timestamp <= endTime,
            "Invalid phase"
        );
        _;
    }

    modifier hasNotReachedTarget() {
        require(
            getTotalContributions() < fundTarget,
            "Fundraising target reached"
        );
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    receive() external payable {
        revert("Contract does not accept Ether directly");
    }

    function getCurrentPhase() external view returns (string memory) {
        if (block.timestamp < startTime) {
            return "Before Fundraising";
        } else if (block.timestamp <= endTime) {
            return "During Fundraising";
        } else {
            return "After Fundraising";
        }
    }

    function getRemainingTime() external view isValidPhase returns (uint256) {
        return endTime - block.timestamp;
    }

    function contribute()
        external
        payable
        isValidPhase
        hasNotReachedTarget
        nonReentrant
    {
        if (getTotalContributions() >= fundTarget) {
            revert("Funding target reached");
        }

        require(msg.value > 0, "Invalid contribution amount");

        uint256 remainingUntilTarget = fundTarget - getTotalContributions();
        uint256 userContribution = msg.value;
        uint256 differenceToBeRefunded;

        if (userContribution > remainingUntilTarget) {
            differenceToBeRefunded = userContribution - remainingUntilTarget;
            contributions[msg.sender] += remainingUntilTarget;
        } else {
            contributions[msg.sender] += msg.value;
        }

        emit Contribution(msg.sender, msg.value);

        if (differenceToBeRefunded > 0) {
            require(
                payable(msg.sender).send(differenceToBeRefunded),
                "Failed to send refund"
            );
        }
    }

    function getTotalContributions() public view returns (uint256) {
        return address(this).balance;
    }

    function claimRefund() external nonReentrant hasNotReachedTarget {
        require(
            block.timestamp > endTime && getTotalContributions() < fundTarget,
            "Either it's not the end of funding, or the fund target has been reached and deploy comes next"
        );

        uint256 refundAmount = contributions[msg.sender];

        require(refundAmount > 0, "No refund available");

        require(payable(msg.sender).send(refundAmount), "Something went wrong");

        contributions[msg.sender] = 0;
    }

    function withdrawFunds() external onlyOwner nonReentrant {
        require(
            block.timestamp > endTime && getTotalContributions() >= fundTarget,
            "Either it's not the end of funding, or the fund target hasn't been reached."
        );

        uint256 balance = getTotalContributions();
        require(payable(address(owner)).send(balance), "Something went wrong");
    }
}
