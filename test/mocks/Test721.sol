// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import "lib/lssvm2/lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "lib/lssvm2/lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Test721 is ERC721, Ownable {
    constructor() ERC721("Test721", "T721") {}

    function mint(address to, uint256 id) public {
        _mint(to, id);
    }
}
