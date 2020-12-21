pragma solidity ^0.7.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./SaleManager.sol";
import "./interfaces/IUniswapV2Router02.sol";

contract SeedSale is SaleManager {
    using SafeMath for uint;
    using SafeERC20 for ERC20;
    uint public constant ZOOM_SOTA = 10 ** 18;
    uint public constant ZOOM_USDT = 10 ** 6;
    uint public price =  10 ** 5; // price / zoom = 0.1
    uint public MIN_AMOUNT = 1000 * 10 ** 6; // 1 usdt
    uint public MAX_AMOUNT = 10000 * 10 ** 6; // 10000 usdt
    uint public startTime = 1608470467;
    uint public endTime = 1609433999;
    address public usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public uniRouterV2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public sota;
    address public hot_wallet;
    mapping (address => uint) public totalBuy; 
    mapping (address => bool) public whiteListSigner;
    event Buy( address indexed buyer, uint indexed usdtAmount, uint indexed sotaAmount);
    modifier isBuyable(bytes memory sign) {
        require(!paused(), "Paused");
        require(startTime <= block.timestamp && block.timestamp <= endTime, "Can-not-buy");
        require(isKYC(sign), "User-not-KYC");
        _;
    }
    constructor(
        address _sota,
        address _hot_wallet
    ) 
        public {
        sota = _sota;
        hot_wallet = _hot_wallet;
        whiteListSigner[msg.sender] = true;
    }
    function isValidAmount(uint usdtAmout) private returns (bool) {
        uint newAmount = totalBuy[msg.sender].add(usdtAmout);
        return (MIN_AMOUNT <= newAmount && newAmount <= MAX_AMOUNT);
    }
    /**
     * @dev calculate sota token amount
     * @param usdtAmount amount USDT user deposit to buy
     */
    function calSota(uint usdtAmount) private returns (uint) {
        return usdtAmount.mul(ZOOM_SOTA).div(price);
    }
    /**
     * @dev allow user buy SOTA with USDT
     * @param usdtAmount amount USDT user deposit to buy
     */
    function buyWithUSDT(
        uint usdtAmount,
        bytes memory sign
    )   isBuyable(sign)
        public returns (bool) {
        require(isValidAmount(usdtAmount), "Invalid-amount-USDT");
        //transfer USDT to hot_wallet directly
        ERC20(usdt).safeTransferFrom(msg.sender, hot_wallet, usdtAmount);
        uint sotaAmount = calSota(usdtAmount);
        IERC20(sota).transfer(msg.sender, sotaAmount);
        totalBuy[msg.sender] = totalBuy[msg.sender].add(usdtAmount);
        emit Buy(msg.sender, usdtAmount, sotaAmount);
        return true;
    }   
    /**
     * @dev get path for exchange ETH->WETH->USDT via Uniswap
     */
    function getPathUSDTWETH() private pure returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; //WETH
        path[1] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; //USDT
        return path;
    }
    /**
     * @dev allow user buy SOTA with ETH, swap ETH to USDT though uniswap
     * @param expectedUSDT is min amount USDT user expect when swap from ETH
     * @param deadline is deadline of transaction can be process
     */
    function buyWithETH(
        uint expectedUSDT, 
        uint deadline,
        bytes memory sign
    ) 
        payable isBuyable(sign) public returns (bool){
        // swap ETH for USDT via Uniswap return amounts receive if success
        // transfer USDT to hot_wallet directly
        uint[] memory amounts = IUniswapV2Router02(uniRouterV2).swapExactETHForTokens{value: msg.value}(
            expectedUSDT,
            getPathUSDTWETH(),
            hot_wallet,
            deadline
        ); // amounts[0] = WETH, amounts[1] = USDT
        // calculate sota token amount from usdt received
        require(isValidAmount(amounts[1]), "Invalid-amount-USDT");
        uint sotaAmount = calSota(amounts[1]); //
        IERC20(sota).transfer(msg.sender, sotaAmount);
        totalBuy[msg.sender] = totalBuy[msg.sender].add(amounts[1]);
        emit Buy(msg.sender, amounts[1], sotaAmount);
        return true;
    }
    // ADMIN FEATURES
    /**
     * @dev admin set hot wallet
     */
    function changeHotWallet(address _newWallet) public onlyOwner returns (bool) {
        hot_wallet = _newWallet;
        return true;
    }
    function adminWhiteList(address _signer, bool _whiteList) public onlyOwner returns (bool) {
        whiteListSigner[_signer] = _whiteList;
        return true;
    }
    function isKYC(bytes memory signature) private returns (bool) {
        bytes32 dataHash = keccak256(abi.encodePacked(msg.sender));
        bytes32 prefixedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash));
        address recoverAddress = getRecoveredAddress(signature, prefixedHash);
        return whiteListSigner[recoverAddress];
    }  
     function getRecoveredAddress(bytes memory sig, bytes32 dataHash)
        private
        pure
        returns (address)
    {
        bytes32 ra;
        bytes32 sa;
        uint8 va;
        // Check the signature length
        if (sig.length != 65) {
            return address(0);
        }
        // Divide the signature in r, s and v variables
        assembly {
          ra := mload(add(sig, 32))
          sa := mload(add(sig, 64))
          va := byte(0, mload(add(sig, 96)))
        }
        if (va < 27) {
            va += 27;
        }
        address recoveredAddress = ecrecover(dataHash, va, ra, sa);
        return (recoveredAddress);
    }
}