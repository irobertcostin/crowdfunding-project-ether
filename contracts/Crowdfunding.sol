// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./SafeMath.sol";

contract CrowdfundingEther is ReentrancyGuard {
    using SafeMath for uint256;

    address public owner;
    uint256 public fundTarget = 1 ether;
    uint256 public startTime = 1709060700;
    uint256 public endTime = 1709061300;
    bool public fundsWithdrawn;

    mapping(address => uint256) public contributions;

    event Contribution(address indexed contributor, uint256 amount);
    event RefundClaimed(address indexed contributor, uint256 amount);
    event Withdrawal(uint256 amount);

    modifier fundsNotWithdrawn() {
        require(!fundsWithdrawn, "Funds already withdrawn");
        _;
    }

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

    function contribute() external payable isValidPhase nonReentrant {
        require(msg.value > 0, "Invalid contribution amount");

        uint256 userContribution = msg.value;

        uint256 remainingUntilTarget = fundTarget.sub(
            getTotalContributions() - userContribution
        );

        require(
            remainingUntilTarget > 0,
            "Target has been reached, wait for launch."
        );

        uint256 differenceToBeRefunded;

        if (userContribution > remainingUntilTarget) {
            differenceToBeRefunded = userContribution.sub(remainingUntilTarget);
            contributions[msg.sender] = contributions[msg.sender].add(
                remainingUntilTarget
            );
        } else {
            contributions[msg.sender] = contributions[msg.sender].add(
                msg.value
            );
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

    function withdrawFunds() external onlyOwner nonReentrant fundsNotWithdrawn {
        require(
            block.timestamp > endTime && getTotalContributions() >= fundTarget,
            "Either it's not the end of funding, or the fund target hasn't been reached."
        );

        uint256 balance = getTotalContributions();
        require(payable(address(owner)).send(balance), "Something went wrong");
        fundsWithdrawn = true;
    }
}
