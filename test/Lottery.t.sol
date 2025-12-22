// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/games/Lottery.sol";
import "./mocks/VRFCoordinatorV2Mock.sol";

contract LotteryTest is Test {
    Lottery lottery;
    VRFCoordinatorV2Mock vrf;

    // test
    address owner = address(1);
    address playerA = address(2);
    address playerB = address(3);

    uint64 subId;

    function setUp() public {
        vm.startPrank(owner);

        // 1. create VRF mock
        vrf = new VRFCoordinatorV2Mock(
            0.1 ether, // base fee
            1e9 // gas price link
        );

        subId = vrf.createSubscription();

        // 3. Добавляем деньги на subscription
        vrf.fundSubscription(subId, 10 ether);

        // 4. Деплоим Lottery
        lottery = new Lottery(
            0.01 ether, // ticketPrice
            500, // 5% fee
            address(vrf),
            bytes32(0), // mock keyHash, не важно
            subId
        );

        // 5. Указываем контракт как consumer
        vrf.addConsumer(subId, address(lottery));

        vm.stopPrank();
    }

    function testBuyTickets() public {
        vm.deal(playerA, 10 ether);

        vm.prank(playerA);
        lottery.buyTickets{value: 0.03 ether}(3);

        // Проверим состояние раунда
        (uint256 pot, uint256 ticketsSold, , , , , ) = lottery.rounds(
            lottery.currentRoundId()
        );
        assertEq(pot, 0.03 ether);
        assertEq(ticketsSold, 3);

        // Проверим кто купил билеты
        address[] memory tickets = lottery.getRoundTickets(
            lottery.currentRoundId()
        );
        assertEq(tickets.length, 3);
        assertEq(tickets[0], playerA);
        assertEq(tickets[1], playerA);
    }

    function testPickWinner() public {
        // Player A покупает билет
        vm.deal(playerA, 1 ether);
        vm.prank(playerA);
        lottery.buyTickets{value: 0.01 ether}(1);

        // Player B покупает билет
        vm.deal(playerB, 1 ether);
        vm.prank(playerB);
        lottery.buyTickets{value: 0.01 ether}(1);

        uint256 potBefore = address(lottery).balance;

        // Owner закрывает раунд → запрос VRF
        vm.prank(owner);
        uint256 requestId = lottery.closeRound();

        // ТЕПЕРЬ ДЕЛАЕМ fulfillment
        // VRF mock вызывает fulfillRandomWords вручную:
        vrf.fulfillRandomWords(requestId, address(lottery));

        // Проверим, что раунд завершён
        uint256 finishedRound = lottery.currentRoundId() - 1;
        (, , address winner, , , , ) = lottery.rounds(finishedRound);

        assertTrue(
            winner == playerA || winner == playerB,
            "winner must be A or B"
        );

        // Проверим что pot = 0
        (uint256 pot, , , , , ,) = lottery.rounds(finishedRound);
        assertEq(pot, 0);
    }

    function testPayouts() public {
        vm.deal(playerA, 1 ether);
        vm.prank(playerA);
        lottery.buyTickets{value: 0.03 ether}(3);

        vm.prank(owner);
        uint256 req = lottery.closeRound();

        // balances before
        uint256 ownerBalBefore = owner.balance;
        uint256 playerABalBefore = playerA.balance;

        // fulfill
        vrf.fulfillRandomWords(req, address(lottery));

        // houseFee = 5% от 0.03 ETH = 0.0015 ETH
        uint256 expectedFee = (0.03 ether * 500) / 10000;

        assertEq(owner.balance, ownerBalBefore + expectedFee);

        // приз = pot - fee
        uint256 expectedPrize = 0.03 ether - expectedFee;

        // поскольку A единственный игрок — он выиграет
        assertEq(playerA.balance, playerABalBefore + expectedPrize);
    }

    function testNewRoundStartsOpen() public {
        vm.deal(playerA, 1 ether);
        vm.prank(playerA);
        lottery.buyTickets{value: 0.01 ether}(1);

        vm.prank(owner);
        uint256 req = lottery.closeRound();
        vrf.fulfillRandomWords(req, address(lottery));

        uint256 newRound = lottery.currentRoundId();

        (, uint256 ticketsSold, , , , ,) = lottery.rounds(newRound);
        assertEq(ticketsSold, 0);
    }
}
