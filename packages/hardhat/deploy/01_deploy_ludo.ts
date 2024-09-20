import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const deployLudoContracts: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  // Deploy LudoFactory
  const ludoFactory = await deploy("LudoFactory", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true,
  });

  console.log("LudoFactory deployed to:", ludoFactory.address);
};

export default deployLudoContracts;
deployLudoContracts.tags = ["LudoContracts"];
