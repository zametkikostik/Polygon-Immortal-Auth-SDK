// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ImmortalWeb32FA
 * @author Senior Web3 Architect
 * @notice Неуязвимый аутентификатор 2FA без серверов с Gasless транзакциями
 * 
 * @dev Особенности:
 * - Native Meta-Transactions (EIP-712) - пользователи не платят газ
 * - Business Paymaster - компании оплачивают газ через депозит
 * - AES-GCM шифрование на клиенте
 * - Работа из IPFS
 * 
 * Сеть: Polygon Mainnet
 */
contract ImmortalWeb32FA {
    
    // ==========================================
    // СТРУКТУРЫ ДАННЫХ
    // ==========================================
    
    /**
     * @dev Структура мета-транзакции (EIP-712)
     */
    struct MetaTransaction {
        address user;
        bytes relayer;
        uint256 nonce;
        uint256 gasLimit;
        uint256 gasPrice;
        bytes functionSignature;
    }
    
    /**
     * @dev Структура бизнес-аккаунта
     */
    struct BusinessAccount {
        uint256 deposit;        // Депозит для оплаты газа
        uint256 spent;          // Потрачено на газ
        uint256 employeeCount;  // Количество сотрудников
        bool active;            // Активен ли аккаунт
    }
    
    /**
     * @dev Структура vault пользователя
     */
    struct Vault {
        string ipfsHash;        // CID хэш в IPFS
        uint256 createdAt;      // Время создания
        uint256 updatedAt;      // Время обновления
        bool exists;            // Флаг существования
    }
    
    // ==========================================
    // СОСТОЯНИЕ КОНТРАКТА
    // ==========================================
    
    // Домен для EIP-712 подписей
    string constant internal EIP712_DOMAIN_NAME = "ImmortalWeb32FA";
    string constant internal EIP712_DOMAIN_VERSION = "1";
    bytes32 internal DOMAIN_SEPARATOR;
    bytes32 constant internal META_TRANSACTION_TYPEHASH = keccak256(
        "MetaTransaction(address user,address relayer,uint256 nonce,uint256 gasLimit,uint256 gasPrice,bytes functionSignature)"
    );
    
    // Депозиты бизнесов
    mapping(address => BusinessAccount) public businessAccounts;
    
    // Привязка сотрудников к бизнесу
    mapping(address => address) public employeeToBusiness;
    
    // Список сотрудников бизнеса
    mapping(address => address[]) public businessEmployees;
    
    // Vault пользователей
    mapping(address => Vault) private userVaults;
    
    // Nonce для мета-транзакций
    mapping(address => uint256) public nonces;
    
    // Минимальный депозит для активации бизнеса (в wei)
    uint256 public MINIMUM_DEPOSIT = 0.01 ether;
    
    // Комиссия платформы (1% = 100 basis points)
    uint256 public PLATFORM_FEE = 100;
    uint256 public constant BASIS_POINTS = 10000;
    
    // Адрес платформы для сбора комиссий
    address payable public immutable PLATFORM_ADDRESS;
    
    // Владелец контракта
    address public owner;
    
    // ==========================================
    // СОБЫТИЯ
    // ==========================================
    
    event BusinessDeposited(address indexed business, uint256 amount, uint256 newBalance);
    event BusinessWithdrawn(address indexed business, uint256 amount, uint256 newBalance);
    event EmployeeLinked(address indexed employee, address indexed business);
    event EmployeeUnlinked(address indexed employee, address indexed business);
    event VaultCreated(address indexed user, string ipfsHash, uint256 timestamp);
    event VaultUpdated(address indexed user, string ipfsHash, uint256 timestamp);
    event VaultDeleted(address indexed user, uint256 timestamp);
    event MetaTransactionExecuted(address indexed user, address indexed relayer, bool success);
    event GasPaid(address indexed business, address indexed user, uint256 amount);
    
    // ==========================================
    // МОДИФИКАТОРЫ
    // ==========================================
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier validGasPrice(uint256 gasPrice) {
        require(gasPrice <= tx.gasprice, "Gas price too high");
        _;
    }
    
    // ==========================================
    // КОНСТРУКТОР
    // ==========================================
    
    constructor(address payable _platformAddress) {
        require(_platformAddress != address(0), "Invalid platform address");
        
        owner = msg.sender;
        PLATFORM_ADDRESS = _platformAddress;
        
        // EIP-712 Domain Separator
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes(EIP712_DOMAIN_NAME)),
            keccak256(bytes(EIP712_DOMAIN_VERSION)),
            block.chainid,
            address(this)
        ));
    }
    
    // ==========================================
    // БИЗНЕС ФУНКЦИИ (DEPOSIT / WITHDRAW)
    // ==========================================
    
    /**
     * @dev Пополнение депозита бизнеса
     * @notice Бизнес оплачивает газ для своих сотрудников
     */
    function deposit() external payable {
        require(msg.value > 0, "Amount must be > 0");
        
        BusinessAccount storage business = businessAccounts[msg.sender];
        business.deposit += msg.value;
        business.active = true;
        
        emit BusinessDeposited(msg.sender, msg.value, business.deposit);
    }
    
    /**
     * @dev Вывод средств бизнеса
     * @param _amount Сумма для вывода
     */
    function withdraw(uint256 _amount) external {
        BusinessAccount storage business = businessAccounts[msg.sender];
        require(business.deposit >= _amount, "Insufficient balance");
        
        // Оставляем минимальный депозит если есть сотрудники
        if (business.employeeCount > 0) {
            require(business.deposit - _amount >= MINIMUM_DEPOSIT, "Cannot withdraw below minimum");
        }
        
        business.deposit -= _amount;
        business.spent += _amount; // Для статистики
        
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "Withdraw failed");
        
        emit BusinessWithdrawn(msg.sender, _amount, business.deposit);
    }
    
    /**
     * @dev Привязка сотрудника к бизнесу
     * @param _employee Адрес сотрудника
     */
    function linkEmployee(address _employee) external {
        require(businessAccounts[msg.sender].active, "Business not active");
        require(_employee != address(0), "Invalid address");
        require(employeeToBusiness[_employee] == address(0), "Already linked");
        
        employeeToBusiness[_employee] = msg.sender;
        businessEmployees[msg.sender].push(_employee);
        businessAccounts[msg.sender].employeeCount++;
        
        emit EmployeeLinked(_employee, msg.sender);
    }
    
    /**
     * @dev Отвязка сотрудника от бизнеса
     * @param _employee Адрес сотрудника
     */
    function unlinkEmployee(address _employee) external {
        require(employeeToBusiness[_employee] == msg.sender, "Not linked to this business");
        
        delete employeeToBusiness[_employee];
        businessAccounts[msg.sender].employeeCount--;
        
        emit EmployeeUnlinked(_employee, msg.sender);
    }
    
    /**
     * @dev Отвязка от текущего бизнеса (сотрудник)
     */
    function unlinkSelf() external {
        address business = employeeToBusiness[msg.sender];
        require(business != address(0), "Not linked to any business");
        
        delete employeeToBusiness[msg.sender];
        businessAccounts[business].employeeCount--;
        
        emit EmployeeUnlinked(msg.sender, business);
    }
    
    // ==========================================
    // META-TRANSACTIONS (EIP-712)
    // ==========================================
    
    /**
     * @dev Выполнение мета-транзакции от имени пользователя
     * @param user Адрес пользователя (от чьего имени выполняется)
     * @param relayer Адрес релеера (оплачивает газ)
     * @param nonce Nonce пользователя
     * @param gasLimit Лимит газа
     * @param gasPrice Цена газа
     * @param functionSignature Подписанные данные функции
     * @return success Результат выполнения
     * 
     * @notice Пользователь подписывает данные оффчейн, релеер отправляет транзакцию
     */
    function executeMetaTransaction(
        address user,
        address relayer,
        uint256 nonce,
        uint256 gasLimit,
        uint256 gasPrice,
        bytes calldata functionSignature
    ) external payable validGasPrice(gasPrice) returns (bool success) {
        require(nonce == nonces[user], "Invalid nonce");
        
        // Проверяем подпись
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            keccak256(abi.encode(
                META_TRANSACTION_TYPEHASH,
                user,
                relayer,
                nonce,
                gasLimit,
                gasPrice,
                keccak256(functionSignature)
            ))
        ));
        
        address signer = recoverSigner(digest, functionSignature);
        require(signer == user, "Invalid signature");
        
        // Проверяем что есть бизнес для оплаты газа
        address business = employeeToBusiness[user];
        require(business != address(0), "No business linked");
        
        BusinessAccount storage businessAccount = businessAccounts[business];
        require(businessAccount.active, "Business not active");
        
        // Вычисляем стоимость газа
        uint256 gasCost = gasLimit * gasPrice;
        uint256 platformFee = (gasCost * PLATFORM_FEE) / BASIS_POINTS;
        uint256 totalCost = gasCost + platformFee;
        
        require(businessAccount.deposit >= totalCost, "Insufficient business balance");
        
        // Списываем с депозита бизнеса
        businessAccount.deposit -= totalCost;
        businessAccount.spent += totalCost;
        
        // Увеличиваем nonce
        nonces[user]++;
        
        // Выполняем функцию от имени пользователя
        (success, ) = address(this).call(abi.encodePacked(functionSignature, user));
        
        emit MetaTransactionExecuted(user, relayer, success);
        emit GasPaid(business, user, gasCost);
    }
    
    /**
     * @dev Восстановление подписанта из подписи
     */
    function recoverSigner(bytes32 digest, bytes calldata signature) internal pure returns (address) {
        require(signature.length == 65, "Invalid signature length");
        
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        
        if (v < 27) {
            v += 27;
        }
        
        require(v == 27 || v == 28, "Invalid v");
        require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "Invalid s");
        
        return ecrecover(digest, v, r, s);
    }
    
    /**
     * @dev Получение подписи для мета-транзакции (для оффчейн использования)
     */
    function getMetaTransactionData(
        address user,
        address relayer,
        uint256 nonce,
        uint256 gasLimit,
        uint256 gasPrice,
        bytes memory functionSignature
    ) external view returns (bytes32) {
        return keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            keccak256(abi.encode(
                META_TRANSACTION_TYPEHASH,
                user,
                relayer,
                nonce,
                gasLimit,
                gasPrice,
                keccak256(functionSignature)
            ))
        ));
    }
    
    // ==========================================
    // VAULT ФУНКЦИИ
    // ==========================================
    
    /**
     * @dev Создание vault с IPFS хэшем
     * @param _ipfsHash CID хэш данных в IPFS
     */
    function createVault(string calldata _ipfsHash) external {
        require(bytes(_ipfsHash).length > 0, "Empty IPFS hash");
        require(!userVaults[msg.sender].exists, "Vault exists");
        
        userVaults[msg.sender] = Vault({
            ipfsHash: _ipfsHash,
            createdAt: block.timestamp,
            updatedAt: block.timestamp,
            exists: true
        });
        
        emit VaultCreated(msg.sender, _ipfsHash, block.timestamp);
    }
    
    /**
     * @dev Обновление vault с новым IPFS хэшем
     * @param _ipfsHash Новый CID хэш
     */
    function updateVault(string calldata _ipfsHash) external {
        require(bytes(_ipfsHash).length > 0, "Empty IPFS hash");
        require(userVaults[msg.sender].exists, "Vault not found");
        
        userVaults[msg.sender].ipfsHash = _ipfsHash;
        userVaults[msg.sender].updatedAt = block.timestamp;
        
        emit VaultUpdated(msg.sender, _ipfsHash, block.timestamp);
    }
    
    /**
     * @dev Получение IPFS хэша пользователя (бесплатный view)
     * @param _user Адрес пользователя
     * @return IPFS CID хэш
     */
    function getVault(address _user) external view returns (string memory) {
        require(userVaults[_user].exists, "Vault not found");
        return userVaults[_user].ipfsHash;
    }
    
    /**
     * @dev Проверка существования vault
     * @param _user Адрес пользователя
     * @return true если vault существует
     */
    function hasVault(address _user) external view returns (bool) {
        return userVaults[_user].exists;
    }
    
    /**
     * @dev Информация о vault
     * @param _user Адрес пользователя
     * @return ipfsHash, createdAt, updatedAt, exists
     */
    function getVaultInfo(address _user) external view returns (
        string memory ipfsHash,
        uint256 createdAt,
        uint256 updatedAt,
        bool exists
    ) {
        Vault storage vault = userVaults[_user];
        return (vault.ipfsHash, vault.createdAt, vault.updatedAt, vault.exists);
    }
    
    /**
     * @dev Удаление vault
     */
    function deleteVault() external {
        require(userVaults[msg.sender].exists, "Vault not found");
        delete userVaults[msg.sender];
        emit VaultDeleted(msg.sender, block.timestamp);
    }
    
    // ==========================================
    // ADMIN ФУНКЦИИ
    // ==========================================
    
    /**
     * @dev Изменение минимального депозита
     */
    function setMinimumDeposit(uint256 _newDeposit) external onlyOwner {
        MINIMUM_DEPOSIT = _newDeposit;
    }
    
    /**
     * @dev Изменение комиссии платформы
     */
    function setPlatformFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 500, "Fee too high"); // Макс 5%
        PLATFORM_FEE = _newFee;
    }
    
    /**
     * @dev Вывод средств платформы
     */
    function withdrawPlatformFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds");
        
        (bool success, ) = PLATFORM_ADDRESS.call{value: balance}("");
        require(success, "Transfer failed");
    }
    
    /**
     * @dev Получение баланса контракта
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Получение информации о бизнесе
     */
    function getBusinessInfo(address _business) external view returns (
        uint256 deposit,
        uint256 spent,
        uint256 employeeCount,
        bool active
    ) {
        BusinessAccount storage business = businessAccounts[_business];
        return (business.deposit, business.spent, business.employeeCount, business.active);
    }
    
    /**
     * @dev Получение списка сотрудников бизнеса
     */
    function getBusinessEmployees(address _business) external view returns (address[] memory) {
        return businessEmployees[_business];
    }
    
    // ==========================================
    // FALLBACK / RECEIVE
    // ==========================================
    
    receive() external payable {
        deposit();
    }
}
