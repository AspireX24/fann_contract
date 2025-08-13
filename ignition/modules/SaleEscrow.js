const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("SaleEscrowModule", (m) => {
  const kycAddress = "0x2Ff598aaAb89aa39dfe597a9546a4d9B9F6a8B99";
  const usdtAdress = "0xB9A0B25B041B950686b78B68E7156B8f38141F80"

  const escrow = m.contract("SaleEscrow", [usdtAdress,kycAddress]);

  return { escrow };
});
