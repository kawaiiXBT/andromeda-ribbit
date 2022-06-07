const hre = require("hardhat");

async function main() {
  const Token = await hre.ethers.getContractFactory("RibbitToken");
  const token = await Token.deploy();
  await token.deployed();
  console.log("$RIBBIT Token contract deployed to:", token.address);

  const Staking = await hre.ethers.getContractFactory("RibbitStaking");
  const staking = await Staking.deploy();
  await staking.deployed();
  console.log("$RIBBIT Staking contract deployed to:", staking.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
