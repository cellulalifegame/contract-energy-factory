// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import '../lib/VRGDA.sol';

contract VRGDA_Test {
    function getVRGDAPrice(int256 timeSinceStart, int256 targetPrice, int256 decayConstant, int256 targetSaleTime) public pure returns (uint256) {
        return VRGDA.getVRGDAPrice(timeSinceStart, targetPrice, decayConstant, targetSaleTime);
    }
    function getTargetSaleTimeLinear(int256 sold, int256 perTimeUnit) public pure returns (int256) {
        return VRGDA.getTargetSaleTimeLinear(sold, perTimeUnit);
    }
    function getTargetSaleTimeLogisticToLinear(int256 sold, int256 soldBySwitch, int256 switchTime, int256 logisticLimit, int256 timeScale, int256 perTimeUnit) public pure returns (int256) {
        return VRGDA.getTargetSaleTimeLogisticToLinear(sold, soldBySwitch, switchTime, logisticLimit, timeScale, perTimeUnit);
    }

    // unused
    function getTargetSaleTimeLogistic(int256 sold, int256 logisticLimit, int256 timeScale) public pure returns (int256) {
        return VRGDA.getTargetSaleTimeLogistic(sold, logisticLimit, timeScale);
    }
}
