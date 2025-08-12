// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
abstract contract ERC165 is IERC165 {
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}
interface IAccessControl {
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
    error AccessControlBadConfirmation();
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address callerConfirmation) external;
}
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address account => bool) hasRole;
        bytes32 adminRole;
    }
    mapping(bytes32 role => RoleData) private _roles;
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }
    function hasRole(bytes32 role, address account) public view virtual returns (bool) {
        return _roles[role].hasRole[account];
    }
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert AccessControlUnauthorizedAccount(account, role);
        }
    }
    function getRoleAdmin(bytes32 role) public view virtual returns (bytes32) {
        return _roles[role].adminRole;
    }
    function grantRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }
    function revokeRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }
    function renounceRole(bytes32 role, address callerConfirmation) public virtual {
        if (callerConfirmation != _msgSender()) {
            revert AccessControlBadConfirmation();
        }
        _revokeRole(role, callerConfirmation);
    }
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }
    function _grantRole(bytes32 role, address account) internal virtual returns (bool) {
        if (!hasRole(role, account)) {
            _roles[role].hasRole[account] = true;
            emit RoleGranted(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }
    function _revokeRole(bytes32 role, address account) internal virtual returns (bool) {
        if (hasRole(role, account)) {
            _roles[role].hasRole[account] = false;
            emit RoleRevoked(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }
}
contract KYCRegistry is AccessControl {
    bytes32 public constant KYC_MANAGER_ROLE = keccak256("KYC_MANAGER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("Admin_ROLE");

    mapping(address => bool) private _isVerified;
    mapping(address => bool) private _isBlocked;

    event UserVerified(address indexed user);
    event UserRevoked(address indexed user);
    event UserBlocked(address indexed user);
    event UserUnblocked(address indexed user);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(KYC_MANAGER_ROLE, msg.sender);
    }

    modifier notBlocked(address user) {
        require(!_isBlocked[user], "User is blocked");
        _;
    }
    // Mark a user as KYC verified
    function verifyUser(address user) external onlyRole(KYC_MANAGER_ROLE) notBlocked(user) {
        _isVerified[user] = true;
        emit UserVerified(user);
    }
    // Revoke KYC verification for a user
    function revokeUser(address user) external onlyRole(KYC_MANAGER_ROLE) {
        _isVerified[user] = false;
        emit UserRevoked(user);
    }
    // Block a user (cannot be verified until unblocked)
    function blockUser(address user) external onlyRole(KYC_MANAGER_ROLE) {
        _isVerified[user] = false;
        _isBlocked[user] = true;
        emit UserBlocked(user);
    }
    // Unblock a previously blocked user
    function unblockUser(address user) external onlyRole(KYC_MANAGER_ROLE) {
        _isBlocked[user] = false;
        emit UserUnblocked(user);
    }
    // Check if a user is verified and not blocked
    function isUserVerified(address user) external view returns (bool) {
        return _isVerified[user] && !_isBlocked[user];
    }
    // Check if a user is blocked
    function isUserBlocked(address user) external view returns (bool) {
        return _isBlocked[user];
    }
}
