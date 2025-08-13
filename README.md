command to deploy smart contract 
npx hardhat ignition deploy ./ignition/modules/KYCResigtry.js --network sepolia

0x2Ff598aaAb89aa39dfe597a9546a4d9B9F6a8B99
----------------------------------------------------------------------------------------
npx hardhat ignition deploy ./ignition/modules/RWAFactory.js --network sepolia

0x7AfCE1424f81a8faA7BbB6179AF3682aAb6a0864
----------------------------------------------------------------------------------------
npx hardhat ignition deploy ./ignition/modules/SaleEscrow.js --network sepolia

0x220878008d3eb7c94Afda696d2057462df66fdd8
----------------------------------------------------------------------------------------
npx hardhat ignition deploy ./ignition/modules/SaleMarketplace.js --network sepolia

0x6d8d9E120f4FED9c441CF14bAf7B254425d3dD3c
-----------------------------------------------------------------------------------------
USDT Address : 0xb9a0b25b041b950686b78b68e7156b8f38141f80

-----------------------------------------------------------------------------------------

testing Flow

1- verify seller buyer from kyc contract 

2- generate rwa token from factory contract

3- mint from rwstoken according to share also add 18 zero suppose 100 share then write 100000000000000000000

4- create usdt for testing purpose  use deposit function add six zero after value suppose you want 100 usdt then add 100000000 (it is only for testnet testing)

5- verify marketplace address from kyc contract using verifyUser function (one time)

6- approve RWAToken to MarketPlace Contract Address (RWAToken wo wala jo wo parameter main pass kr rha)

7- createListing(IERC20 RWAToken,uint256 share, uint256 price)

8- approve USDT to marketplace smart contract address amount equal to price

9- purchase(uint256 saleId)

10- markShipped(uint256 saleId, string calldata trackingInfo) seller call function

11- confirmDelivery(uint256 saleId)  buyer call function

12- cancelListing(uint256 saleId) seller can cencell the listing agr kissi nay buy nai kia 
