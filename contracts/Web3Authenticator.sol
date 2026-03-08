// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Web3Authenticator
 * @dev Бессмертный Web3 2FA Аутентификатор для хранения зашифрованных данных
 * Сеть: Polygon (MATIC)
 */
contract Web3Authenticator {
    
    // Mapping для хранения зашифрованных vault данных пользователей
    mapping(address => string) private userVaults;
    
    // Событие для отслеживания обновлений vault
    event VaultUpdated(address indexed user, uint256 timestamp);
    
    // Событие для отслеживания чтения vault
    event VaultAccessed(address indexed user, uint256 timestamp);
    
    /**
     * @dev Сохраняет зашифрованный массив данных в vault пользователя
     * @param _data Зашифрованные данные в виде JSON строки
     */
    function saveVault(string memory _data) public {
        require(bytes(_data).length > 0, "Data cannot be empty");
        require(bytes(_data).length <= 100000, "Data too large");
        
        userVaults[msg.sender] = _data;
        
        emit VaultUpdated(msg.sender, block.timestamp);
    }
    
    /**
     * @dev Возвращает зашифрованные данные пользователя (бесплатный view вызов)
     * @param _user Адрес пользователя
     * @return Зашифрованные данные vault
     */
    function getVault(address _user) public view returns (string memory) {
        emit VaultAccessed(_user, block.timestamp);
        return userVaults[_user];
    }
    
    /**
     * @dev Проверяет, есть ли данные у пользователя
     * @param _user Адрес пользователя
     * @return true если данные существуют
     */
    function hasVault(address _user) public view returns (bool) {
        return bytes(userVaults[_user]).length > 0;
    }
    
    /**
     * @dev Удаляет vault пользователя (опционально)
     */
    function deleteVault() public {
        delete userVaults[msg.sender];
        emit VaultUpdated(msg.sender, block.timestamp);
    }
}
