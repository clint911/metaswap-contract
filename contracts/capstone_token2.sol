// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//contract address 0xb7d7a73cd706977c350e75658962e16cc82769a7
//New Contract Address: 0x78bedce71cf5ba60f50e594be084470d5f337ee8
contract SKT is ERC20 {
    constructor() ERC20("StacKoin Token,", "SKT") {
        _mint(msg.sender, 1000000 * (10 ** decimals()));
    }
}
