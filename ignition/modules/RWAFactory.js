const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("RWATokenFactoryModule", (m) => {
  const kycAddress = "0x2Ff598aaAb89aa39dfe597a9546a4d9B9F6a8B99";

  const factory = m.contract("RWATokenFactory", [kycAddress]);

  return { factory };
});
