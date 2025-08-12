// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
interface IKYCRegistry {
    function isUserVerified(address user) external view returns (bool);
    function isUserBlocked(address user) external view returns (bool);
}
contract RWAToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE         = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE         = keccak256("BURNER_ROLE");
    bytes32 public constant TRANSFER_AGENT_ROLE = keccak256("TRANSFER_AGENT_ROLE");

    // fractional ownership bookkeeping
    uint256 public immutable maxShares;
    uint256 public issuedShares;

    string private _metaData;
    IKYCRegistry public immutable kycRegistry;

    event MetadataUpdated(string metaData);
    event SharesMinted(address indexed to, uint256 shares);
    constructor(
        string memory name_,
        string memory symbol_,
        IKYCRegistry kycRegistry_,
        string memory metaData_,
        address owner_,
        uint256 maxShares_       // total allowed shares (e.g. 10000)
    ) ERC20(name_, symbol_) {
        require(owner_ != address(0), "RWAToken: owner zero");
        require(address(kycRegistry_) != address(0), "RWAToken: kyc zero");
        require(maxShares_ > 0, "RWAToken: maxShares == 0");

        kycRegistry = kycRegistry_;
        _metaData = metaData_;
        maxShares = maxShares_;
        issuedShares = 0;

        // roles
        _grantRole(DEFAULT_ADMIN_ROLE, owner_);
        _grantRole(MINTER_ROLE, owner_);
        _grantRole(BURNER_ROLE, owner_);
        _grantRole(TRANSFER_AGENT_ROLE, owner_);
    }

    function updateMetadata(string memory metaData_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _metaData = metaData_;
        emit MetadataUpdated(metaData_);
    }

    function getMetadata() external view returns (string memory) {
        return _metaData;
    }

    // Mint shares to `to`. Requires receiver to be KYC verified.
    function mint(address to, uint256 shares) external onlyRole(MINTER_ROLE) {
        require(shares > 0, "RWAToken: shares 0");
        require(issuedShares + shares <= maxShares, "RWAToken: exceeds max shares");
        require(kycRegistry.isUserVerified(to), "RWAToken: receiver not verified");

        issuedShares += shares;
        _mint(to, shares);
        emit SharesMinted(to, shares);
    }

    // Burn tokens: either owner burns own tokens or caller has allowance
    function burnFrom(address from, uint256 amount) external {
        if (msg.sender != from) {
            uint256 currentAllowance = allowance(from, msg.sender);
            require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
            _approve(from, msg.sender, currentAllowance - amount);
        }
        _burn(from, amount);

        if (issuedShares >= amount) {
            issuedShares -= amount;
        } else {
            issuedShares = 0;
        }
    }

    // Role-based arbitrary burn (for BURNER_ROLE)
    function roleBasedBurn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, amount);
        if (issuedShares >= amount) {
            issuedShares -= amount;
        } else {
            issuedShares = 0;
        }
    }

    // Transfers must respect KYC unless sender is a TRANSFER_AGENT_ROLE (marketplace/escrow)
    modifier onlyVerified(address from, address to) {
        if (!hasRole(TRANSFER_AGENT_ROLE, msg.sender)) {
            require(kycRegistry.isUserVerified(from), "RWAToken: sender not verified");
            require(kycRegistry.isUserVerified(to), "RWAToken: receiver not verified");
            require(!kycRegistry.isUserBlocked(from), "RWAToken: sender blocked");
            require(!kycRegistry.isUserBlocked(to), "RWAToken: receiver blocked");
        }
        _;
    }

    function transfer(address to, uint256 amount)
        public
        override
        onlyVerified(_msgSender(), to)
        returns (bool)
    {
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        override
        onlyVerified(from, to)
        returns (bool)
    {
        return super.transferFrom(from, to, amount);
    }
}
contract RWATokenFactory {
    IKYCRegistry public immutable kycRegistry;
    address[] public allTokens;
    event TokenCreated(address indexed tokenAddress, string name, string symbol, string metaData);

    constructor(address kycRegistry_) {
        require(kycRegistry_ != address(0), "RWATokenFactory: kyc addr zero");
        kycRegistry = IKYCRegistry(kycRegistry_);
    }

    modifier onlyVerified(address _user) {
        require(kycRegistry.isUserVerified(_user), "RWATokenFactory: user not verified");
        _;
    }
    function createRwaToken(
        string memory name_,
        string memory symbol_,
        string memory metaData_,
        uint256 maxShares_
    ) external onlyVerified(msg.sender) returns (address) {
        RWAToken token = new RWAToken(
            name_,
            symbol_,
            kycRegistry,
            metaData_,
            msg.sender,
            maxShares_
        );
        allTokens.push(address(token));
        emit TokenCreated(address(token), name_, symbol_, metaData_);
        return address(token);
    }

    function getAllTokens() external view returns (address[] memory) {
        return allTokens;
    }
}
