// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title A sample lottery Smart Contract
 * @author K8888
 */

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    error Raffle__NotEnoughSentEth();
    error Raffle__TransferIsFailed();
    error Raffle__NotOpen();
    error Raffle__NotPerformUpkeep(
        uint256 raffleState,
        uint256 balance,
        uint256 players
    );

    /** State variable */

    uint32 private constant NUM_WORDS = 1;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    uint256 private immutable i_enteranceFee;
    uint256 private immutable i_interval;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;

    address payable[] private s_players;
    uint256 private s_lastTimestamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    constructor(
        uint256 enteranceFee,
        uint256 interval,
        bytes32 gaslane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        address vrfCoordinator
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_enteranceFee = enteranceFee;
        i_interval = interval;
        i_gasLane = gaslane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);

        s_lastTimestamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    event Raffle__RecentPlayers(address indexed player);
    event Raffle__RecentWinner(address indexed winner);
    event Raffle__RequestId(uint256 indexed rqtId);

    function enterRaffle() external payable {
        if (msg.value < i_enteranceFee) {
            revert Raffle__NotEnoughSentEth();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }

        s_players.push(payable(msg.sender));
        emit Raffle__RecentPlayers(msg.sender);
    }

    /**
      @dev
     * 1.检查间隔时间是否足够
     * 2.检查合约状态是否是打开状态
     * 3.检查合约是否有参与者
     * 4.检查合约是否有钱
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool timeHasPassed = (block.timestamp - s_lastTimestamp) > i_interval;
        bool hasPlayer = s_players.length > 0;
        bool hasbalance = address(this).balance > 0;
        bool upkeepNeeds = isOpen && timeHasPassed && hasPlayer && hasbalance;
        return (upkeepNeeds, "0x");
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upkeepNeeds, ) = checkUpkeep("");
        if (!upkeepNeeds) {
            revert Raffle__NotPerformUpkeep(
                uint256(s_raffleState),
                address(this).balance,
                s_players.length
            );
        }
        s_raffleState = RaffleState.CALCULATING;
        uint256 rqtId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit Raffle__RequestId(rqtId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        //填充随机数组用%取出索引
        uint256 indexedOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexedOfWinner];
        s_recentWinner = winner;
        s_players = new address payable[](0);
        emit Raffle__RecentWinner(winner);
        s_raffleState = RaffleState.OPEN;
        s_lastTimestamp = block.timestamp;

        (bool sucess, ) = winner.call{value: address(this).balance}("");
        if (!sucess) {
            revert Raffle__TransferIsFailed();
        }
    }

    /** view/pure Funtion(getter) */

    function getEnteranceFee() public view returns (uint256) {
        return i_enteranceFee;
    }

    function getPlayed(uint256 indexedOfPlayers) public view returns (address) {
        return s_players[indexedOfPlayers];
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getLastTimestamp() public view returns (uint256) {
        return s_lastTimestamp;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayedLength() public view returns (uint256) {
        return s_players.length;
    }
}
