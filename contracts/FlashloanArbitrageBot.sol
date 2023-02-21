// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@aave/protocol-v2/contracts/flashloan/base/FlashLoanReceiverBase.sol";
import "@aave/protocol-v2/contracts/interfaces/ILendingPool.sol";
import "@aave/protocol-v2/contracts/interfaces/ILendingPoolAddressesProvider.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/**
 * @title FlashLoanArbitragebot
 * @author geometricalDominator
 * @notice loans eth, converts to token, swaps token back to eth on another dex 
 */

contract FlashLoanArbitragebot is FlashLoanReceiverBase, Ownable {



    address private s_asset;
    address private s_tokenToBuy;
    IUniswapV2Router02 private immutable i_UniswapRouter;
    IUniswapV2Router02 private immutable i_SushiswapRouter;

    constructor(address _provider, IUniswapV2Router02 _uniswapRouter, IUniswapV2Router02 _sushiswapRouter) public FlashLoanReceiverBase(ILendingPoolAddressesProvider(_provider)) {
        i_UniswapRouter = _uniswapRouter;
        i_SushiswapRouter = _sushiswapRouter;
    }
    
    

    function executeOperation(address[] calldata assets, uint256[] calldata amounts, uint256[] calldata premiums, address /*_initiator*/ , bytes calldata /*_params*/) external override returns (bool) {
        uint256 amountOutMin = 1;
        uint256 amountIn = IERC20(s_asset).balanceOf(address(this));
        IERC20(s_asset).transferFrom(msg.sender, address(this), amountIn);
        IERC20(s_asset).approve(address(i_UniswapRouter), amountIn);
        
        address[] memory UniPath = new address[](2);
        UniPath[0] = s_asset;
        UniPath[1] = s_tokenToBuy;
        i_UniswapRouter.swapExactTokensForTokens(amountIn, amountOutMin, UniPath, msg.sender, block.timestamp);

        uint256 amountIn2 = IERC20(s_tokenToBuy).balanceOf(address(this));
        IERC20(s_tokenToBuy).transferFrom(msg.sender, address(this), amountIn2);
        IERC20(s_tokenToBuy).approve(address(i_SushiswapRouter), amountIn2);
        
        address[] memory SushiPath = new address[](2);
        UniPath[0] = s_tokenToBuy;
        UniPath[1] = s_asset;
        i_SushiswapRouter.swapExactTokensForTokens(amountIn2, amountOutMin, SushiPath, msg.sender, block.timestamp);

        if (amountIn < IERC20(s_asset).balanceOf(address(this)) + premiums[0]) {
            revert("Too small profit");
        }
        
        uint amountOwing = amounts[0].add(premiums[0]);
        IERC20(assets[0]).approve(address(LENDING_POOL), amountOwing);
        

        return true;
    }


    function requestFlashLoan(uint256 _amount) external {
        address receiverAddress = address(this);
        address[] memory assets = new address[](1);
        assets[0] = s_asset;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;
        address onBehalfOf = address(this);
        bytes memory params = "";
        uint16 referralCode = 0;

        LENDING_POOL.flashLoan(receiverAddress, assets, amounts, modes, onBehalfOf, params, referralCode);
    }

    function setAsset(address _asset) external onlyOwner() {
        s_asset = _asset;
    }

    function setTokenToBuy(address _token) external onlyOwner() {
        s_tokenToBuy = _token;
    }

    function withdraw(address _token) external onlyOwner() {
        IERC20 token = IERC20(_token);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    function getBalance(address _token) public view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function getAsset() view public returns (address) {
        return s_asset;
    }

    function getToken() view public returns (address) {
        return s_tokenToBuy;
    }


}