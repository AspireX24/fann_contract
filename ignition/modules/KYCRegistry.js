const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");
module.exports = buildModule("KYCRegistryModule", (m) => {
  const kyc = m.contract("KYCRegistry");
  return { kyc };
});

