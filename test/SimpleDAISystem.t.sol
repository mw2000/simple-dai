// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {SimpleDAISystem} from "../src/SimpleDAISystem.sol";
import {MockV3Aggregator} from "../src/mocks/MockV3Aggregator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Interest} from "../src/Interest.sol";

contract SimpleDAISystemTest is Test {
    SimpleDAISystem public simpleDai;
    MockV3Aggregator public mockV3Aggregator;

    uint8 public constant DECIMALS = 8;
    int256 public constant INIT_ANSWER = 250 * 10**8; // Example ETH/USD price
    uint256 public constant STABILITY_FEE = 5e16; // 5% annual
    uint256 public constant SECONDS_PER_YEAR = 31536000; // 60*60*24*365

    function setUp() public {
        mockV3Aggregator = new MockV3Aggregator(DECIMALS, INIT_ANSWER);        
        simpleDai = new SimpleDAISystem(address(mockV3Aggregator));
    }

    function testCollateralValueOfDai() public {
        uint256 collateralAmount = 1 ether;
        uint256 collateralValue = simpleDai.getCollateralValueInDai(collateralAmount);
        // Normalizing the value to 1e18
        assertEq((uint256(INIT_ANSWER) * 1e18) / 1e8, collateralValue);
    }

    function testdepositVaultGenerateDai() public {
        uint256 collateralAmount = 1 ether;
        uint256 daiAmount = 100 * 1e18; // Example Dai amount

        // Simulate sending ETH with the transaction
        vm.deal(address(this), collateralAmount);

        // Deposit ETH and generate Dai
        vm.startPrank(address(this));
        simpleDai.depositVaultGenerateDai{value: collateralAmount}(daiAmount);
        vm.stopPrank();

        // Check vault values
        (uint256 collateral, uint256 debt, ) = simpleDai.vaults(address(this));
        assertEq(collateral, collateralAmount);
        assertEq(debt, daiAmount);
    }

    function testWithdrawCollateral() public {
        uint256 collateralAmount = 1 ether;
        uint256 withdrawAmount = 0.5 ether;
        uint256 daiAmount = 100 * 1e18;

        // Setup vault
        vm.deal(address(this), collateralAmount);
        simpleDai.depositVaultGenerateDai{value: collateralAmount}(daiAmount);

        // Withdraw collateral
        vm.startPrank(address(this));
        simpleDai.withdrawCollateral(withdrawAmount);
        vm.stopPrank();

        // Check vault and balance
        (uint256 collateral, ,) = simpleDai.vaults(address(this));
        assertEq(collateral, collateralAmount - withdrawAmount);
        assertEq(address(this).balance, withdrawAmount);
    }

    function testLiquidation() public {
        uint256 collateralAmount = 4 ether;
        uint256 daiAmount = 300 * 1e18; // Higher Dai to force undercollateralization

        // Setup vault
        vm.deal(address(this), collateralAmount);
        simpleDai.depositVaultGenerateDai{value: collateralAmount}(daiAmount);

        // Change the ETH price to simulate undercollateralization
        int256 newPrice = 100 * 10**8; // Lower ETH/USD price
        mockV3Aggregator.updateAnswer(newPrice);

        // Liquidate
        vm.startPrank(address(913));
        simpleDai.liquidateVault(address(this), 1 ether);
        vm.stopPrank();

        // Check vaults after liquidation
        (uint256 collateralAfter, uint256 debtAfter, ) = simpleDai.vaults(address(this));
        assertEq(collateralAfter, 3 ether);
        assertEq(debtAfter, 200 ether);
    }

    function testTotalLossInLiquidation() public {
        uint256 collateralAmount = 1 ether;
        uint256 daiAmount = 30 * 1e18; // High Dai amount to force severe undercollateralization

        // Setup vault
        vm.deal(address(this), collateralAmount);
        simpleDai.depositVaultGenerateDai{value: collateralAmount}(daiAmount);

        // Change the ETH price to simulate severe undercollateralization
        int256 newPrice = 30 * 10**8; // Extremely low ETH/USD price
        mockV3Aggregator.updateAnswer(newPrice);

        // Liquidate
        vm.startPrank(address(913));
        simpleDai.liquidateVault(address(this), collateralAmount);
        vm.stopPrank();

        // Check vaults after liquidation
        (uint256 collateralAfter, uint256 debtAfter, ) = simpleDai.vaults(address(this));
        assertEq(collateralAfter, 0, "All collateral should be seized");
        assertEq(debtAfter, 0, "Debt should be cleared");
    }


    function testPayBackDai() public {
        uint256 collateralAmount = 1 ether;
        uint256 daiAmount = 30 * 1e18; // Amount of Dai to generate

        // Setup vault by depositing ETH and generating Dai
        vm.deal(address(this), collateralAmount);
        simpleDai.depositVaultGenerateDai{value: collateralAmount}(daiAmount);

        // Simulate paying back some Dai
        uint256 payBackAmount = 10 * 1e18; // Amount of Dai to pay back

        // Approve the Dai amount to the SimpleDAISystem contract
        IERC20(simpleDai.daiToken()).approve(address(simpleDai), payBackAmount);
        assert(IERC20(simpleDai.daiToken()).balanceOf(address(this)) == 30 ether);

        // Pay back Dai
        vm.startPrank(address(this));
        simpleDai.payBackDai(payBackAmount);
        vm.stopPrank();

        // // Check the updated debt in the vault
        (, uint256 debtAfterPayback, ) = simpleDai.vaults(address(this));
        assertEq(debtAfterPayback, daiAmount - payBackAmount);
    }

    function testCompoundInterestAccrual() public {
        uint256 collateralAmount = 1 ether;
        uint256 daiAmount = 10 * 1e18; // Example Dai amount
        uint256 secondsElapsed = 31536000; // Number of blocks to elapse

        // Deposit ETH and generate Dai
        vm.deal(address(this), collateralAmount);
        simpleDai.depositVaultGenerateDai{value: collateralAmount}(daiAmount);

        // Simulate the passage of blocks
        vm.warp(block.timestamp + 31536000);
        simpleDai.withdrawCollateral(0);

        // Calculate the expected debt amount with compound interest
        uint256 rayRate = Interest.yearlyRateToRay(STABILITY_FEE);
        uint256 expectedDebt = Interest.accrueInterest(daiAmount, rayRate, secondsElapsed);

        // Check if the vault's debt matches the expected debt
        (, uint256 debtAfterAccrual, ) = simpleDai.vaults(address(this));
        assertEq(debtAfterAccrual, expectedDebt);
    }

    receive() external payable {}
}
