// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { toWadUnsafe, toDaysWadUnsafe, wadLn } from 'solmate/src/utils/SignedWadMath.sol';

contract SignedWadMath_Test {
    function _toWadUnsafe(uint256 x) public pure returns (int256 r) {
        return toWadUnsafe(x);
    }
    function _toDaysWadUnsafe(uint256 x) public pure returns (int256 r) {
        return toDaysWadUnsafe(x);
    }
    function _wadLn(int256 x) public pure returns (int256 r) {
        return wadLn(x);
    }
}
