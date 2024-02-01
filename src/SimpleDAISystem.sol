pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);
  function description() external view returns (string memory);
  function version() external view returns (uint256);
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}

contract SimplifiedDaiStablecoinSystem {
    AggregatorV3Interface internal priceFeed;
    IERC20 public daiToken;

    event Liquidation(address indexed vaultOwner, address indexed liquidator, uint256 collateralSeized, uint256 debtTransferred);

    // Struct to represent a vault
    struct Vault {
        uint256 collateralAmount; // in ETH
        uint256 debtAmount; // Dai generated against the collateral
    }
    
    mapping(address => Vault) public vaults;

    // You need to replace this with the actual Chainlink Data Feed address for ETH/USD for your network
    constructor(address _priceFeedAddress, address _daiTokenAddress) public {
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
        daiToken = IERC20(_daiTokenAddress);
    }
    
    // Deposit ETH as collateral and generate Dai
    function createVault(uint256 _daiAmount) public payable {
        require(msg.value > 0, "Collateral must be greater than 0");
        require(_daiAmount > 0, "Dai amount must be greater than 0");
        
        vaults[msg.sender].collateralAmount += msg.value;
        
        // Check if the vault is above the minimum collateralization ratio, if so generate Dai
        require(isVaultSafe(msg.sender), "Vault is below minimum collateralization ratio");
        daiToken.transfer(msg.sender, _daiAmount);
        vaults[msg.sender].debtAmount += _daiAmount;
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
        uint256 collateralValueInDai = uint256(price) * _collateralAmount / 1e18;
        return collateralValueInDai;
    }
    
    // Allow users to withdraw their ETH collateral (partial or full)
    // Additional logic for handling debt, interest, and collateralization ratio to be added
    function withdrawCollateral(uint256 _withdrawAmount) public {
        require(_withdrawAmount <= vaults[msg.sender].collateralAmount, "Not enough collateral");
        
        // Check if the vault is still safe after withdrawal
        require(isVaultSafe(msg.sender), "Vault would be undercollateralized");
        
        vaults[msg.sender].collateralAmount -= _withdrawAmount;
        msg.sender.transfer(_withdrawAmount);
    }
        
    // Liquidate a vault
    function liquidateVault(address _vaultOwner) public {
        require(!isVaultSafe(_vaultOwner), "Vault is already safe");
        
        Vault storage vault = vaults[_vaultOwner];
        uint256 collateralValueInDai = getCollateralValueInDai(vault.collateralAmount);
        uint256 debtAmount = vault.debtAmount;
        
        // Calculate the amount of collateral to be seized
        uint256 collateralToSeize = (collateralValueInDai * debtAmount) / collateralValueInDai;
        
        // Transfer the seized collateral to the liquidator
        vaults[_vaultOwner].collateralAmount -= collateralToSeize;
        vaults[msg.sender].collateralAmount += collateralToSeize;
        
        // Transfer the debt amount from the liquidated vault to the liquidator
        vaults[_vaultOwner].debtAmount = 0;
        vaults[msg.sender].debtAmount += debtAmount;
        
        // Emit an event to indicate the liquidation
        emit Liquidation(_vaultOwner, msg.sender, collateralToSeize, debtAmount);
    }

    // Pay back Dai
    function payBackDai(uint256 _daiAmount) public {
        require(_daiAmount > 0, "Dai amount must be greater than 0");
        require(vaults[msg.sender].debtAmount >= _daiAmount, "Not enough debt to pay back");

        vaults[msg.sender].debtAmount -= _daiAmount;
        daiToken.transferFrom(msg.sender, address(this), _daiAmount);
    }
}
