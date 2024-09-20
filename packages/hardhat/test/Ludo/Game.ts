import { expect } from "chai";
import { ethers } from "hardhat";
import { LudoFactory, LudoGame } from "../typechain-types";

describe("Ludo Contracts", function () {
  let ludoFactory: LudoFactory;
  let ludoGame: LudoGame;
  let owner: any;
  let player1: any;
  let player2: any;
  let player3: any;
  let player4: any;

  before(async () => {
    [owner, player1, player2, player3, player4] = await ethers.getSigners();

    const ludoFactoryFactory = await ethers.getContractFactory("LudoFactory");
    ludoFactory = (await ludoFactoryFactory.deploy()) as LudoFactory;
    await ludoFactory.waitForDeployment();

    const ludoGameFactory = await ethers.getContractFactory("LudoGame");
    ludoGame = (await ludoGameFactory.deploy(owner.address, await ludoFactory.getAddress())) as LudoGame;
    await ludoGame.waitForDeployment();
  });

  describe("LudoFactory", function () {
    it("Should create a new game", async function () {
      const tx = await ludoFactory.createGame();
      const receipt = await tx.wait();
      const event = receipt?.logs.find(log => log.fragment.name === "GameCreated");
      expect(event).to.not.be.undefined;
      expect(event?.args?.creator).to.equal(owner.address);
    });

    it("Should record players joining a game", async function () {
      await ludoFactory.recordPlayer(player1.address);
      const gameDetails = await ludoFactory.getGameDetails(0);
      expect(gameDetails.players).to.include(player1.address);
    });
  });

  describe("LudoGame", function () {
    it("Should allow players to join the game", async function () {
      await ludoGame.connect(player1).joinGame();
      await ludoGame.connect(player2).joinGame();
      await ludoGame.connect(player3).joinGame();

      const playerCount = await ludoGame.playerCount();
      expect(playerCount).to.equal(4); // Including the owner
    });

    it("Should not allow more than 4 players", async function () {
      await expect(ludoGame.connect(player4).joinGame()).to.be.revertedWith("Game is full");
    });

    it("Should allow players to roll the dice", async function () {
      // Mocking the Entropy contract behavior
      const mockEntropy = await ethers.getContractFactory("MockEntropy");
      const entropy = await mockEntropy.deploy();
      await entropy.waitForDeployment();

      // Update the LudoGame contract to use the mock Entropy
      await ludoGame.setEntropyContract(await entropy.getAddress());

      await ludoGame.rollDice();
      const lastSequenceNumber = await ludoGame.lastSequenceNumber();
      expect(lastSequenceNumber).to.be.gt(0);
    });

    // Add more tests for game logic, pawn movement, winning conditions, etc.
  });
});
