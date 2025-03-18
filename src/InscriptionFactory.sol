pragma solidity ^0.8.0;

import "./InscriptionToken.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract InscriptionFactory {
    using Clones for address;
    
    address public immutable implementation;
    address public immutable feeCollector;
    uint256 public constant FEE_RATE = 100; // 1% = 100/10000
    
    mapping(address => bool) public isInscriptionToken;
    
    event InscriptionDeployed(
        address indexed tokenAddress,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    );

    event InscriptionMinted(
        address indexed token,
        address indexed to,
        uint256 amount,
        uint256 fee
    );

    constructor(address _feeCollector) {
        implementation = address(new InscriptionToken());
        feeCollector = _feeCollector;
    }

    function deployInscription (
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address) {
        address clone = implementation.clone();
        
        // 初始化克隆合约
        InscriptionToken(clone).initialize(
            symbol,
            totalSupply,
            perMint,
            price,
            msg.sender
        );
        
        isInscriptionToken[clone] = true;
        
        emit InscriptionDeployed(clone, symbol, totalSupply, perMint, price);
        return clone;
    }

    function mintInscription(address tokenAddr) external payable {
        require(isInscriptionToken[tokenAddr], "Not an inscription token");
        
        InscriptionToken token = InscriptionToken(tokenAddr);
        require(msg.value == token.price() * token.perMint()/1 ether, "Invalid payment amount");
        
        // 计算手续费
        uint256 fee = (msg.value * FEE_RATE) / 10000;
        uint256 creatorPayment = msg.value - fee;
        
        // 转账给创建者和收费地址
        (bool success1, ) = feeCollector.call{value: fee}("");
        require(success1, "Fee transfer failed");
        
        (bool success2, ) = token.creator().call{value: creatorPayment}("");
        require(success2, "Creator payment failed");
        
        // 铸造代币
        token.mint{value: 0}(msg.sender);
        
        emit InscriptionMinted(tokenAddr, msg.sender, token.perMint(), fee);
    }
}
