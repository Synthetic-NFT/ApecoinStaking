import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
const { ethers, upgrades } = require("hardhat");

describe("StakingRewards", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshopt in every test.
  async function deployStakingFixture() {

    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const StakingRewards = await ethers.getContractFactory("StakingRewards");
    const ERC20 = await ethers.getContractFactory("ERC20");
    const ERC721 = await ethers.getContractFactory("ERC721");
    const Vault = await ethers.getContractFactory("Vault");

    const BAYC = await ERC721.deploy("BoredApeYachtClub", "BAYC")
    const MAYC = await ERC721.deploy("MutantApeYachtClub", "MAYC")
    const BAKC = await ERC721.deploy("BoredApeKennelClub", "BAKC")
    const Apecoin = await ERC20.deploy("Apecoin", "APE")

    const vault = await upgrades.deployProxy(Vault);
    const stakingRewards = await upgrades.deployProxy(
        StakingRewards,
        [
            Apecoin.address,
            Apecoin.address,
            BAYC.address,
            MAYC.address,
            BAKC.address,
            vault.address
        ]
    );

    return { BAYC, MAYC, BAKC, Apecoin, vault, stakingRewards, owner, otherAccount };
  }

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    // `it` is another Mocha function. This is the one you use to define each
    // of your tests. It receives the test name, and a callback function.
    //
    // If the callback function is async, Mocha will `await` it.
    it("Should set the right owner", async function () {
      const { BAYC, MAYC, BAKC, Apecoin, vault, stakingRewards, owner, otherAccount } = await loadFixture(deployStakingFixture);
      expect(await stakingRewards.owner()).to.equal(owner.address);
    });

  });

});
