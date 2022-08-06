// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

contract MacroNFT is ERC721, Ownable, ERC2771Context {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor(address forwarder) ERC721("MacroNFT", "MNFT") ERC2771Context(forwarder) {
    }

    function _msgSender() internal view virtual
        override(ERC2771Context, Context) returns (address) {
        return super._msgSender();
    }

    function _msgData() internal view virtual
        override(ERC2771Context, Context) returns (bytes calldata) {
        return super._msgData();
    }


    function mint(address to) public onlyOwner {
        _tokenIds.increment();

        uint256 newTokenId = _tokenIds.current();
        _mint(to, newTokenId);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://example.com/tokens/";
    }
}
