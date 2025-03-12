// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ExtERC20.sol";
import "../src/tokenBank.sol";
import "../src/NFTMarket.sol";
import "../src/BaseERC721.sol";

contract ExtERC20Test is Test {
    ExtERC20 public extERC20;
    TokenBankV2 public tokenBankV2;
    NFTMarket public nftMarket;
    BaseERC721 public nftToken;

    address public user1;
    address public user2;
    address public user3;
    address public user4;

    function setUp() public {
        user1 = address(1);
        user2 = address(2);
        user3 = address(3);
        user4 = address(4);

        extERC20 = new ExtERC20("Extended Token", "EXT", 18, 10**6 * 10**18);
        tokenBankV2 = new TokenBankV2(address(extERC20));
        string memory baseURI = "ipfs://QmdYeDpkVZedk1mkGodjNmF35UNxwafhFLVvsHrWgJoz6A/beanz_metadata";
        nftToken = new BaseERC721("MockERC721", "MNFT", baseURI);
        nftMarket = new NFTMarket(address(nftToken), address(extERC20));
    }

    function testMint() public {
        uint256 amount = 100 * 10**18;
        extERC20.mint(user1, amount);
        assertEq(extERC20.balanceOf(user1), amount);
        assertEq(extERC20.totalSupply(), 10**6 * 10**18 + amount);
        
    }
    
    function testMintFail() public {
        uint256 amount = 100 * 10**18;
        vm.startPrank(user1);
        vm.expectRevert("Only the owner can perform this action");
        extERC20.mint(user1, amount);
        vm.stopPrank();
    }

    function testTransferWithCallbackToContract() public {
        uint256 amount = 100 * 10**18;
        extERC20.mint(user1, amount);
        uint256 initialBalance = extERC20.balanceOf(user1);
        
        // transfer 100 to tokenBank
        vm.startPrank(user1);
        extERC20.transferWithCallback(address(tokenBankV2), amount, "");
        vm.stopPrank();

        assertEq(extERC20.balanceOf(user1), initialBalance - amount);
        assertEq(tokenBankV2.balances(user1), amount);
        assertEq(extERC20.balanceOf(address(tokenBankV2)), 0);
    }

    function testTransferWithCallbackToEOA() public {
        uint256 amount = 100 * 10**18;
        extERC20.mint(user1, amount);

        uint256 initialBalanceUser1 = extERC20.balanceOf(user1);
        uint256 initialBalanceUser2 = extERC20.balanceOf(user2);

        vm.startPrank(user1);
        extERC20.transferWithCallback(user2, amount, "");
        vm.stopPrank();

        assertEq(extERC20.balanceOf(user1), initialBalanceUser1 - amount);
        assertEq(extERC20.balanceOf(user2), initialBalanceUser2 + amount);
    }

    function testTransferWithCallbackRevert() public {
        uint256 amount = 100 * 10**18;
        extERC20.mint(user1, amount);
        uint256 tokenId=1;
        nftToken.mint(user1,tokenId);
        nftToken.approve(address(nftMarket),tokenId);
        nftMarket.list(tokenId,amount);
        //console.log('listing price',nftMarket.getPrice(tokenId));
        vm.startPrank(user1);
        vm.expectRevert("call tokensReceived failed");
        extERC20.transferWithCallback(address(nftMarket), amount, abi.encode(tokenId));
        vm.stopPrank();
    }

    function testTransferWithCallbackInsufficientBalance() public {
        uint256 amount = 100 * 10**18;
        extERC20.mint(user1, amount);
        vm.startPrank(user2);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        extERC20.transferWithCallback(user1, amount, "");
        vm.stopPrank();
    }
    function testTokenBankV2Deposit(){
        uint256 amount = 100 * 10**18;
        extERC20.mint(user1, amount);
        vm.startPrank(user1);
        extERC20.transferWithCallback(address(tokenBankV2),amount,"");
        vm.stopPrank();
        assertEq(tokenBankV2.balances(user1),amount);
    }
    function testTokenBankV2DepositOtherToken(){
        MyToken myToken = new MyToken("MyToken","MTK");
        uint256 amount = 100 * 10**18;
        vm.expectRevert("Not my supported ERC20");
        tokenBankV2.tokensReceived(amount, "");
    }

}
