// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";

contract LudoGame is IEntropyConsumer {
    IEntropy public entropy;
    address public provider;
    LudoFactory public factory;

    enum GameState { Waiting, Playing, Finished }
    
    struct Player {
        address addr;
        uint8[4] pawns;
        bool[4] inHome;
        uint8 pawnsAtHome;
    }

    GameState public state;
    Player[4] public players;
    uint8 public currentPlayerTurn;
    uint8 public playerCount;
    uint64 public lastSequenceNumber;
    uint8 public constant BOARD_SIZE = 52;
    uint8 public constant PAWNS_PER_PLAYER = 4;

    event PlayerJoined(address player);
    event DiceRolled(address player, uint8 roll);
    event PawnMoved(address player, uint8 pawnIndex, uint8 newPosition);
    event PawnKnockedOut(address attacker, address victim, uint8 pawnIndex);
    event PlayerWon(address player);
    event GameFinished(address winner);

    constructor(address _creator, address _factory) {
        entropy = IEntropy(0x123...); // Replace with actual Entropy contract address
        provider = entropy.getDefaultProvider();
        factory = LudoFactory(_factory);
        players[0].addr = _creator;
        playerCount = 1;
        state = GameState.Waiting;
        factory.recordPlayer(_creator);
    }

    function joinGame() external {
        require(state == GameState.Waiting, "Game is not in waiting state");
        require(playerCount < 4, "Game is full");
        
        players[playerCount].addr = msg.sender;
        for (uint8 i = 0; i < PAWNS_PER_PLAYER; i++) {
            players[playerCount].pawns[i] = 0;
            players[playerCount].inHome[i] = false;
        }
        players[playerCount].pawnsAtHome = PAWNS_PER_PLAYER;
        playerCount++;
        
        factory.recordPlayer(msg.sender);

        if (playerCount == 4) {
            state = GameState.Playing;
        }
        
        emit PlayerJoined(msg.sender);
    }

    function rollDice() external {
        require(state == GameState.Playing, "Game is not in playing state");
        require(msg.sender == players[currentPlayerTurn].addr, "Not your turn");
        
        uint256 fee = entropy.getFee(provider);
        uint64 sequenceNumber = entropy.requestWithCallback{value: fee}(provider, abi.encodePacked(block.timestamp, msg.sender));
        lastSequenceNumber = sequenceNumber;
    }

    function getEntropy() internal view override returns (address) {
        return address(entropy);
    }

    function entropyCallback(uint64 sequenceNumber, address, bytes32 randomNumber) internal override {
        require(sequenceNumber == lastSequenceNumber, "Invalid sequence number");
        
        uint8 roll = uint8(uint256(randomNumber) % 6) + 1;
        emit DiceRolled(players[currentPlayerTurn].addr, roll);
        
        bool moved = false;
        Player storage currentPlayer = players[currentPlayerTurn];

        // Check if player can move any pawn out of home
        if (roll == 6 && currentPlayer.pawnsAtHome > 0) {
            for (uint8 i = 0; i < PAWNS_PER_PLAYER; i++) {
                if (currentPlayer.pawns[i] == 0) {
                    currentPlayer.pawns[i] = 1;
                    currentPlayer.pawnsAtHome--;
                    moved = true;
                    emit PawnMoved(currentPlayer.addr, i, 1);
                    break;
                }
            }
        }

        // If no pawn was moved out of home, try to move existing pawns
        if (!moved) {
            for (uint8 i = 0; i < PAWNS_PER_PLAYER; i++) {
                if (currentPlayer.pawns[i] > 0 && !currentPlayer.inHome[i]) {
                    uint8 newPosition = (currentPlayer.pawns[i] + roll) % BOARD_SIZE;
                    if (newPosition == 0) newPosition = BOARD_SIZE;

                    // Check if pawn can enter home
                    if (newPosition > BOARD_SIZE - 6) {
                        currentPlayer.inHome[i] = true;
                        currentPlayer.pawnsAtHome++;
                        emit PawnMoved(currentPlayer.addr, i, newPosition);
                        moved = true;
                        break;
                    }

                    // Check for knocking out other players' pawns
                    for (uint8 j = 0; j < playerCount; j++) {
                        if (j != currentPlayerTurn) {
                            for (uint8 k = 0; k < PAWNS_PER_PLAYER; k++) {
                                if (players[j].pawns[k] == newPosition) {
                                    players[j].pawns[k] = 0;
                                    players[j].pawnsAtHome++;
                                    emit PawnKnockedOut(currentPlayer.addr, players[j].addr, k);
                                }
                            }
                        }
                    }

                    currentPlayer.pawns[i] = newPosition;
                    emit PawnMoved(currentPlayer.addr, i, newPosition);
                    moved = true;
                    break;
                }
            }
        }

        // Check if the current player has won
        if (currentPlayer.pawnsAtHome == PAWNS_PER_PLAYER) {
            emit PlayerWon(currentPlayer.addr);
            state = GameState.Finished;
            emit GameFinished(currentPlayer.addr);
        } else {
            // Move to the next player's turn if the current player didn't roll a 6
            if (roll != 6) {
                currentPlayerTurn = (currentPlayerTurn + 1) % playerCount;
            }
        }
    }

    function getPawnPositions(uint8 playerIndex) external view returns (uint8[4] memory) {
        require(playerIndex < playerCount, "Invalid player index");
        return players[playerIndex].pawns;
    }

    function getPlayerAddress(uint8 playerIndex) external view returns (address) {
        require(playerIndex < playerCount, "Invalid player index");
        return players[playerIndex].addr;
    }

    function getCurrentPlayerTurn() external view returns (uint8) {
        return currentPlayerTurn;
    }

    function getGameState() external view returns (GameState) {
        return state;
    }

    function finishGame() internal {
        require(state == GameState.Finished, "Game is not finished");
        address[] memory podium = new address[](playerCount);
        uint8 podiumIndex = 0;
        for (uint8 i = 0; i < playerCount; i++) {
            if (players[i].pawnsAtHome == PAWNS_PER_PLAYER) {
                podium[podiumIndex] = players[i].addr;
                podiumIndex++;
            }
        }
        factory.recordGameResult(podium);
    }

    function setEntropyContract(address _entropyAddress) external {
        require(msg.sender == factory.owner(), "Only factory owner can set Entropy contract");
        entropy = IEntropy(_entropyAddress);
    }
}