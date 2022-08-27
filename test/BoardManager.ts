import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { BoardManager } from "../typechain-types";

describe("BoardManager", () => {
  async function deployBoardManager() {
    const BoardManager = await ethers.getContractFactory("BoardManager");
    const manager = await BoardManager.deploy();
    await manager.deployed();

    return { manager };
  }

  let manager: BoardManager;

  beforeEach(async () => {
    manager = (await loadFixture(deployBoardManager)).manager;
  });

  it("fails to start already started board", async () => {
    await manager.start();
    await expect(manager.start()).to.be.revertedWith(
      "Can't start an already started board"
    );
  });

  it("returns canvas", async () => {
    const result = await manager.getCanvas();
    expect(result).to.have.same.members([0, 0, 0, 0]);
  });

  it.skip("fails to get canvas when board is not started", async () => {});

  it("draws", async () => {
    await manager.draw(42);
    let board = await manager.getCanvas();
    expect(board).to.have.same.members([0, 0, 0, 42]);

    await manager.draw(43);
    board = await manager.getCanvas();
    expect(board).to.have.same.members([0, 0, 0, 43]);
  });

  it("fails to draw empty canvas", async () => {
    await expect(manager.draw(0)).to.be.revertedWith(
      "Drawing shouldn't be empty"
    );
  });

  it("finishes", async () => {
    await manager.draw(42);
    await manager.finish();
  });

  it.skip("fails to finish already finished board", async () => {});
});
