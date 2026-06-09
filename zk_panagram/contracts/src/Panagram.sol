// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24; 

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IVerifier {
    function verify(bytes memory proof, bytes32[] memory publicInputs) external view returns (bool);
}

error Panagram_MinTimeNotPassed(uint256 minDuration, uint256 timePassed);
error Panagram_NoRoundWinner();

contract Panagram is ERC1155, Ownable {
    IVerifier public s_verifier;
    uint256 public MIN_DURATION = 10800; 
    uint256 public s_currentRound;
    uint256 public s_roundStartTime;
    bytes32 public s_answer;
    address public s_currentRoundWinner;
    mapping(address => uint256) public s_lastCorrectGuessRound;
    event Panagram_VerifierUpdated(IVerifier verifier);
    event Panagram_NewRoundsStarted(bytes32 answer);
    // Events related to makeGuess
    event Panagram_WinnerCrowned(address indexed winner, uint256 round);
    event Panagram_RunnerUpCrowned(address indexed runnerUp, uint256 round);
// Errors related to makeGuess
    error Panagram_FirstPanagramNotSet();
    error Panagram_AlreadyGuessedCorrectly(uint256 round, address user);
    error Panagram_InvalidProof();

    constructor(IVerifier _verifier) ERC1155("ipfs://bafybeicqfc4ipkle34tgqv3gh7gccwhmr22qdg7p6k6oxon255mnwb6csi/{id}.json") Ownable(msg.sender){
        s_verifier = _verifier;
    }
    function setVerifier(IVerifier _newVerifier) external onlyOwner {
    // We'll add access control here
    s_verifier = _newVerifier;
    emit Panagram_VerifierUpdated(_newVerifier);
    }

    // function to create a new round 
    function newRound(bytes32 _answer) external onlyOwner {
        if(s_roundStartTime == 0){
            s_roundStartTime = block.timestamp;
            s_answer = _answer; 

        } else {
            if(block.timestamp < s_roundStartTime + MIN_DURATION) {
                revert Panagram_MinTimeNotPassed(MIN_DURATION, block.timestamp - s_roundStartTime);

            } 
            if(s_currentRoundWinner == address(0)) {
                revert Panagram_NoRoundWinner(); 

            }
            s_roundStartTime = block.timestamp;
            s_currentRoundWinner = address(0);
            s_answer = _answer;
            
        }
        s_currentRound++; 
       

        
        emit Panagram_NewRoundsStarted(_answer); 

    }
    // function allow user to submit the a guess 
    function makeGuess(bytes memory _proof) external returns (bool) {
    if (s_currentRound == 0) {
        revert Panagram_FirstPanagramNotSet();
    }

    if (s_lastCorrectGuessRound[msg.sender] == s_currentRound) {
        revert Panagram_AlreadyGuessedCorrectly(s_currentRound, msg.sender);
    }

    bytes32[] memory publicInputs = new bytes32[](2);
    publicInputs[0] = s_answer;
    publicInputs[1] = bytes32(uint256(uint160(msg.sender)));

    bool proofResult = s_verifier.verify(_proof, publicInputs);

    if (!proofResult) {
        revert Panagram_InvalidProof();
    }

    // If proof is valid, the guess is correct
    s_lastCorrectGuessRound[msg.sender] = s_currentRound;

    if (s_currentRoundWinner == address(0)) { // First correct guess for this round
        s_currentRoundWinner = msg.sender;
        _mint(msg.sender, 0, 1, ""); // Mint NFT ID 0 (Winner NFT)
        emit Panagram_WinnerCrowned(msg.sender, s_currentRound);
    } else { // Subsequent correct guess (runner-up)
        _mint(msg.sender, 1, 1, ""); // Mint NFT ID 1 (Participant NFT)
        emit Panagram_RunnerUpCrowned(msg.sender, s_currentRound);
    }

    return true;
    }

    // Getter functions for testing
    function getCurrentPanagram() external view returns (bytes32) {
        return s_answer;
    }

    function getCurrentRoundStatus() external view returns (address) {
        return s_currentRoundWinner;
    }

}