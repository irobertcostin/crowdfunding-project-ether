// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract CrowdfundingEther is ReentrancyGuard {
    address public owner;
    uint256 public fundTarget = 0.1 ether;
    uint256 public startTime = 1705240800;
    uint256 public endTime = 1705327200;
    uint256 public totalContributions;

    struct ContributionInfo {
        address contributor;
        uint256 amount;
    }

    ContributionInfo[] public contributions;

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
    };


    function getCurrentPhase() external view returns (string memory) {
        if (block.timestamp < startTime) {
            return "Before Fundraising";
        } else if (block.timestamp <= endTime) {
            return "During Fundraising";
        } else {
            return "After Fundraising";
        }
    };

    function getRemainingTime() external view isValidPhase returns (uint256) {
        return endTime - block.timestamp;
    };

    function contribute(
        uint256 amount,
    )
        external
        public
        payable
        isValidPhase
        hasNotReachedTarget
        nonReentrant
    {
        if (getTotalContributions() >= fundTarget) {
            revert("Funding target reached");
        }

        require(msg.value == amount, "Invalid contribution amount");
        


        uint256 remainingUntilTarget = fundTarget - getTotalContributions();
        uint256 userContribution = msg.value;
        uint256 differenceToBeRefunded;


        if (userContribution > remainingUntilTarget) {
            differenceToBeRefunded = userContribution - remainingUntilTarget;
        }

        bool alreadyExists=false;

        for(uint256 i=0;i<contributions.length;i++){
            if(contributions[i].contributor==msg.sender){
                contributions[i].amount+=msg.value;
                alreadyExists=true;
            }
        }

        if(alreadyExists==false){
            contributions.push(ContributionInfo({
            contributor: msg.sender,
            amount:msg.value
        }))
        }

        totalContributions += msg.value;

        emit Contribution(msg.sender, msg.value);

        if (differenceToBeRefunded > 0) {
            require(payable(msg.sender).send(differenceToBeRefunded), "Failed to send refund");
            
            for (uint256 i = 0; i < contributions.length; i++) {
            if (contributions[i].contributor == msg.sender) {
            contributions[i].amount -= differenceToBeRefunded;
            break;
        }
    }
        }
    };

    function getTotalContributions() public view returns (uint256) {
        uint256 totalContributions;
        for (uint256 i = 0; i < contributions.length; i++) {
            totalContributions += contributions[i].amount;
        }
        return totalContributions;
    };

    function claimRefund() external nonReentrant hasNotReachedTarget {
        require(
            block.timestamp > endTime && getTotalContributions() < fundTarget,
            "Either it's not the end of funding, or the fund target has been reached and deploy comes next"
        );

        uint256 refundAmount;

        for (uint256 i = 0; i < contributions.length; i++) {
        if (contributions[i].contributor == msg.sender) {
        refundAmount = contributions[i].amount;
        require(refundAmount > 0, "No refund available");

        require(payable(msg.sender).send(refundAmount),"Something went wrong");
        contributions[i].amount = 0;
        }
    }
};

    function withdrawFunds() external onlyOwner nonReentrant {
        require(
            block.timestamp > endTime && getTotalContributions() >= fundTarget,
            "Either it's not the end of funding, or the fund target hasn't been reached."
        );

        uint256 balance = getTotalContributions();
        require(payable(owner).transfer(balance),"Something went wrong");
    };
}
