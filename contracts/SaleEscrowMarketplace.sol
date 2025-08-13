// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IKYCRegistry {
    function isUserVerified(address user) external view returns (bool);

    function isUserBlocked(address user) external view returns (bool);
}

contract SaleEscrow is AccessControl {
    bytes32 public constant ARBITER_ROLE = keccak256("ARBITER_ROLE");
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");
    IERC20 public immutable usdt;
    IKYCRegistry public immutable kyc;
    enum EscrowStatus {
        None,
        Locked,
        Released
    }
    struct escrow {
        uint256 id;
        IERC20 RWAToken;
        address buyer;
        address seller;
        uint256 priceAmount;
        uint256 releaseAfter;
        EscrowStatus status;
    }
    // saleId => escrow
    mapping(uint256 => escrow) public payments;

    event PaymentLocked(
        uint256 indexed saleId,
        address indexed buyer,
        address indexed seller,
        uint256 priceAmount,
        uint256 releaseAfter
    );
    event PaymentReleased(
        uint256 indexed saleId,
        address indexed to,
        uint256 priceAmount
    );

    constructor(address usdtAddress, address kycRegistry) {
        require(usdtAddress != address(0), "Escrow: usdt zero");
        require(kycRegistry != address(0), "Escrow: kyc zero");
        usdt = IERC20(usdtAddress);
        kyc = IKYCRegistry(kycRegistry);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ARBITER_ROLE, msg.sender);
    }
    function lockPayment(
        uint256 _id,
        IERC20 RWAToken,
        address buyer,
        address seller,
        uint256 priceAmount,
        uint256 releaseAfterTimestamp
    ) external {
        require(_id != 0, "Escrow: saleId 0");
        require(
            payments[_id].status == EscrowStatus.None,
            "Escrow: already exists"
        );
        require(priceAmount > 0, "Escrow: amount 0");
        require(
            kyc.isUserVerified(buyer) && !kyc.isUserBlocked(buyer),
            "Escrow: payer not verified"
        );
        require(
            kyc.isUserVerified(seller) && !kyc.isUserBlocked(seller),
            "Escrow: beneficiary not verified"
        );

        payments[_id] = escrow({
            id: _id,
            RWAToken: RWAToken,
            buyer: buyer,
            seller: seller,
            priceAmount: priceAmount,
            releaseAfter: releaseAfterTimestamp,
            status: EscrowStatus.Locked
        });

        emit PaymentLocked(
            _id,
            buyer,
            seller,
            priceAmount,
            releaseAfterTimestamp
        );
    }

    function releaseToSeller(uint256 _id) external {
        escrow storage e = payments[_id];
        require(kyc.isUserVerified(e.seller), "Escrow: seller not verified");
        require(e.status == EscrowStatus.Locked, "Escrow: not locked");
        e.status = EscrowStatus.Released;
        require(
            usdt.transfer(e.seller, e.priceAmount),
            "Escrow: transfer failed"
        );
        emit PaymentReleased(_id, e.seller, e.priceAmount);
    }

    function releaseIfTimedOut(uint256 saleId) external {
        escrow storage e = payments[saleId];
        require(e.status == EscrowStatus.Locked, "Escrow: not locked");
        require(block.timestamp >= e.releaseAfter, "Escrow: not yet timed out");
        e.status = EscrowStatus.Released;
        require(
            usdt.transfer(e.seller, e.priceAmount),
            "Escrow: transfer failed"
        );
        emit PaymentReleased(saleId, e.seller, e.priceAmount);
    }

    function adminWithdraw(address to, uint256 amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(usdt.transfer(to, amount), "Escrow: admin withdraw failed");
    }

    function setMarketplace(address marketplace)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(marketplace != address(0), "Escrow: marketplace zero");
        _grantRole(MARKETPLACE_ROLE, marketplace);
    }

    // view helper
    function getPayment(uint256 saleId)
        external
        view
        returns (
            uint256 _saleId,
            address _payer,
            address _beneficiary,
            uint256 _amount,
            uint256 _releaseAfter,
            EscrowStatus _status
        )
    {
        escrow storage e = payments[saleId];
        return (
            e.id,
            e.buyer,
            e.seller,
            e.priceAmount,
            e.releaseAfter,
            e.status
        );
    }
}

