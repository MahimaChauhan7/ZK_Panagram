
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Panagram, IVerifier} from "../src/Panagram.sol";
import {HonkVerifier } from "../src/Verifier.sol";

contract PanagramTest is Test {
    HonkVerifier verifier;
    Panagram panagram;

    uint256 constant FIELD_MODULUS = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    bytes32 constant ANSWER = bytes32(uint256(keccak256(abi.encodePacked(bytes32(uint256(keccak256("triangles")) % FIELD_MODULUS)))) % FIELD_MODULUS);
    bytes32 constant CORRECT_GUESS = bytes32(uint256(keccak256("triangles")) % FIELD_MODULUS);
    bytes proof;
    bytes32[] publicInputs;

    address user = makeAddr("user");

    function setUp() public {
        verifier = new HonkVerifier();
        panagram = new Panagram(IVerifier(address(verifier)));

        panagram.newRound(ANSWER);
        proof = _getProof(CORRECT_GUESS, ANSWER, user);
    }

    function _getProof(bytes32 guess, bytes32 correctAnswer, address _user) internal returns (bytes memory _proof) {
        uint256 NUM_ARGS = 6;
        string[] memory inputs = new string[](NUM_ARGS);
        inputs[0] = "npx";
        inputs[1] = "tsx";
        inputs[2] = "js-scripts/generate-proofs.ts";
        inputs[3] = vm.toString(guess);
        inputs[4] = vm.toString(correctAnswer);
        inputs[5] = vm.toString(bytes32(uint256(uint160(_user))));

        bytes memory result = vm.ffi(inputs);
        (_proof, /*_publicInputs*/) =
            abi.decode(result, (bytes, bytes32[]));
    }

    function testCorrectGuessPasses() public {
        vm.prank(user);
        panagram.makeGuess(proof);
        vm.assertEq(panagram.balanceOf(user, 0), 1); 
        vm.assertEq(panagram.balanceOf(user, 1), 0);

        // check they can't try again
        vm.prank(user);
        vm.expectRevert();
        panagram.makeGuess(proof);
    }

    function testStartNewRound() public {
        // start a round (in setUp)
        // get a winner
        vm.prank(user);
        panagram.makeGuess(proof);
        // min time passed
        vm.warp(panagram.MIN_DURATION() + 1);
        // start a new round
        panagram.newRound(bytes32(uint256(keccak256(abi.encodePacked(bytes32(uint256(keccak256("abcdefghi")) % FIELD_MODULUS)))) % FIELD_MODULUS));
        // validate the state has reset
        vm.assertEq(panagram.getCurrentPanagram(), bytes32(uint256(keccak256(abi.encodePacked(bytes32(uint256(keccak256("abcdefghi")) % FIELD_MODULUS)))) % FIELD_MODULUS));
        vm.assertEq(panagram.getCurrentRoundStatus(), address(0));
        vm.assertEq(panagram.s_currentRound(), 2);
    }

    function testIncorrectGuessFails() public {
        bytes32 INCORRECT_ANSWER = bytes32(uint256(keccak256(abi.encodePacked(bytes32(uint256(keccak256("outnumber")) % FIELD_MODULUS)))) % FIELD_MODULUS);
        bytes32 INCORRECT_GUESS = bytes32(uint256(keccak256("outnumber")) % FIELD_MODULUS);
        bytes memory incorrectProof = _getProof(INCORRECT_GUESS, INCORRECT_ANSWER, user);
        vm.prank(user);
        vm.expectRevert();
        panagram.makeGuess(incorrectProof);
    }

    function testSecondWinnerPasses() public {
        address user2 = makeAddr("user2");
        vm.prank(user);
        panagram.makeGuess(proof);
        vm.assertEq(panagram.balanceOf(user, 0), 1); // they did nft 1
        vm.assertEq(panagram.balanceOf(user, 1), 0);

        bytes memory proof2 = _getProof(CORRECT_GUESS, ANSWER, user2);
        vm.prank(user2);
        panagram.makeGuess(proof2);
        vm.assertEq(panagram.balanceOf(user2, 0), 0);
        vm.assertEq(panagram.balanceOf(user2, 1), 1);
    }
}
//@e So anyone can see the proof in the mempool and can use it for getting the nft.