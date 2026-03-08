// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// ============================================
// IMPORTS (OpenZeppelin via URL for Remix)
// ============================================
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.0/contracts/metatx/ERC2771Context.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.0/contracts/security/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.0/contracts/access/Ownable.sol";

/**
 * @title Web3Authenticator
 * @author Senior Blockchain Engineer
 * @notice Production-ready decentralized 2FA vault with Gasless support
 * @dev ERC-2771 compatible for Biconomy meta-transactions
 * 
 * Network: Polygon Mainnet (Chain ID: 137)
 * 
 * Features:
 * - Gasless transactions via Biconomy Paymaster
 * - One-time activation fee (2 POL)
 * - Encrypted vault storage (IPFS hash)
 * - Owner can manage fees and withdraw funds
 */
contract Web3Authenticator is ERC2771Context, ReentrancyGuard, Ownable {
    
    // ============================================
    // STATE VARIABLES
    // ============================================
    
    /**
     * @dev Хранение зашифрованных данных пользователя (IPFS CID)
     */
    mapping(address => string) private userVaults;
    
    /**
     * @dev Статус активации (оплата activationFee)
     */
    mapping(address => bool) public isActivated;
    
    /**
     * @dev Время активации пользователя
     */
    mapping(address => uint256) private activatedAt;
    
    /**
     * @dev Стоимость активации в wei (2 POL = 2 * 10^18 wei)
     */
    uint256 public activationFee = 2 ether;
    
    /**
     * @dev Минимальная стоимость активации (0.5 POL)
     */
    uint256 public constant MIN_ACTIVATION_FEE = 500000000000000000;
    
    /**
     * @dev Адрес платформы для сбора комиссий
     */
    address payable public platformAddress;
    
    /**
     * @dev Комиссия платформы в basis points (100 = 1%)
     */
    uint256 public platformFeeBps = 100;
    uint256 public constant BPS_DENOMINATOR = 10000;
    
    // ============================================
    // EVENTS
    // ============================================
    
    event VaultActivated(address indexed user, uint256 amount, uint256 timestamp);
    event VaultUpdated(address indexed user, string ipfsHash, uint256 timestamp);
    event VaultDeleted(address indexed user, uint256 timestamp);
    event ActivationFeeUpdated(uint256 newFee);
    event PlatformAddressUpdated(address newAddress);
    event PlatformFeeUpdated(uint256 newFeeBps);
    event FundsWithdrawn(address indexed to, uint256 amount);
    
    // ============================================
    // ERRORS
    // ============================================
    
    error VaultAlreadyActivated();
    error VaultNotActivated();
    error InsufficientActivationFee();
    error ActivationFeeTooHigh();
    error InvalidPlatformAddress();
    error InvalidTrustedForwarder();
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    /**
     * @dev Конструктор с настройкой ERC-2771 Trusted Forwarder
     * @param _trustedForwarder Адрес Biconomy Forwarder (Polygon: 0x1D0013...)
     * @param _platformAddress Адрес для сбора комиссий платформы
     */
    constructor(
        address _trustedForwarder,
        address payable _platformAddress
    ) 
        ERC2771Context(_trustedForwarder)
        Ownable(msg.sender)
    {
        if (_trustedForwarder == address(0)) {
            revert InvalidTrustedForwarder();
        }
        if (_platformAddress == address(0)) {
            revert InvalidPlatformAddress();
        }
        
        platformAddress = _platformAddress;
    }
    
    // ============================================
    // ERC-2771 OVERRIDES (CRITICAL FOR GASLESS)
    // ============================================
    
    /**
     * @dev Возвращает отправителя с учетом мета-транзакций
     */
    function _msgSender() internal view override(Context, ERC2771Context) returns (address) {
        return ERC2771Context._msgSender();
    }
    
    /**
     * @dev Возвращает данные калла с учетом контекста ERC-2771
     */
    function _msgData() internal view override(Context, ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }
    
    /**
     * @dev Возвращает длину суффикса контекста
     */
    function _contextSuffixLength() internal view override(Context, ERC2771Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }
    
    // ============================================
    // MODIFIERS
    // ============================================
    
    /**
     * @dev Проверяет что пользователь активирован
     */
    modifier onlyActivated() {
        if (!isActivated[_msgSender()]) {
            revert VaultNotActivated();
        }
        _;
    }
    
    /**
     * @dev Проверяет что отправлена достаточная сумма
     */
    modifier sufficientFee() {
        if (msg.value < activationFee) {
            revert InsufficientActivationFee();
        }
        _;
    }
    
    // ============================================
    // CORE FUNCTIONS
    // ============================================
    
    /**
     * @dev Активация vault с оплатой activationFee
     * @notice После активации все операции saveVault становятся газлесс (через Biconomy)
     */
    function activate() external payable sufficientFee nonReentrant {
        address user = _msgSender();
        
        if (isActivated[user]) {
            revert VaultAlreadyActivated();
        }
        
        // Распределение комиссий
        uint256 fee = msg.value;
        uint256 platformShare = (fee * platformFeeBps) / BPS_DENOMINATOR;
        uint256 contractShare = fee - platformShare;
        
        // Отправка комиссии платформе
        if (platformShare > 0) {
            (bool success, ) = platformAddress.call{value: platformShare}("");
            require(success, "Platform fee transfer failed");
        }
        
        // Остаток остаётся в контракте для оплаты газа
        isActivated[user] = true;
        activatedAt[user] = block.timestamp;
        
        emit VaultActivated(user, fee, block.timestamp);
    }
    
    /**
     * @dev Сохранение зашифрованных данных (IPFS CID)
     * @param _ipfsHash CID хэш зашифрованных данных в IPFS
     * @notice Вызывается через Biconomy Paymaster (газлесс для активированных)
     */
    function saveVault(string calldata _ipfsHash) external onlyActivated {
        address user = _msgSender();
        
        if (bytes(_ipfsHash).length == 0) {
            revert("Empty IPFS hash");
        }
        
        userVaults[user] = _ipfsHash;
        
        emit VaultUpdated(user, _ipfsHash, block.timestamp);
    }
    
    /**
     * @dev Получение IPFS хэша пользователя
     * @param user Адрес пользователя
     * @return IPFS CID хэш
     */
    function getVault(address user) external view returns (string memory) {
        return userVaults[user];
    }
    
    /**
     * @dev Проверка наличия vault у пользователя
     * @param user Адрес пользователя
     * @return true если vault существует
     */
    function hasVault(address user) external view returns (bool) {
        return bytes(userVaults[user]).length > 0;
    }
    
    /**
     * @dev Информация о vault пользователя
     * @param user Адрес пользователя
     * @return ipfsHash, activated, activatedAt
     */
    function getVaultInfo(address user) external view returns (
        string memory ipfsHash,
        bool activated,
        uint256 activationTime
    ) {
        return (userVaults[user], isActivated[user], activatedAt[user]);
    }
    
    /**
     * @dev Удаление vault пользователем
     * @notice Возврат не возможен, данные удаляются безвозвратно
     */
    function deleteVault() external onlyActivated {
        address user = _msgSender();
        delete userVaults[user];
        
        emit VaultDeleted(user, block.timestamp);
    }
    
    // ============================================
    // ADMIN FUNCTIONS (OWNER ONLY)
    // ============================================
    
    /**
     * @dev Изменение стоимости активации
     * @param newFee Новая стоимость в wei
     */
    function setActivationFee(uint256 newFee) external onlyOwner {
        if (newFee < MIN_ACTIVATION_FEE) {
            revert ActivationFeeTooHigh();
        }
        activationFee = newFee;
        emit ActivationFeeUpdated(newFee);
    }
    
    /**
     * @dev Изменение адреса платформы
     * @param newAddress Новый адрес платформы
     */
    function setPlatformAddress(address payable newAddress) external onlyOwner {
        if (newAddress == address(0)) {
            revert InvalidPlatformAddress();
        }
        platformAddress = newAddress;
        emit PlatformAddressUpdated(newAddress);
    }
    
    /**
     * @dev Изменение комиссии платформы (в basis points)
     * @param newFeeBps Новая комиссия (100 = 1%, макс 500 = 5%)
     */
    function setPlatformFeeBps(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > 500) {
            revert("Fee too high");
        }
        platformFeeBps = newFeeBps;
        emit PlatformFeeUpdated(newFeeBps);
    }
    
    /**
     * @dev Вывод накопленных средств контракта
     * @param amount Сумма для вывода
     */
    function withdraw(uint256 amount) external onlyOwner {
        if (address(this).balance < amount) {
            revert("Insufficient balance");
        }
        
        (bool success, ) = owner().call{value: amount}("");
        require(success, "Withdrawal failed");
        
        emit FundsWithdrawn(owner(), amount);
    }
    
    /**
     * @dev Вывод всех средств контракта
     */
    function withdrawAll() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert("No funds");
        }
        
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Withdrawal failed");
        
        emit FundsWithdrawn(owner(), balance);
    }
    
    // ============================================
    // VIEW FUNCTIONS
    // ============================================
    
    /**
     * @dev Получение баланса контракта
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Проверка является ли адрес Trusted Forwarder
     */
    function isTrustedForwarder(address forwarder) public view override returns (bool) {
        return ERC2771Context.isTrustedForwarder(forwarder);
    }
    
    /**
     * @dev Получение времени активации пользователя
     */
    function getActivatedAt(address user) external view returns (uint256) {
        return activatedAt[user];
    }
    
    // ============================================
    // RECEIVE & FALLBACK
    // ============================================
    
    /**
     * @dev Автоматическая активация при отправке POL
     * @notice Если отправлена сумма >= activationFee и vault не активирован
     */
    receive() external payable {
        if (msg.value >= activationFee && !isActivated[msg.sender]) {
            // Для прямого перевода используем msg.sender (не _msgSender())
            isActivated[msg.sender] = true;
            activatedAt[msg.sender] = block.timestamp;
            
            uint256 platformShare = (msg.value * platformFeeBps) / BPS_DENOMINATOR;
            if (platformShare > 0) {
                (bool success, ) = platformAddress.call{value: platformShare}("");
                require(success, "Platform fee transfer failed");
            }
            
            emit VaultActivated(msg.sender, msg.value, block.timestamp);
        }
    }
    
    /**
     * @dev Fallback функция
     */
    fallback() external payable {
        revert("Fallback not supported");
    }
}
