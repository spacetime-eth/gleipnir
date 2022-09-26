import {loadFixture} from "@nomicfoundation/hardhat-network-helpers"
import {expect} from "chai"
import {BigNumber} from "ethers"
import {ethers} from "hardhat"
import {BoardManager} from "../typechain-types"

const drawExpectations: Array<{ value: number; neighbors: Neighbors }> = [
	{value: 0, neighbors: {}},
	{value: 1, neighbors: {bottom: 0}},
	{value: 2, neighbors: {left: 0}},
	{value: 3, neighbors: {top: 0}},
	{value: 4, neighbors: {right: 0}},
	{value: 5, neighbors: {bottom: 1}},
	{value: 6, neighbors: {bottom: 2, left: 1}},
	{value: 7, neighbors: {left: 2}},
	{value: 8, neighbors: {top: 2, left: 3}},
	{value: 9, neighbors: {top: 3}},
	{value: 10, neighbors: {top: 4, right: 3}},
	{value: 11, neighbors: {right: 4}},
	{value: 12, neighbors: {right: 1, bottom: 4}},
	{value: 13, neighbors: {bottom: 5}},
	{value: 14, neighbors: {bottom: 6, left: 5}},
	{value: 15, neighbors: {bottom: 7, left: 6}},
	{value: 16, neighbors: {left: 7}},
	{value: 17, neighbors: {top: 7, left: 8}},
	{value: 18, neighbors: {top: 8, left: 9}},
	{value: 19, neighbors: {top: 9}},
	{value: 20, neighbors: {top: 10, right: 9}},
	{value: 21, neighbors: {top: 11, right: 10}},
	{value: 22, neighbors: {right: 11}},
	{value: 23, neighbors: {right: 12, bottom: 11}},
	{value: 24, neighbors: {right: 5, bottom: 12}},
	{value: 25, neighbors: {bottom: 13}},
	{value: 26, neighbors: {bottom: 14, left: 13}}
]

type Neighbors = Partial<Record<"top" | "right" | "bottom" | "left", number>>;

describe("BoardManager", () => {
	async function deployBoardManager() {
		const BoardManager = await ethers.getContractFactory("BoardManager")
		const manager = await BoardManager.deploy()
		await manager.deployed()

		return {manager}
	}

	let manager: BoardManager

	beforeEach(async () => {
		//@ts-ignore
		manager = (await loadFixture(deployBoardManager)).manager
	})

	describe("board is idle", () => {
		it("fails to get canvas", async () => {
			await expect(manager.getMyCanvas()).to.be.revertedWith(
				"Board must be started before getting a canvas"
			)
		})

		it("fails to draw", async () => {
			await expect(manager.draw(DRAWING_A_REQUEST)).to.be.revertedWith(
				"Board must be started before drawing"
			)
		})
	})

	describe("board is started", () => {
		beforeEach(async () => {
			await manager.start()
		})

		it("fails to start already started board", async () => {
			await expect(manager.start()).to.be.revertedWith(
				"Can't start an already started board"
			)
		})

		it("returns canvas", async () => {
			const result = await manager.getMyCanvas()
			expect(result).to.deep.equal([
				EMPTY_CANVAS_RESPONSE,
				EMPTY_CANVAS_RESPONSE,
				EMPTY_CANVAS_RESPONSE,
				EMPTY_CANVAS_RESPONSE
			])
		})

		it("draws", async () => {
			for (const expectation of drawExpectations) {
				const reserveResponse = await manager.reserveCanvas()
				// @ts-ignore
				console.log("reserve gas", (await reserveResponse.wait()).gasUsed)
				let board = await manager.getMyCanvas()
				const drawResponse = await manager.draw(drawingForNumber(expectation.value))
				console.log("draw gas", (await drawResponse.wait()).gasUsed)

				expect(board).to.deep.equal(
					drawingPropertyToIndexes(expectation.neighbors)
				)
				console.log("all good for", expectation.value)
			}
		})

		it("fails to draw empty canvas", async () => {
			await expect(manager.draw(EMPTY_CANVAS)).to.be.revertedWith(
				"Drawing shouldn't be empty"
			)
		})

		it("finishes", async () => {
			await manager.draw(DRAWING_A_REQUEST)
			await manager.finish()
		})

		it("fails to finish already finished board", async () => {
			await manager.finish()
			await expect(manager.finish()).to.be.revertedWith(
				"Board must be started in order to be finished"
			)
		})
	})
})

const toBigNumberResponse = (value: number) => BigNumber.from(value)

const EMPTY_CANVAS = Array(16).fill(0n)
const EMPTY_CANVAS_RESPONSE = EMPTY_CANVAS.map(toBigNumberResponse)
const DRAWING_A_REQUEST = Array.from(Array(16), (_, i) => i)

function drawingForNumber(value: number) {
	return Array.from(Array(16), (_, i) => i + value)
}

function drawingPropertyToIndexes(value: Neighbors) {
	const result = Array(4).fill(EMPTY_CANVAS.map(toBigNumberResponse))
	if (value.top !== undefined) result[0] = drawingForNumber(value.top).map(toBigNumberResponse)
	if (value.right !== undefined) result[1] = drawingForNumber(value.right).map(toBigNumberResponse)
	if (value.bottom !== undefined) result[2] = drawingForNumber(value.bottom).map(toBigNumberResponse)
	if (value.left !== undefined) result[3] = drawingForNumber(value.left).map(toBigNumberResponse)
	return result
}
