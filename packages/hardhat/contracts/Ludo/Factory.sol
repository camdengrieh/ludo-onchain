pragma solidity ^0.8.17;

import "./Game.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LudoFactory is Ownable {
    struct GameRecord {
        address gameAddress;
        address creator;
        address[] players;
        address[] podium;
    }

    GameRecord[] public games;
    mapping(address => uint256[]) public playerGames;

    event GameCreated(address gameAddress, address creator);
    event GameFinished(address gameAddress, address[] podium);

    function createGame() external returns (address) {
        LudoGame newGame = new LudoGame(msg.sender, address(this));
        games.push(GameRecord({
            gameAddress: address(newGame),
            creator: msg.sender,
            players: new address[](0),
            podium: new address[](0)
        }));
        newGame.initialiseFirstPlayer(msg.sender);
        uint256 gameId = games.length - 1;
        playerGames[msg.sender].push(gameId);
        emit GameCreated(address(newGame), msg.sender);
        return address(newGame);
    }

    function recordPlayer(address player) external {
        require(games.length > 0, "No games created yet");
        uint256 gameId = games.length - 1;
        require(msg.sender == games[gameId].gameAddress, "Only the game contract can record players");
        games[gameId].players.push(player);
        playerGames[player].push(gameId);
    }

    function recordGameResult(address[] memory podium) external {
        require(games.length > 0, "No games created yet");
        uint256 gameId = games.length - 1;
        require(msg.sender == games[gameId].gameAddress, "Only the game contract can record results");
        games[gameId].podium = podium;
        emit GameFinished(games[gameId].gameAddress, podium);
    }

    function getPlayerGames(address player) external view returns (uint256[] memory) {
        return playerGames[player];
    }

    function getGameDetails(uint256 gameId) external view returns (GameRecord memory) {
        require(gameId < games.length, "Invalid game ID");
        return games[gameId];
    }
}
