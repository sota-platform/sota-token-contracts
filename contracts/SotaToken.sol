// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
import "@openzeppelin/contracts/token/ERC20/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SotaToken is ERC20, ERC20Capped, ERC20Burnable, Ownable {

    uint public allowTransferOn = 1617123600; // 2021-03-31 0:00:00 GMT+7 timezone
    mapping (address => bool ) public whiteListTransfer;

    /**
     * @dev Constructor function of Sota Token
     * @dev set name, symbol and decimal of token
     * @dev mint totalSupply (cap) to deployer
     */
    constructor (
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 cap
    ) public ERC20(name, symbol) ERC20Capped(cap) {
        _setupDecimals(decimals);
        _mint(_msgSender(), cap);
        whiteListTransfer[_msgSender()] = true;
    }

    /**
     * @dev Admin whitelist/un-whitelist transfer  
     * @dev to allow address transfer
     * @dev token before allowTransferOn
     */
    function adminWhiteList(address _whitelistAddr, bool _whiteList) public onlyOwner returns (bool) {
        whiteListTransfer[_whitelistAddr] = _whiteList;
        return true;
    }

    /**
     * @dev Admin can set allowTransferOn to   
     * @dev any time before 2021-03-31 0:00:00 GMT+7
     */
    function adminSetTime(uint _newTransferTime) public onlyOwner returns (bool) {
        require(block.timestamp < allowTransferOn && _newTransferTime < allowTransferOn, "Invalid-time");
        allowTransferOn = _newTransferTime;
        return true;
    }

    function transfer(address to, uint amount) public override(ERC20) returns (bool) {
        require(block.timestamp > allowTransferOn || whiteListTransfer[msg.sender], "Can-not-transfer");
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint amount) public override(ERC20) returns (bool) {
        require(block.timestamp > allowTransferOn || whiteListTransfer[msg.sender], "Can-not-transfer");
        return super.transferFrom(from, to, amount);
    }
     /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC20, ERC20Capped) {
        super._beforeTokenTransfer(from, to, amount);
    }
}
