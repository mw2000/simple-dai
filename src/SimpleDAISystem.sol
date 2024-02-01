pragma solidity ^0.8.13;

import {IDai, Dai} from "src/Dai.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SimpleDAISystem {
    // Goerli price feed for ETH/USD
    AggregatorV3Interface internal priceFeed;
    address public daiToken;

    event Liquidation(address indexed vaultOwner, address indexed liquidator, uint256 collateralSeized, uint256 debtTransferred);

    // Struct to represent a vault
    struct Vault {
        uint256 collateralAmount; // in ETH
        uint256 debtAmount; // Dai generated against the collateral
    }
    
    mapping(address => Vault) public vaults;

    // You need to replace this with the actual Chainlink Data Feed address for ETH/USD for your network
    constructor(address _priceFeedAddress) {
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
        daiToken = address(new Dai());
    }
    
    // Deposit ETH as collateral and generate Dai
    function depositVault(uint256 _daiAmount) public payable {
        require(msg.value > 0, "Collateral must be greater than 0");
        require(_daiAmount > 0, "Dai amount must be greater than 0");
        
        vaults[msg.sender].collateralAmount += msg.value;
        vaults[msg.sender].debtAmount += _daiAmount;

        // Check if the vault is above the minimum collateralization ratio
        require(isVaultSafe(msg.sender), "Vault is below minimum collateralization ratio");

        IDai(daiToken).mint(_daiAmount);
        IERC20(daiToken).transfer(msg.sender, _daiAmount);
    }
    
    // Function to check the collateralization ratio
    function isVaultSafe(address _vaultOwner) public view returns (bool) {
        Vault storage vault = vaults[_vaultOwner];
        uint256 collateralValueInDai = getCollateralValueInDai(vault.collateralAmount);
        uint256 minimumRequiredValue = vault.debtAmount * 150 / 100; // 150% collateralization ratio
        return collateralValueInDai >= minimumRequiredValue;
    }
    
    // Function to get the collateral value in Dai
    function getCollateralValueInDai(uint256 _collateralAmount) public view returns (uint256) {
        (,int price,,,) = priceFeed.latestRoundData();
        // Assuming the price is in USD with 8 decimal places, and 1 ETH = 1e18 wei
        uint256 collateralValueInDai = (uint256(price) * _collateralAmount) / 1e8;
        return collateralValueInDai;
    }
    
    // Allow users to withdraw their ETH collateral (partial or full)
    // Additional logic for handling debt, interest, and collateralization ratio to be added
    function withdrawCollateral(uint256 _withdrawAmount) public {
        require(_withdrawAmount <= vaults[msg.sender].collateralAmount, "Not enough collateral");
        
        // Check if the vault is still safe after withdrawal
        require(isVaultSafe(msg.sender), "Vault would be undercollateralized");
        
        vaults[msg.sender].collateralAmount -= _withdrawAmount;
        payable(msg.sender).transfer(_withdrawAmount);
    }
        
    // Liquidate a vault
    function liquidateVault(address _vaultOwner, uint256 _collateralAmount) public {
        require(!isVaultSafe(_vaultOwner), "Vault is already safe");

        Vault storage vault = vaults[_vaultOwner];
        uint256 collateralAmountValueInDai = getCollateralValueInDai(_collateralAmount);

        vault.collateralAmount -= _collateralAmount;
        vault.debtAmount -= (collateralAmountValueInDai > vault.debtAmount ?  vault.debtAmount : collateralAmountValueInDai);

        if (vault.debtAmount > 0) {
            require(
                (getCollateralValueInDai(vault.collateralAmount) * 100 / vault.debtAmount) >= 150, 
                "Can't force liquidation below 150%"
            );
        }

        // Transfer the seized collateral to the liquidator
        payable(msg.sender).transfer(_collateralAmount);

        // Emit an event to indicate the liquidation
        emit Liquidation(_vaultOwner, msg.sender, _collateralAmount, collateralAmountValueInDai);
    }

    // Pay back Dai
    function payBackDai(uint256 _daiAmount) public {
        require(_daiAmount > 0, "Dai amount must be greater than 0");
        require(vaults[msg.sender].debtAmount >= _daiAmount, "Not enough debt to pay back");

        IERC20(daiToken).transferFrom(msg.sender, address(this), _daiAmount);
        vaults[msg.sender].debtAmount -= _daiAmount;
        IDai(daiToken).burn(_daiAmount);
    }

    receive() external payable {}
}
