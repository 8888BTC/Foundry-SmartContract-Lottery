// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    event Raffle__RecentPlayers(address indexed player);
    event Raffle__RecentWinner(address indexed winner);

    uint256 enteranceFee;
    uint256 interval;
    bytes32 gaslane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address vrfCoordinator;
    address link;

    address public PLAYER = makeAddr("PLAYER");
    uint256 public constant STARING_VALUE = 10 ether;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();

        (
            enteranceFee,
            interval,
            gaslane,
            subscriptionId,
            callbackGasLimit,
            vrfCoordinator,
            link
        ) = helperConfig.activeNetworkConfig();

        vm.deal(PLAYER, STARING_VALUE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /////////////////////////////////////
    /////////// enterRaffle ////////////
    ///////////////////////////////////

    function testRevertFaildedIfNotEnoughSentEth() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughSentEth.selector);
        raffle.enterRaffle();
    }

    function testPlayerHasPushArrange() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
        assert(raffle.getPlayed(0) == PLAYER);
    }

    function testEmitMsgsenderAtWork() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Raffle__RecentPlayers(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
    }

    function testIfRaffleStateNotOpenRevert() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
    }

    /////////////////////////////////////
    /////////// checkUpneeded //////////
    ///////////////////////////////////

    function testIfContractStateIsCalculatingRvert() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep(""); // state is calculating;

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testIfTimeNotPassRevert() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + interval - 2);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testContractNotBalanceAndPlayerWhileIsORevert() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    /////////////////////////////////////
    ///////////performUpkeep ///////////
    ///////////////////////////////////

    function testCheckUpkeepCanOnlyapplyToPerformUpKeep() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");
    }

    function testPerformUpkeepIsRevertWhenCheckupNeededFalse() public {
        uint256 raffleState = 0;
        uint256 balance = 0;
        uint256 players = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__NotPerformUpkeep.selector,
                raffleState,
                balance,
                players
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepAtCalculatingIfCheckUpKeepTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");
        assert(uint256(raffle.getRaffleState()) == 1);
    }

    function testPerformUpkeepRequestIdIsCorrect() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        vm.recordLogs(); //把所有日志都保存了进来
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[1];

        assert(uint256(requestId) > 0);
    }

    /////////////////////////////////////
    /////////// FulfuilRandom //////////
    ///////////////////////////////////

    function testFulfuilRandomwordsCanOnlyAfterCheckUpAndPerformUpApply(
        uint256 randomRequestId
    ) public skipFork {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.expectRevert();
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfuilRandomWordsAtWorkAndPickWinnerResetArranySendBalanceToWinner()
        public
        skipFork
    {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        uint256 numberOfPlayers = 5;
        uint256 indexedOfPlayers = 1;
        for (
            uint256 i = indexedOfPlayers;
            i < indexedOfPlayers + numberOfPlayers;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARING_VALUE);
            raffle.enterRaffle{value: enteranceFee}(); // 5
        }
        uint256 prize = enteranceFee * (numberOfPlayers + 1);
        // uint256 money = enteranceFee * (numberOfPlayers + 1);
        //假装chainlink节点进行函数调用
        vm.recordLogs(); //把所有日志都保存了进来
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousLastTimestamp = raffle.getLastTimestamp();

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getPlayedLength() == 0);
        assert(address(raffle).balance == 0);
        assert(previousLastTimestamp < raffle.getLastTimestamp());

        assert(
            raffle.getRecentWinner().balance ==
                (STARING_VALUE + prize) - enteranceFee
        );
    }
}
