// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
import { ERC20 } from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract CellulaToken is ERC20 {
    constructor(address first_holder) ERC20('Cellula Token', 'CELA') {
        _mint(first_holder, 1_000_000_000 * 1e18);
    }
}
