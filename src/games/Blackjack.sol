// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

contract Blackjack is Ownable, ReentrancyGuard, VRFConsumerBaseV2 {
    VRFCoordinatorV2Interface public coordinator;
    bytes32 public keyHash;
    uint64 public subId;
    uint32 public callbackGasLimit = 250_000;
    uint16 public reqConfirmations = 3;

    uint256 public ticketPrice;
    uint256 public creatorFeeBase;
    uint256 public currentRoundId;

    constructor(
        uint256 _ticketPrice,
        uint256 _creatorFeeBase,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId
    ) Ownable(msg.sender) VRFConsumerBaseV2(_vrfCoordinator) {
        require(_creatorFeeBase <= 2000, "creator fee too high");
        ticketPrice = _ticketPrice;
        creatorFeeBase = _creatorFeeBase;

        coordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        keyHash = _keyHash;
        subId = _subscriptionId;

        _startNewRound();
    }

    function _startNewRound() internal {}
}
