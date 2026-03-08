// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// ============================================
// IMPORTS (OpenZeppelin via URL for Remix)
// ============================================
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.0/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.0/contracts/security/ReentrancyGuard.sol";

/**
 * @title PolyVault
 * @author Senior Blockchain Engineer
 * @notice Secure vault storage with authenticator-gated access
 * @dev Only Web3Authenticator contract can write data
 * 
 * Network: Polygon Mainnet (Chain ID: 137)
 * 
 * Architecture:
 * - Web3Authenticator (owner) → writes to PolyVault
 * - PolyVault → stores encrypted data
 * - Users → read-only access to their own data
 * 
 * Security:
 * - Only authenticator can call storeData
 * - Users can only read their own data
 * - Owner can change authenticator address
 */
contract PolyVault is Ownable, ReentrancyGuard {
    
    // ============================================
    // STATE VARIABLES
    // ============================================
    
    /**
     * @dev Хранилище зашифрованных данных пользователей
     * @notice Доступ к записи только у Web3Authenticator
     */
    mapping(address => string) private encryptedSecrets;
    
    /**
     * @dev Адрес контракта-аутентификатора (Web3Authenticator)
     * @notice Только этот адрес может вызывать storeData
     */
    address public authenticator;
    
    /**
     * @dev Статус активности хранилища
     */
    bool public vaultActive = true;
    
    /**
     * @dev Общее количество записей
     */
    uint256 public totalRecords;
    
    // ============================================
    // EVENTS
    // ============================================
    
    /**
     * @dev Событие записи данных
     */
    event DataStored(address indexed user, uint256 timestamp, string ipfsHash);
    
    /**
     * @dev Событие обновления аутентификатора
     */
    event AuthenticatorUpdated(address oldAuth, address newAuth);
    
    /**
     * @dev Событие чтения данных
     */
    event DataAccessed(address indexed user, address indexed accessor, uint256 timestamp);
    
    /**
     * @dev Событие удаления данных
     */
    event DataDeleted(address indexed user, uint256 timestamp);
    
    /**
     * @dev Событие активации/деактивации хранилища
     */
    event VaultStatusChanged(bool active);
    
    // ============================================
    // ERRORS
    // ============================================
    
    error InvalidAuthenticatorAddress();
    error CallerNotAuthenticator();
    error VaultNotActive();
    error NoDataFound();
    error UnauthorizedAccess();
    
    // ============================================
    // MODIFIERS
    // ============================================
    
    /**
     * @dev Проверяет что вызывающий — контракт-аутентификатор
     */
    modifier onlyAuthenticator() {
        if (msg.sender != authenticator) {
            revert CallerNotAuthenticator();
        }
        _;
    }
    
    /**
     * @dev Проверяет что хранилище активно
     */
    modifier vaultIsActive() {
        if (!vaultActive) {
            revert VaultNotActive();
        }
        _;
    }
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    /**
     * @dev Конструктор инициализирует владельца
     * @notice Owner = деплоер контракта
     */
    constructor() Ownable(msg.sender) {
        // Authenticator будет установлен через setAuthenticator
    }
    
    // ============================================
    // ADMIN FUNCTIONS (OWNER ONLY)
    // ============================================
    
    /**
     * @dev Установка адреса контракта-аутентификатора
     * @param _auth Адрес Web3Authenticator контракта
     * @notice Доступно только owner
     */
    function setAuthenticator(address _auth) external onlyOwner {
        if (_auth == address(0)) {
            revert InvalidAuthenticatorAddress();
        }
        
        address oldAuth = authenticator;
        authenticator = _auth;
        
        emit AuthenticatorUpdated(oldAuth, _auth);
    }
    
    /**
     * @dev Активация хранилища
     */
    function activateVault() external onlyOwner {
        vaultActive = true;
        emit VaultStatusChanged(true);
    }
    
    /**
     * @dev Деактивация хранилища (экстренная остановка)
     */
    function deactivateVault() external onlyOwner {
        vaultActive = false;
        emit VaultStatusChanged(false);
    }
    
    /**
     * @dev Принудительное удаление данных пользователя (admin)
     * @param user Адрес пользователя
     */
    function adminDeleteData(address user) external onlyOwner {
        delete encryptedSecrets[user];
        emit DataDeleted(user, block.timestamp);
    }
    
    // ============================================
    // CORE FUNCTIONS
    // ============================================
    
    /**
     * @dev Сохранение зашифрованных данных
     * @param _user Адрес пользователя
     * @param _ipfsHash CID хэш зашифрованных данных в IPFS
     * @notice Доступно только Web3Authenticator контракту
     */
    function storeData(address _user, string calldata _ipfsHash) external onlyAuthenticator vaultIsActive {
        if (bytes(_ipfsHash).length == 0) {
            revert("Empty IPFS hash");
        }
        
        encryptedSecrets[_user] = _ipfsHash;
        totalRecords++;
        
        emit DataStored(_user, block.timestamp, _ipfsHash);
    }
    
    /**
     * @dev Обновление существующих данных
     * @param _user Адрес пользователя
     * @param _ipfsHash Новый CID хэш
     * @notice Доступно только Web3Authenticator контракту
     */
    function updateData(address _user, string calldata _ipfsHash) external onlyAuthenticator vaultIsActive {
        if (bytes(encryptedSecrets[_user]).length == 0) {
            revert NoDataFound();
        }
        
        encryptedSecrets[_user] = _ipfsHash;
        
        emit DataStored(_user, block.timestamp, _ipfsHash);
    }
    
    /**
     * @dev Получение данных пользователем или аутентификатором
     * @param _user Адрес пользователя
     * @return IPFS CID хэш зашифрованных данных
     * @notice Пользователь может читать только свои данные
     */
    function getData(address _user) external view returns (string memory) {
        // Разрешаем чтение: owner, authenticator, или сам пользователь
        if (msg.sender != owner() && msg.sender != authenticator && msg.sender != _user) {
            revert UnauthorizedAccess();
        }
        
        string memory data = encryptedSecrets[_user];
        
        if (bytes(data).length == 0) {
            revert NoDataFound();
        }
        
        emit DataAccessed(_user, msg.sender, block.timestamp);
        
        return data;
    }
    
    /**
     * @dev Проверка наличия данных у пользователя
     * @param _user Адрес пользователя
     * @return true если данные существуют
     */
    function hasData(address _user) external view returns (bool) {
        return bytes(encryptedSecrets[_user]).length > 0;
    }
    
    /**
     * @dev Удаление данных пользователем
     * @notice Пользователь может удалить только свои данные
     */
    function deleteData() external vaultIsActive {
        address user = msg.sender;
        
        if (bytes(encryptedSecrets[user]).length == 0) {
            revert NoDataFound();
        }
        
        delete encryptedSecrets[user];
        
        emit DataDeleted(user, block.timestamp);
    }
    
    // ============================================
    // VIEW FUNCTIONS
    // ============================================
    
    /**
     * @dev Получение информации о хранилище
     * @return total, active, authenticator, owner
     */
    function getVaultInfo() external view returns (
        uint256 total,
        bool active,
        address auth,
        address own
    ) {
        return (totalRecords, vaultActive, authenticator, owner());
    }
    
    /**
     * @dev Проверка является ли адрес авторизованным для записи
     */
    function isAuthorizedWriter(address addr) external view returns (bool) {
        return addr == authenticator;
    }
    
    /**
     * @dev Получение количества записей для конкретного пользователя
     * @notice Всегда 1 или 0 (последняя запись перезаписывает предыдущую)
     */
    function getUserRecordCount(address user) external view returns (uint256) {
        return hasData(user) ? 1 : 0;
    }
    
    // ============================================
    // EMERGENCY FUNCTIONS
    // ============================================
    
    /**
     * @dev Экстренная пауза всех операций записи
     * @notice Только owner
     */
    function emergencyStop() external onlyOwner {
        vaultActive = false;
        emit VaultStatusChanged(false);
    }
    
    /**
     * @dev Проверка статуса экстренной остановки
     */
    function isEmergencyStop() external view returns (bool) {
        return !vaultActive;
    }
    
    // ============================================
    // METADATA FUNCTIONS
    // ============================================
    
    /**
     * @dev Получение последнего времени записи для пользователя
     */
    function getLastWriteTime(address user) external view returns (uint256) {
        // Для этого нужно добавить отдельный маппинг
        // Упрощённая версия возвращает 0
        return 0;
    }
    
    /**
     * @dev Статистика хранилища
     */
    function getStats() external view returns (
        uint256 total,
        bool active,
        address auth,
        address own,
        uint256 balance
    ) {
        return (totalRecords, vaultActive, authenticator, owner(), address(this).balance);
    }
}
