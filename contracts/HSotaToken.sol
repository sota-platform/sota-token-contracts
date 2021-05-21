// SPDX-License-Identifier: MIT
pragma solidity 0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract HSotaToken is ERC20("SOTA", "SOTA"), ERC20Burnable, Ownable {
    using SafeMath for uint256;
    uint256 public FEE = 10;
    uint256 public feeCollected;
    mapping(address => bool) private whiteList;

    event Swap(
        address indexed _from,
        address indexed _to,
        uint256 indexed _amount
    );

    modifier onlyWhiteList() {
        require(whiteList[msg.sender], "Only-whitelist-minter");
        _;
    }

    constructor() public {
        _setupDecimals(18);
    }

    function adminWhiteList(address _whitelistAddr, bool _whiteList)
        public
        onlyOwner
    {
        whiteList[_whitelistAddr] = _whiteList;
    }

    function mint(address _to, uint256 _amount) public onlyWhiteList {
        _mint(_to, _amount);
    }

    function swap(address _receiver, uint256 _amount) public {
        require(_amount > FEE, "Invalid-amount");
        uint256 swapAmount = _amount.sub(FEE);
        feeCollected = feeCollected.add(FEE);
        _burn(msg.sender, swapAmount);
        _transfer(msg.sender, address(this), FEE);
        emit Swap(msg.sender, _receiver, swapAmount);
    }

    function setSwapFee(uint256 _fee) public onlyOwner {
        FEE = _fee;
    }

    function adminWithdrawFee(address _to) public onlyOwner {
        _transfer(address(this), _to, feeCollected);
    }
}
