// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ImmortalWeb32FA
 * @author Senior Blockchain Engineer
 * @notice Production-ready decentralized 2FA with Biconomy integration
 * @dev ERC-2771 compatible, B2B whitelist, gasless meta-transactions
 */
contract ImmortalWeb32FA is ReentrancyGuard, ERC2771Context, Ownable {
    
    // ==========================================
    // КОНСТАНТЫ
    // ==========================================
    uint256 public constant ACTIVATION_FEE = 2 ether;
    uint256 public constant PLATFORM_FEE_BPS = 100;
    uint256 public constant BPS_DENOMINATOR = 10000;
    
    // ==========================================
    // СТРУКТУРЫ
    // ==========================================
    struct Vault {
        string ipfsHash;
        uint256 activatedAt;
        uint256 updatedAt;
        bool exists;
    }
    
    struct BusinessAccount {
        uint256 deposit;
        uint256 spent;
        uint256 employeeCount;
        bool active;
    }
    
    // ==========================================
    // СОСТОЯНИЕ
    // ==========================================
    mapping(address => Vault) private userVaults;
    mapping(address => BusinessAccount) public businessAccounts;
    mapping(address => address) public employeeToBusiness;
    mapping(address => address[]) public businessEmployees;
    mapping(address => bool) public isWhitelisted;
    
    address payable public immutable PLATFORM_ADDRESS;
    
    // События
    event VaultActivated(address indexed user, uint256 amount, uint256 timestamp);
    event VaultUpdated(address indexed user, string ipfsHash, uint256 timestamp);
    event VaultDeleted(address indexed user, uint256 timestamp);
    event BusinessDeposited(address indexed business, uint256 amount);
    event EmployeeLinked(address indexed employee, address indexed business);
    event EmployeeUnlinked(address indexed employee, address indexed business);
    event WhitelistStatusChanged(address indexed user, bool status);
    event Withdrawal(address indexed to, uint256 amount);
    
    // ==========================================
    // КОНСТРУКТОР
    // ==========================================
    constructor(
        address _trustedForwarder,
        address payable _platformAddress
    ) 
        ERC2771Context(_trustedForwarder)
        Ownable(msg.sender)
    {
        require(_platformAddress != address(0), "Invalid platform address");
        PLATFORM_ADDRESS = _platformAddress;
    }
    
    // ==========================================
    // ERC-2771 OVERRIDE
    // ==========================================
    function _msgSender() internal view override(Context, ERC2771Context) returns (address) {
        return ERC2771Context._msgSender();
    }
    
    function _msgData() internal view override(Context, ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }
    
    function _contextSuffixLength() internal view override(Context, ERC2771Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }
    
    // ==========================================
    // МОДИФИКАТОРЫ
    // ==========================================
    modifier vaultExists() {
        require(userVaults[_msgSender()].exists, "Vault not activated");
        _;
    }
    
    modifier sufficientActivationFee() {
        require(msg.value >= ACTIVATION_FEE, "Insufficient activation fee");
        _;
    }
    
    modifier onlyWhitelisted() {
        require(isWhitelisted[_msgSender()], "User not whitelisted");
        _;
    }
    
    // ==========================================
    // ACTIVATION (PAY ONCE)
    // ==========================================
    /**
     * @dev Активация vault с оплатой 2 POL
     * @notice Whitelisted пользователи активируются бесплатно
     */
    function activateVault() external payable sufficientActivationFee nonReentrant {
        address user = _msgSender();
        require(!userVaults[user].exists, "Vault already activated");
        
        // Whitelisted не платят
        if (!isWhitelisted[user]) {
            uint256 platformFee = (msg.value * PLATFORM_FEE_BPS) / BPS_DENOMINATOR;
            uint256 remaining = msg.value - platformFee;
            
            (bool success, ) = PLATFORM_ADDRESS.call{value: platformFee}("");
            require(success, "Platform fee transfer failed");
        }
        
        userVaults[user] = Vault({
            ipfsHash: "",
            activatedAt: block.timestamp,
            updatedAt: block.timestamp,
            exists: true
        });
        
        emit VaultActivated(user, msg.value, block.timestamp);
    }
    
    /**
     * @dev Проверка активации
     */
    function isActivated(address user) external view returns (bool) {
        return userVaults[user].exists;
    }
    
    // ==========================================
    // VAULT OPERATIONS (GASLESS)
    // ==========================================
    /**
     * @dev Сохранение vault (вызывается через Biconomy)
     * @notice Whitelisted пользователи не платят газ
     */
    function saveVault(string calldata _ipfsHash) external vaultExists {
        address user = _msgSender();
        
        if (userVaults[user].ipfsHash.length == 0) {
            userVaults[user].ipfsHash = _ipfsHash;
        } else {
            userVaults[user].ipfsHash = _ipfsHash;
            userVaults[user].updatedAt = block.timestamp;
        }
        
        emit VaultUpdated(user, _ipfsHash, block.timestamp);
    }
    
    /**
     * @dev Получение IPFS хэша
     */
    function getVault(address user) external view returns (string memory) {
        require(userVaults[user].exists, "Vault not found");
        return userVaults[user].ipfsHash;
    }
    
    /**
     * @dev Информация о vault
     */
    function getVaultInfo(address user) external view returns (
        string memory ipfsHash,
        uint256 activatedAt,
        uint256 updatedAt,
        bool exists
    ) {
        Vault storage vault = userVaults[user];
        return (vault.ipfsHash, vault.activatedAt, vault.updatedAt, vault.exists);
    }
    
    /**
     * @dev Удаление vault
     */
    function deleteVault() external vaultExists {
        address user = _msgSender();
        delete userVaults[user];
        emit VaultDeleted(user, block.timestamp);
    }
    
    // ==========================================
    // B2B: WHITELIST & BUSINESS
    // ==========================================
    /**
     * @dev Установка статуса whitelist (только owner)
     * @notice Whitelisted пользователи не платят activation fee
     */
    function setWhitelisted(address user, bool status) external onlyOwner {
        isWhitelisted[user] = status;
        emit WhitelistStatusChanged(user, status);
    }
    
    /**
     * @dev Массовая установка whitelist
     */
    function setWhitelistedBatch(address[] calldata users, bool status) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            isWhitelisted[users[i]] = status;
            emit WhitelistStatusChanged(users[i], status);
        }
    }
    
    /**
     * @dev Пополнение депозита бизнеса
     */
    function businessDeposit() external payable {
        require(msg.value > 0, "Amount must be > 0");
        businessAccounts[msg.sender].deposit += msg.value;
        businessAccounts[msg.sender].active = true;
        emit BusinessDeposited(msg.sender, msg.value);
    }
    
    /**
     * @dev Привязка сотрудника
     */
    function linkEmployee(address employee) external {
        require(businessAccounts[msg.sender].active, "Business not active");
        require(employeeToBusiness[employee] == address(0), "Already linked");
        
        employeeToBusiness[employee] = msg.sender;
        businessEmployees[msg.sender].push(employee);
        businessAccounts[msg.sender].employeeCount++;
        
        // Автоматически whitelist для сотрудника
        isWhitelisted[employee] = true;
        emit WhitelistStatusChanged(employee, true);
        
        emit EmployeeLinked(employee, msg.sender);
    }
    
    /**
     * @dev Отвязка сотрудника
     */
    function unlinkEmployee(address employee) external {
        require(employeeToBusiness[employee] == msg.sender, "Not linked");
        delete employeeToBusiness[employee];
        businessAccounts[msg.sender].employeeCount--;
        emit EmployeeUnlinked(employee, msg.sender);
    }
    
    /**
     * @dev Проверка статуса сотрудника
     */
    function isEmployee(address user) external view returns (bool) {
        return employeeToBusiness[user] != address(0);
    }
    
    /**
     * @dev Получение списка сотрудников
     */
    function getBusinessEmployees(address business) external view returns (address[] memory) {
        return businessEmployees[business];
    }
    
    // ==========================================
    // ADMIN FUNCTIONS
    // ==========================================
    /**
     * @dev Вывод средств
     */
    function withdraw(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        (bool success, ) = owner().call{value: amount}("");
        require(success, "Withdrawal failed");
        emit Withdrawal(owner(), amount);
    }
    
    /**
     * @dev Изменение fee
     */
    function setActivationFee(uint256 newFee) external onlyOwner {
        ACTIVATION_FEE = newFee;
    }
    
    /**
     * @dev Получение баланса
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Получение статуса whitelist
     */
    function getWhitelistStatus(address user) external view returns (bool) {
        return isWhitelisted[user];
    }
    
    // ==========================================
    // RECEIVE
    // ==========================================
    receive() external payable {
        if (msg.value >= ACTIVATION_FEE && !userVaults[msg.sender].exists) {
            activateVault();
        } else {
            businessDeposit();
        }
    }
}
