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

  it("returns canvas", async () => {
    const { manager } = await loadFixture(deployBoardManager);
    const result = await manager.getCanvas();
    expect(result).to.have.same.members([0, 0, 0, 0]);
  });
});
