// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./utils/DSTestPlus.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../UmbraBatchSend.sol";

interface UmbraToll {
  function toll() external returns(uint256);
  function setToll(uint256 _newToll) external;
  function owner() external view returns (address);
}

contract UmbraBatchSendTest is DSTestPlus {

    UmbraBatchSend public router = new UmbraBatchSend();
    
    address umbra = 0xFb2dc580Eed955B528407b4d36FfaFe3da685401;
    address dai = 0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735;

    address alice = address(0x202204);
    address bob = address(0x202205);

    uint256 alicePrevBal = alice.balance;
    uint256 bobPrevBal = bob.balance;
    uint256 umbraPrevBal;

    uint256 toll;

    bytes32 pkx = "pkx";
    bytes32 ciphertext = "ciphertext";   

    IERC20 token = IERC20(address(dai));
    UmbraBatchSend.SendEth[] sendEth;
    UmbraBatchSend.SendToken[] sendToken;

    function setUp() virtual public {

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(address(this), "UmbraBatchSendTest");

        umbraPrevBal = token.balanceOf(umbra);
        toll = UmbraToll(umbra).toll();

        tip(dai, address(this), type(uint256).max);
        vm.deal(address(this), type(uint256).max);
    }

    event Log(address indexed caller, uint256 indexed value, string message);

    function testFuzz_BatchSendEth(uint128 amount, uint128 amount2) public {

        vm.assume(amount > 0);
        vm.assume(amount2 > 0);
        vm.assume(amount > toll && amount2 > toll);

        sendEth.push(UmbraBatchSend.SendEth(payable(alice), amount, pkx, ciphertext));
        sendEth.push(UmbraBatchSend.SendEth(payable(bob), amount2, pkx, ciphertext));

        uint256 totalAmount = uint256(amount) + uint256(amount2) + (toll * sendEth.length);
        emit log_named_uint("total amount is", totalAmount);

        vm.expectCall(address(router), abi.encodeWithSelector(router.batchSendEth.selector, toll, sendEth));
        // vm.expectEmit(true, true, true, true);

        // emit Log(address(this),totalAmount, "called batchSendEth");
        router.batchSendEth{value: totalAmount}(toll, sendEth);

        assertEq(alice.balance, alicePrevBal + amount);
        assertEq(bob.balance, bobPrevBal + amount2);

    }

    function testFuzz_BatchSendTokens(uint128 amount, uint128 amount2) public {

        //         vm.assume(amount > 0);
        // vm.assume(amount2 > 0);

        uint256 totalAmount = uint256(amount) + uint256(amount2);


        sendToken.push(UmbraBatchSend.SendToken(alice, dai, amount, pkx, ciphertext));
        sendToken.push(UmbraBatchSend.SendToken(bob, dai, amount2, pkx, ciphertext));
        uint256 totalToll = toll *  sendToken.length;

        token.approve(address(router), totalAmount);

        vm.expectCall(address(router), abi.encodeWithSelector(router.batchSendTokens.selector, toll, sendToken));
        // vm.expectEmit(true, true, true, true);

        // emit Log(address(this), toll, "called batchSendTokens");
        router.batchSendTokens{value: totalToll}(toll, sendToken);

        assertEq(token.balanceOf(umbra), umbraPrevBal + totalAmount);

    }

    function testFuzz_BatchSend(uint128 amount, uint128 amount2) public {

        vm.assume(amount > 0);
        vm.assume(amount2 > 0);

        uint256 totalAmount = uint256(amount) + uint256(amount2);

        sendEth.push(UmbraBatchSend.SendEth(payable(alice), amount, pkx, ciphertext));
        sendEth.push(UmbraBatchSend.SendEth(payable(bob), amount2, pkx, ciphertext));

        sendToken.push(UmbraBatchSend.SendToken(alice, dai, amount, pkx, ciphertext));
        sendToken.push(UmbraBatchSend.SendToken(bob, dai, amount2, pkx, ciphertext));
        token.approve(address(router), totalAmount);

        vm.expectCall(address(router), abi.encodeWithSelector(router.batchSend.selector, toll, sendEth, sendToken));        
        vm.expectEmit(true, true, true, true);

        uint256 totalToll = toll * sendEth.length + toll * sendToken.length;
        emit Log(address(this), totalAmount + totalToll, "called batchSend");


        router.batchSend{value: totalAmount + totalToll}(toll, sendEth, sendToken);

        assertEq(alice.balance, alicePrevBal + amount);
        assertEq(bob.balance, bobPrevBal + amount2);

        assertEq(token.balanceOf(umbra), umbraPrevBal + totalAmount);

    }

}