contract SaleMarketplace is AccessControl {
    bytes32 public constant LISTING_MANAGER_ROLE =
        keccak256("LISTING_MANAGER_ROLE"); // can create listing on behalf of seller if needed
    bytes32 public constant KYC_MANAGER_ROLE = keccak256("KYC_MANAGER_ROLE");
    enum SaleStatus {
        None,
        Listed,
        Purchased,
        Shipped,
        DeliveredConfirmed,
        Released,
        Cancelled
    }
    uint256 saleCounter;
    struct Sale {
        IERC20 RWAToken;
        uint256 share;
        address seller;
        address buyer; // zero until purchased
        uint256 price; // in USDT smallest unit (e.g., 6 or 18 decimals depending on token)
        uint256 createdAt;
        uint256 purchasedAt;
        uint256 autoReleaseAfter; // unix timestamp
        string trackingInfo;
        SaleStatus status;
    }
    IKYCRegistry public immutable kyc;
    IERC20 public immutable usdt;
    SaleEscrow public immutable escrow;
    mapping(uint256 => Sale) public sales;
    event SaleCreated(
        uint256 indexed saleId,
        IERC20 indexed RWAToken,
        address indexed seller,
        uint256 price,
        uint256 listingTime
    );
    event Purchased(
        uint256 indexed saleId,
        address indexed buyer,
        uint256 price
    );
    event Shipped(uint256 indexed saleId, string trackingInfo);
    event DeliveryConfirmed(uint256 indexed saleId, address indexed buyer);
    event Cancelled(uint256 indexed saleId);

    constructor(
        address usdtAddr,
        address kycRegistry,
        address escrowAddr
    ) {
        require(
            usdtAddr != address(0) &&
                kycRegistry != address(0) &&
                escrowAddr != address(0),
            "Marketplace: zero addr"
        );
        usdt = IERC20(usdtAddr);
        kyc = IKYCRegistry(kycRegistry);
        escrow = SaleEscrow(escrowAddr);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(LISTING_MANAGER_ROLE, msg.sender);
    }

    modifier onlyVerified(address user) {
        require(
            kyc.isUserVerified(user) && !kyc.isUserBlocked(user),
            "Marketplace: user not verified"
        );
        _;
    }

    // Seller creates a listing
    function createListing(IERC20 RWAToken,uint256 share, uint256 price) external onlyVerified(msg.sender) returns (uint256){
        require(price > 0, "Marketplace: price 0");
        require(
            RWAToken.transferFrom(msg.sender, address(this),share),
            "Marketplace: RWAToken transferFrom failed"
        );
        saleCounter++;
        sales[saleCounter] = Sale({
            RWAToken: RWAToken,
            share : share,
            seller: msg.sender,
            buyer: address(0),
            price: price,
            createdAt: block.timestamp,
            purchasedAt: 0,
            autoReleaseAfter: 0,
            trackingInfo : "",
            status: SaleStatus.Listed
        });
        emit SaleCreated(saleCounter,RWAToken, msg.sender, price,block.timestamp);
        return saleCounter;
    }
    function purchase(uint256 saleId) external onlyVerified(msg.sender){
        Sale storage s = sales[saleId];
        require(s.status == SaleStatus.Listed, "Marketplace: not listed");
        require(msg.sender != s.seller, "Marketplace: seller cannot buy own");
        require(
            kyc.isUserVerified(s.seller) && !kyc.isUserBlocked(s.seller),
            "Marketplace: seller not verified"
        );
    
            usdt.transferFrom(msg.sender, address(this), s.price);
            usdt.transfer(address(escrow), s.price);
        
            s.RWAToken.transfer(msg.sender,s.share);
        s.buyer = msg.sender;
        s.purchasedAt = block.timestamp;
        s.autoReleaseAfter = block.timestamp +  300; //604800; // 7days
        s.status = SaleStatus.Purchased;
        escrow.lockPayment(
            saleId,
            s.RWAToken,
            msg.sender,
            s.seller,
            s.price,
            s.autoReleaseAfter
        );
        emit Purchased(saleId, msg.sender, s.price);
    }
    function markShipped(uint256 saleId, string calldata trackingInfo) external {
        Sale storage s = sales[saleId];
        require(s.status == SaleStatus.Purchased, "Marketplace: not purchased");
        require(msg.sender == s.seller, "Marketplace: not seller");
        s.status = SaleStatus.Shipped;
        s.trackingInfo = trackingInfo;
        emit Shipped(saleId, trackingInfo);
    }
    function confirmDelivery(uint256 saleId) external {
        Sale storage s = sales[saleId];
        require(
            s.status == SaleStatus.Shipped,
            "Marketplace: cannot confirm"
        );
        require(msg.sender == s.buyer, "Marketplace: not buyer");
        s.status = SaleStatus.DeliveredConfirmed;
        escrow.releaseToSeller(saleId);
        emit DeliveryConfirmed(saleId, msg.sender);
    }
    function cancelListing(uint256 saleId) external {
        Sale storage s = sales[saleId];
        require(s.status == SaleStatus.Listed, "Marketplace: cannot cancel");
        require(msg.sender == s.seller, "Marketplace: not seller");
        s.status = SaleStatus.Cancelled;
        emit Cancelled(saleId);
    }
    function getSale(uint256 saleId)
        external
        view
        returns (
            IERC20 RWAToken,
        uint256 share,
        address seller,
        address buyer, 
        uint256 price,
        uint256 createdAt,
        uint256 purchasedAt,
        uint256 autoReleaseAfter, 
        string memory trackingInfo,
        SaleStatus status
        )
    {
        Sale storage s = sales[saleId];
        return (
            s.RWAToken,s.share,s.seller,s.buyer,s.price,
            s.createdAt,s.purchasedAt,s.autoReleaseAfter,s.trackingInfo,s.status
        );
    }
    function registerWithEscrow() external onlyRole(DEFAULT_ADMIN_ROLE) {
        escrow.setMarketplace(address(this));
    }
    function getListedSaleIds() external view returns (uint256[] memory) {
        uint256 count;
        for (uint256 i = 1; i <= saleCounter; i++) {
            if (sales[i].status == SaleStatus.Listed) {
                count++;
            }
        }
        uint256[] memory listedIds = new uint256[](count);
        uint256 index;
        for (uint256 i = 1; i <= saleCounter; i++) {
            if (sales[i].status == SaleStatus.Listed) {
                listedIds[index] = i;
                index++;
            }
        }
        return listedIds;
    }
}