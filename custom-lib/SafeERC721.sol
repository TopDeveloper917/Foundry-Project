// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

library SafeERC721
{
	function safeName(IERC721Metadata _metadata) internal view returns (string memory _name)
	{
		try _metadata.name() returns (string memory _n) { return _n; } catch {}
	}

	function safeSymbol(IERC721Metadata _metadata) internal view returns (string memory _symbol)
	{
		try _metadata.symbol() returns (string memory _s) { return _s; } catch {}
	}

	function safeTokenURI(IERC721Metadata _metadata, uint256 _tokenId) internal view returns (string memory _tokenURI)
	{
		try _metadata.tokenURI(_tokenId) returns (string memory _t) { return _t; } catch {}
	}

	function safeTransfer(IERC721 _token, address _to, uint256 _tokenId) internal
	{
		address _from = address(this);
		try _token.transferFrom(_from, _to, _tokenId) { return; } catch {}
		// attempts to handle non-conforming ERC721 contracts
		_token.approve(_from, _tokenId);
		_token.transferFrom(_from, _to, _tokenId);
	}

	function safeApprove(IERC721 _token, address _to, uint256 _tokenId) internal
	{
		try IERC721(_token).approve(_to, _tokenId) {
		} catch (bytes memory /* _data */) {
		}
	}
}