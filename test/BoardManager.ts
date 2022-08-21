import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("BoardManager", () => {
  async function deployBoardManager() {
    const BoardManager = await ethers.getContractFactory("BoardManager");
    const manager = await BoardManager.deploy();
    await manager.deployed();

    return { manager };
  }

  it("starts board", async () => {
    const { manager } = await loadFixture(deployBoardManager);
    const result = await manager.start();
    expect(result).to.equal(0);
  });

  it.skip("fails to start board twice", async () => {});

  it("returns canvas", async () => {
    const { manager } = await loadFixture(deployBoardManager);
    const result = await manager.getCanvas();
    expect(result).to.have.same.members([0, 0, 0, 0]);
  });

  it.skip("fails to get canvas when board is not started", async () => {});

  it("draws", async () => {
    const { manager } = await loadFixture(deployBoardManager);
    await manager.draw(42);
    let board = await manager.getCanvas();
    expect(board).to.have.same.members([0, 0, 0, 42]);

    await manager.draw(43);
    board = await manager.getCanvas();
    expect(board).to.have.same.members([0, 0, 0, 43]);
  });

  it.skip("fails to draw empty canvas", async () => {});

  it("finishes", async () => {
    const { manager } = await loadFixture(deployBoardManager);
    await manager.draw(42);
    await manager.finish();
  });

  it.skip("fails to finish already finished board", async () => {});
});
