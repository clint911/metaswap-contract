// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//contract Address 0x69af5c1c69458b894b3578890ae62beb70154bd9
//New Contract Address: 0x8088e75c9cada23a8becd6e0e250399f5b221176
contract TokenSwap {
    IERC20 public sdt;
    IERC20 public skt;

    uint256 public constant FEE = 3; // 3%

    uint256 public sdtReserve = 0; //initialized to 0 to avoid potential errors when adding liquidity for the first time
    uint256 public sktReserve = 0;

    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidityProviderBalance;
    uint256 public sdtFeePool; //accumulated fees for SDT
    uint256 public sktFeePool; //accumulated fees for SKT
    address public admin;

    event LiquidityAdded(
        address provider,
        uint256 sdtAmount,
        uint256 sktAmount,
        uint256 liquidityMinted
    );

    event LiquidityRemoved(
        address provider,
        uint256 sdtAmount,
        uint256 sktAmount,
        uint256 liquidityBurned
    );

    event TokensSwapped(
        address trader,
        address input,
        address output,
        uint256 inputAmount,
        uint256 outputAmount
    );

    constructor(address _sdt, address _skt) {
        sdt = IERC20(_sdt);
        skt = IERC20(_skt);
        admin = msg.sender;
    }

    function addLiquidity(
        uint256 _sdtAmount,
        uint _sktAmount
    ) external payable {
        require(
            _sdtAmount > 0 && _sktAmount > 0,
            "Amounts should be greater than zero"
        );
        //check if user has sufficient balance to add liquidity
        require(
            sdt.balanceOf(msg.sender) >= _sdtAmount,
            "Insufficient SDT balance"
        );
        require(
            skt.balanceOf(msg.sender) >= _sktAmount,
            "Insufficient SKT balance"
        );
        uint liquidityMinted = 0;
        //If it's the first liquidity, initialize reserves
        if (totalLiquidity == 0) {
            sdtReserve = _sdtAmount;
            sktReserve = _sktAmount;
            liquidityMinted = 1e18; //An initial supply of LP tokens
        } else {
            liquidityMinted =
                ((_sdtAmount * 1e18) * totalLiquidity) /
                sdtReserve;
        }
        //Transfer SDT and SKT from msg.sender
        sdt.transferFrom(msg.sender, address(this), _sdtAmount);
        skt.transferFrom(msg.sender, address(this), _sktAmount);
        //Mint LP tokens to msg.sender based on share
        liquidityProviderBalance[msg.sender] += liquidityMinted;
        totalLiquidity += liquidityMinted;
        //Emit event
        emit LiquidityAdded(
            msg.sender,
            _sdtAmount,
            _sktAmount,
            liquidityMinted
        );
    }

    function removeLiquidity(uint256 _amount) external {
        require(totalLiquidity > 0, "No Liquidity to remove");
        // Calculate SDT and SKT amounts to withdraw
        uint256 sdtAmount = (sdtReserve * _amount) / totalLiquidity;
        uint256 sktAmount = (sktReserve * _amount) / totalLiquidity;

        //Distribute accumulated fees to the liquidity provider based on their propotion
        uint256 sdtFeeShare = (sdtFeePool * _amount) / totalLiquidity;
        uint256 sktFeeShare = (sktFeePool * _amount) / totalLiquidity;

        sdtFeePool -= sdtFeeShare;
        sktFeePool -= sktFeeShare;

        //Transfer SDT and SKT to msg.sender
        sdt.transfer(msg.sender, sdtAmount + sdtFeeShare);
        skt.transfer(msg.sender, sdtAmount + sktFeeShare);

        //update Reserves
        sdtReserve -= sdtAmount;
        sktReserve -= sktAmount;

        //Burn sender's LP tokens
        totalLiquidity -= _amount;
        liquidityProviderBalance[msg.sender] -= _amount;

        //Emit event
        emit LiquidityRemoved(msg.sender, sdtAmount, sktAmount, _amount);
    }

    function getSwapAmount(
        uint256 _inputAmount,
        address _inputToken,
        address _outputToken
    ) public view returns (uint256) {
        //implement xy=k formula using stored reserves
        uint256 reserveInput = _inputToken == address(sdt)
            ? sdtReserve
            : sktReserve;
        uint256 reserveOutput = _outputToken == address(sdt)
            ? sdtReserve
            : sktReserve;
        uint256 numerator = reserveOutput * _inputAmount * 997;
        uint256 denominator = (reserveInput * 1000) + (_inputAmount * 997);
        return numerator / denominator;
    }

    function swapTokens(
        uint256 _amount,
        address _input,
        address _output
    ) external {
        require(_amount > 0, "Amount must be greater than zero");
        //Calculate the swap amount
        uint256 outputAmount = getSwapAmount(_amount, _input, _output);
        //Transfer input tokens from msg.sender to contract
        if (_input == address(sdt)) {
            sdtReserve += _amount;
            sdt.transferFrom(msg.sender, address(this), _amount);
        } else {
            sktReserve += _amount;
            skt.transferFrom(msg.sender, address(this), _amount);
        }

        //Transfer output tokens to msg.sender
        if (_output == address(sdt)) {
            sdt.transfer(msg.sender, outputAmount);
            sdtReserve -= outputAmount;
        } else {
            skt.transfer(msg.sender, outputAmount);
            sktReserve -= outputAmount;
        }
        //Charge Fee
        uint256 fee = (_amount * FEE) / 100;
        //Distribute fee: 50% to admin 50% to liquidity pool
        uint256 adminFee = fee / 2;
        uint256 poolFee = fee - adminFee;

        if (_input == address(sdt)) {
            sdtReserve -= fee;
            sdt.transfer(admin, adminFee);
            sdtFeePool += poolFee;
        } else {
            sktReserve -= fee;
            skt.transfer(admin, adminFee);
            sktFeePool += poolFee;
        }
        //Emit event
        emit TokensSwapped(msg.sender, _input, _output, _amount, outputAmount);
    }
}
