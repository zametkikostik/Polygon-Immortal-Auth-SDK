// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title PolyVault
 * @dev Decentralized Identity & Access Management
 * Хранение ссылок на зашифрованные данные в IPFS
 * Сеть: Polygon (MATIC)
 */
contract PolyVault {
    
    // Структура для хранения информации о записи
    struct VaultRecord {
        string ipfsHash;      // CID хэш данных в IPFS
        uint256 createdAt;    // Время создания
        uint256 updatedAt;    // Время последнего обновления
        bool exists;          // Флаг существования записи
    }
    
    // Mapping для хранения записей пользователей
    mapping(address => VaultRecord) private userVaults;
    
    // История версий для каждого пользователя
    mapping(address => string[]) private versionHistory;
    
    // События
    event VaultCreated(address indexed user, string ipfsHash, uint256 timestamp);
    event VaultUpdated(address indexed user, string ipfsHash, uint256 timestamp);
    event VaultDeleted(address indexed user, uint256 timestamp);
    event VersionAdded(address indexed user, string ipfsHash, uint256 timestamp);
    
    /**
     * @dev Создает новую запись с ссылкой на IPFS
     * @param _ipfsHash CID хэш данных в IPFS
     */
    function createVault(string memory _ipfsHash) public {
        require(bytes(_ipfsHash).length > 0, "IPFS hash cannot be empty");
        require(!userVaults[msg.sender].exists, "Vault already exists. Use updateVault instead.");
        
        userVaults[msg.sender] = VaultRecord({
            ipfsHash: _ipfsHash,
            createdAt: block.timestamp,
            updatedAt: block.timestamp,
            exists: true
        });
        
        versionHistory[msg.sender].push(_ipfsHash);
        
        emit VaultCreated(msg.sender, _ipfsHash, block.timestamp);
    }
    
    /**
     * @dev Обновляет существующую запись с новой ссылкой на IPFS
     * @param _ipfsHash Новый CID хэш данных в IPFS
     */
    function updateVault(string memory _ipfsHash) public {
        require(bytes(_ipfsHash).length > 0, "IPFS hash cannot be empty");
        require(userVaults[msg.sender].exists, "Vault does not exist. Use createVault first.");
        
        userVaults[msg.sender].ipfsHash = _ipfsHash;
        userVaults[msg.sender].updatedAt = block.timestamp;
        
        versionHistory[msg.sender].push(_ipfsHash);
        
        emit VaultUpdated(msg.sender, _ipfsHash, block.timestamp);
    }
    
    /**
     * @dev Возвращает IPFS хэш пользователя (бесплатный view вызов)
     * @param _user Адрес пользователя
     * @return IPFS CID хэш
     */
    function getVault(address _user) public view returns (string memory) {
        require(userVaults[_user].exists, "Vault does not exist");
        return userVaults[_user].ipfsHash;
    }
    
    /**
     * @dev Проверяет, есть ли данные у пользователя
     * @param _user Адрес пользователя
     * @return true если данные существуют
     */
    function hasVault(address _user) public view returns (bool) {
        return userVaults[_user].exists;
    }
    
    /**
     * @dev Возвращает информацию о vault пользователя
     * @param _user Адрес пользователя
     * @return ipfsHash, createdAt, updatedAt, exists
     */
    function getVaultInfo(address _user) public view returns (
        string memory ipfsHash,
        uint256 createdAt,
        uint256 updatedAt,
        bool exists
    ) {
        VaultRecord storage record = userVaults[_user];
        return (record.ipfsHash, record.createdAt, record.updatedAt, record.exists);
    }
    
    /**
     * @dev Возвращает количество версий у пользователя
     * @param _user Адрес пользователя
     * @return Количество версий
     */
    function getVersionCount(address _user) public view returns (uint256) {
        return versionHistory[_user].length;
    }
    
    /**
     * @dev Возвращает версию по индексу
     * @param _user Адрес пользователя
     * @param _index Индекс версии
     * @return IPFS CID хэш версии
     */
    function getVersion(address _user, uint256 _index) public view returns (string memory) {
        require(_index < versionHistory[_user].length, "Index out of bounds");
        return versionHistory[_user][_index];
    }
    
    /**
     * @dev Возвращает последние N версий
     * @param _user Адрес пользователя
     * @param _count Количество версий для возврата
     * @return Массив IPFS хэшей
     */
    function getRecentVersions(address _user, uint256 _count) public view returns (string[] memory) {
        uint256 total = versionHistory[_user].length;
        if (_count > total) {
            _count = total;
        }
        
        string[] memory recent = new string[](_count);
        for (uint256 i = 0; i < _count; i++) {
            recent[i] = versionHistory[_user][total - _count + i];
        }
        
        return recent;
    }
    
    /**
     * @dev Удаляет vault пользователя (опционально)
     */
    function deleteVault() public {
        require(userVaults[msg.sender].exists, "Vault does not exist");
        delete userVaults[msg.sender];
        emit VaultDeleted(msg.sender, block.timestamp);
    }
    
    /**
     * @dev Возвращает все версии истории
     * @param _user Адрес пользователя
     * @return Массив всех IPFS хэшей
     */
    function getAllVersions(address _user) public view returns (string[] memory) {
        return versionHistory[_user];
    }
}
