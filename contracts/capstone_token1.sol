// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//contract address 0x47df5ee100ff77c3e95152b82c456c814201d26b
//New contract Address: 0x54c3ee7748ac55181690f97f6ba1a8e6493b3cb6
contract SDT is ERC20 {
    constructor() ERC20("StackUp DST Token", "SDT") {
        _mint(msg.sender, 1000000 * (10 ** decimals()));
    }
}
