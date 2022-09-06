import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import {BigNumber} from "ethers"
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
    //@ts-ignore
    manager = (await loadFixture(deployBoardManager)).manager;
  });

  describe("board is idle", () => {
    it("fails to get canvas", async () => {
      await expect(manager.getCanvas()).to.be.revertedWith(
        "Board must be started before getting a canvas"
      );
    });

    it("fails to draw", async () => {
      await expect(manager.draw(DRAWING_A_REQUEST)).to.be.revertedWith(
        "Board must be started before drawing"
      );
    });
  });

  describe("board is started", () => {
    beforeEach(async () => {
      await manager.start();
    });

    it("fails to start already started board", async () => {
      await expect(manager.start()).to.be.revertedWith(
        "Can't start an already started board"
      );
    });

    it("returns canvas", async () => {
      const result = await manager.getCanvas();
      expect(result).to.deep.equal([EMPTY_CANVAS_RESPONSE, EMPTY_CANVAS_RESPONSE, EMPTY_CANVAS_RESPONSE, EMPTY_CANVAS_RESPONSE]);
    });

    it("draws", async () => {
      await manager.draw(DRAWING_A_REQUEST);
      let board = await manager.getCanvas();
      expect(board).to.deep.equal([EMPTY_CANVAS_RESPONSE, EMPTY_CANVAS_RESPONSE, EMPTY_CANVAS_RESPONSE, DRAWING_A_RESPONSE]);

      await manager.draw(DRAWING_B_REQUEST);
      board = await manager.getCanvas();
      expect(board).to.deep.equal([EMPTY_CANVAS_RESPONSE, EMPTY_CANVAS_RESPONSE, EMPTY_CANVAS_RESPONSE, DRAWING_B_RESPONSE]);
    });

    it("fails to draw empty canvas", async () => {
      await expect(manager.draw(EMPTY_CANVAS)).to.be.revertedWith(
        "Drawing shouldn't be empty"
      );
    });

    it("finishes", async () => {
      await manager.draw(DRAWING_A_REQUEST);
      await manager.finish();
    });

    it("fails to finish already finished board", async () => {
      await manager.finish();
      await expect(manager.finish()).to.be.revertedWith(
        "Board must be started in order to be finished"
      );
    });
  });
});

const toBigNumberResponse = (value: number) => BigNumber.from(value)

const EMPTY_CANVAS = Array(16).fill(0n)
const EMPTY_CANVAS_RESPONSE = EMPTY_CANVAS.map(toBigNumberResponse)
const DRAWING_A_REQUEST = Array.from(Array(16), (_, i) => i)
const DRAWING_B_REQUEST = Array.from(Array(16), (_, i) => i + 1)
const DRAWING_A_RESPONSE = DRAWING_A_REQUEST.map(toBigNumberResponse)
const DRAWING_B_RESPONSE = DRAWING_B_REQUEST.map(toBigNumberResponse)
