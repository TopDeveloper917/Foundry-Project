# Testing with NFTFY
1. Approve NFT token
https://goerli.etherscan.io/tx/0x277524a730ea980a3c72037414892a187754f8d1eaba047c8a51373976d74334
From: 0xde186721df2d737c7d3cc578f324c856fb9a1f7b
NFT: 0x1b39a0345f0b01a27606ba148f24f13cdc48fe67
InputData: 
#	Name	Type	   Data
0	to	    address	   0x8279BE8f740DBeDB05C0Ce165447E8bc1457a137 (Fractionalizer)
1	tokenId	uint256	   1

2. Fractionalize () in Fractionalizer
#	Name	        Type	    Data
0	_target	        address	    0x1B39A0345F0b01A27606BA148f24f13Cdc48FE67 (NFT Token address)
1	_tokenId	    uint256	    1
2	_name	        string	    My Vault - 01
3	_symbol	        string	    FIRST
4	_decimals	    uint8	    6
5	_fractionsCount	uint256	    2000000
6	_fractionPrice	uint256	    50000000000
7	_paymentToken	address	    0x0000000000000000000000000000000000000000

Another Tx
Select 2 NFTs -> Fixed Option
name: Integration of 2 collection NFTs, price: 0.02 ETH, Token Supply: 5, Symbol: ICN
Settings: approve for BatchMintBox (0xbbFfeF9d52F252CA60feFBcB73d7145dECee1804)
Pay fee: failed, but success for one NFT
Settings: approve for Fractionalizer

FractionsImpl: 0x04859E76a961E8B2530afc4829605013bEBD01A4
Fractions: 0x11EB38d2d3D13B8365D64f76DCa3539d6F7AA739 (Test: 0xf38EB9e060fC7104908dB80968B3E2a7A226b07F)
Fractionalizer: 0x8279BE8f740DBeDB05C0Ce165447E8bc1457a137

Unlock for Fractions sell
SignatureBasedPeerToPeerMarkets: 0xcda724130b20Bc21Cd99f98d3B90c1A834C21f47
OpenCollectivePurchase: Rockpool

# NEW CONTRACTS
- FractionsImpl: 0xfB8fC5Db81ED669b628c1d1B0b32ee50547D332E  
- Fractions: 
- Fractionalizer: 

