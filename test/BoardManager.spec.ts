import {loadFixture} from "@nomicfoundation/hardhat-network-helpers"
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers"
import {expect} from "chai"
import {BigNumber} from "ethers"
import {ethers} from "hardhat"
import {BoardManager} from "../typechain-types"

const drawExpectations: Array<{ value: number; neighbors: Neighbors }> = [
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
		const manager = await BoardManager.deploy(drawingForNumber(0))
		await manager.deployed()

		return {manager}
	}

	let manager: BoardManager
	let signers: Array<SignerWithAddress>

	before(async () => {
		signers = await ethers.getSigners()
	})

	beforeEach(async () => {
		//@ts-ignore
		manager = (await loadFixture(deployBoardManager)).manager
	})

	describe("board is started", () => {
		it("draws", async () => {
			for (const expectation of drawExpectations) {
				const reserveResponse = await manager.reserveCanvas()
				console.log("reserve gas", (await reserveResponse.wait()).gasUsed)
				let board = await manager.getMyNeighbors()
				const drawResponse = await manager.draw(drawingForNumber(expectation.value) as any)
				console.log("draw gas", (await drawResponse.wait()).gasUsed)

				expect(board).to.deep.equal(
					drawingPropertyToIndexes(expectation.neighbors)
				)
			}
		})

		it("fails to draw empty canvas", async () => {
			await expect(manager.draw(EMPTY_CANVAS)).to.be.revertedWith(
				"Drawing shouldn't be empty"
			)
		})

		it("finishes", async () => {
			await manager.reserveCanvas()
			await manager.draw(DRAWING_A_REQUEST)
			await manager.finish()
		})

		it("fails to finish already finished board", async () => {
			await manager.finish()
			await expect(manager.finish()).to.be.revertedWith(ERROR_NOT_STARTED)
		})

		describe("first assignable is at the start of first ring", async () => {
			it("assigns first assignable space", async () => {
				await manager.reserveCanvas()

				await expect(await manager.getMyCanvasIndex()).to.equal(1)
			})

			it("reserves same space if same signer", async () => {
				await reserve_canvas_for_signer(0)

				await reserve_canvas_for_signer(0)
				await expect(await get_canvas_index_for_signer(0)).to.equal(1)
			})

			it("reserves same space if expired", async () => {
				await reserve_canvas_for_signer(1)

				await ethers.provider.send("evm_increaseTime", [1801])

				await reserve_canvas_for_signer(0)
				await expect(await get_canvas_index_for_signer(0)).to.equal(1)
			})

			it("reserves same space resets timer even when not expired", async () => {
				await reserve_canvas_for_signer(0)

				await ethers.provider.send("evm_increaseTime", [1000])

				await reserve_canvas_for_signer(0)

				await ethers.provider.send("evm_increaseTime", [1000])

				//skips one because it is not expired now
				await reserve_canvas_for_signer(1)
				await expect(await get_canvas_index_for_signer(1)).to.equal(2)
			})

			it("skips if other is drawing", async () => {
				await reserve_canvas_for_signer(1)

				await reserve_canvas_for_signer(0)
				await expect(await get_canvas_index_for_signer(0)).to.equal(2)
			})

			it("skips drawn", async () => {
				await reserve_canvas_for_signer(1)
				await draw_canvas_for_signer(1)

				await reserve_canvas_for_signer(0)
				await expect(await get_canvas_index_for_signer(0)).to.equal(2)
			})

			it("skips drawing and drawn", async () => {
				await reserve_canvas_for_signer(1)

				await reserve_canvas_for_signer(0)
				await draw_canvas_for_signer(0)

				await reserve_canvas_for_signer(0)
				await expect(await get_canvas_index_for_signer(0)).to.equal(3)
			})

			it("fails to reserve canvas when no place is found", async () => {
				//max concurrency is 4 at first ring
				await reserve_canvas_for_signer(1)
				await reserve_canvas_for_signer(2)
				await reserve_canvas_for_signer(3)
				await reserve_canvas_for_signer(4)

				await expect(reserve_canvas_for_signer(0)).to.be.revertedWith(ERROR_MAX_CONCURRENCY)
			})

			it("draw fails if did not reserve", async () => {
				await reserve_canvas_for_signer(1)

				await expect(draw_canvas_for_signer(0)).to.be.revertedWith(ERROR_NOT_RESERVED)
			})

			it("draw fails if reservation was already drawn", async () => {
				//this is so we do not advance the minimum
				await reserve_canvas_for_signer(1)

				await reserve_canvas_for_signer(0)
				await draw_canvas_for_signer(0)

				await expect(draw_canvas_for_signer(0)).to.be.revertedWith(ERROR_NOT_RESERVED)
			})

			it("draw succeeds even tho expired", async () => {
				await reserve_canvas_for_signer(0)

				await ethers.provider.send("evm_increaseTime", [1801])
				//TODO This should be any value, or ever better, check it correctly drawed
				await expect(draw_canvas_for_signer(0)).to.not.be.revertedWith(ERROR_NOT_RESERVED)
			})

			it("draw fails if someone took my place because of expiration", async () => {
				await reserve_canvas_for_signer(0)

				await ethers.provider.send("evm_increaseTime", [1801])
				await reserve_canvas_for_signer(1)

				await expect(draw_canvas_for_signer(0)).to.be.revertedWith(ERROR_NOT_RESERVED)
			})

			it("no new unlocks for drawing non minimums", async () => {
				//max concurrency is 4 at first ring
				await reserve_canvas_for_signer(1)
				await reserve_canvas_for_signer(2)
				await reserve_canvas_for_signer(3)
				await reserve_canvas_for_signer(4)

				//1 is not drawn, so no minimums are added
				await draw_canvas_for_signer(2)
				await draw_canvas_for_signer(3)
				await draw_canvas_for_signer(4)

				//This is a really sad use case. In practice, it is unlikely once it gains traction.
				await expect(reserve_canvas_for_signer(0)).to.be.revertedWith(ERROR_MAX_CONCURRENCY)
			})

			async function reserve_canvas_for_signer(index: number) {
				return await manager.connect(signers[index]).reserveCanvas()
			}

			async function get_canvas_index_for_signer(index: number) {
				return await manager.connect(signers[index]).getMyCanvasIndex()
			}

			async function draw_canvas_for_signer(index: number) {
				return await manager.connect(signers[index]).draw(DRAWING_A_REQUEST)
			}
		})
	})
})

const toBigNumberResponse = (value: number) => BigNumber.from(value)


const EMPTY_CANVAS: any = 0n
const EMPTY_CANVAS_RESPONSE: any = toBigNumberResponse(EMPTY_CANVAS)
const DRAWING_A_REQUEST: any = 1n

function drawingForNumber(value: number) {
	return toBigNumberResponse(value + 1)
}

function drawingPropertyToIndexes(value: Neighbors) {
	const result = Array(4).fill(EMPTY_CANVAS_RESPONSE)
	if (value.top !== undefined) result[0] = drawingForNumber(value.top)
	if (value.right !== undefined) result[1] = drawingForNumber(value.right)
	if (value.bottom !== undefined) result[2] = drawingForNumber(value.bottom)
	if (value.left !== undefined) result[3] = drawingForNumber(value.left)
	return result
}

const ERROR_NOT_STARTED = "Board must be started"
const ERROR_MAX_CONCURRENCY = "Max concurrency reached"
const ERROR_NOT_RESERVED = "Need to reserve first"