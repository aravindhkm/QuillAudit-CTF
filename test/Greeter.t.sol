// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {WETH10} from "src/WETH10.sol";

contract Weth10Test is Test {
    WETH10 public weth;
    address owner;
    address bob;

    function setUp() public {
        weth = new WETH10();
        bob = makeAddr("bob");

        vm.deal(address(weth), 10 ether);
        vm.deal(address(bob), 1 ether);
        console2.log("addr", weth.data());
        console2.log("addr two", weth.callData());
        console2.log("test", weth.test(),weth.totalSupply());
    }

    function testHack() public {
        assertEq(address(weth).balance, 10 ether, "weth contract should have 10 ether");


        vm.startPrank(bob);

        // hack time!
        weth.withdraw(10 ether);

        vm.stopPrank();
        console2.log("balance", address(weth).balance);

        // assertEq(address(weth).balance, 0, "empty weth contract");
        // assertEq(bob.balance, 11 ether, "player should end with 11 ether");
    }
}