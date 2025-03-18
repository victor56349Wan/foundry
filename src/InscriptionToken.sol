pragma solidity ^0.8.0;
import "./erc20Init.sol";
import "forge-std/console.sol";
contract InscriptionToken is ERC20Init {
    address public creator;
    uint256 public perMint;
    uint256 public price;
    uint256 public minted;
    bool public initialized;


    function initialize(
        string memory _symbol,
        uint256 _totalSupply,
        uint256 _perMint,
        uint256 _price,
        address _creator
    ) public {
        require(_totalSupply > 0, "Total supply must be positive");
        require(_perMint > 0 && _perMint <= _totalSupply, "Invalid perMint amount");
        require(_price > 0, "Price must be positive");
        require(initialized == false, "Already initialized");
        name = string(abi.encodePacked("Inscription Token ", _symbol));
        symbol = _symbol;
        totalSupply = _totalSupply;
        decimals = 18;
        perMint = _perMint;
        price = _price;
        creator = _creator;
        initialized = true;
    }
        

    function mint(address to) external payable {
        
        require(minted + perMint <= totalSupply, "Exceeds total supply");
        minted += perMint;
        _mint(to, perMint);
    }
    function _mint(address account, uint256 amount) internal override {
        require(account != address(0), "ERC20: cannot mint to the zero address");

        balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }    
}
