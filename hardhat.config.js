require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
// Ensure your configuration variables are set before executing the script
const { vars } = require("hardhat/config");

module.exports = {
  solidity: "0.8.26",
  paths: {
    sources: "./contracts",
  },
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/${process.env.KEY}`,
      accounts: [process.env.PRIVATE_KEY],
    },
    mainnet: {
      url: `https://sepolia.infura.io/v3/${process.env.KEY}`,
      accounts: [process.env.PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};
