// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {DefaultOperatorFilterer} from "operator-filter-registry/src/DefaultOperatorFilterer.sol";

import {ERC721A, IERC721A, ERC721AQueryable} from "./ERC721AQueryable.sol";
import {IFavor} from "./interfaces/IFavor.sol";
import {IMonsutaRegistry} from "./interfaces/IMonsutaRegistry.sol";
import {NameUtils} from "./utils/NameUtils.sol";
import {Base64} from "./utils/Base64.sol";

/**
 * @title Monsuta contract
 * @dev Extends ERC721 Non-Fungible Token Standard basic implementation
 */
contract Monsuta is
    ERC721AQueryable,
    Ownable,
    ReentrancyGuard,
    DefaultOperatorFilterer
{
    using Strings for uint256;
    using SafeERC20 for IERC20;

    enum MonsutaState {
        DEFAULT,
        EVOLVED,
        SOUL
    }

    struct Trade {
        uint256 tradeId;
        uint256 openingTokenId;
        uint256 closingTokenId;
        uint256 expiryDate;
        address tradeOpener;
        address tradeCloser;
        bool active;
    }

    // Public variables
    uint256 public constant SALE_START_TIMESTAMP = 1617580800;

    // Time after which monsutas are randomized and allotted
    uint256 public constant REVEAL_TIMESTAMP =
        SALE_START_TIMESTAMP + (86400 * 1);

    uint256 public constant MINT_PRICE = 0.09 ether;
    uint256 public constant MAX_NFT_SUPPLY = 8888;

    // Favor Rewards
    uint256 public constant SECONDS_IN_A_DAY = 86400;
    uint256 public constant INITIAL_ALLOTMENT = 500 * 1e18;
    uint256 public constant EVOLVED_MULTIPLIER = 3;

    uint256 public nameChangePrice = 500 * 1e18;
    uint256 public sacrificePrice = 250 * 1e18;
    uint256 public resurrectPrice = 750 * 1e18;

    uint256 public startingIndexBlock;
    uint256 public startingIndex;

    // Name
    mapping(uint256 => string) private tokenName;
    mapping(string => bool) private nameReserved;

    // $FAVOR token address
    address private favorAddress;

    // MonsutaRegistry contract address
    IMonsutaRegistry public registry;

    // Sale
    bool public salePaused = false;

    // Favor Rewards
    uint256 public emissionStart;
    uint256 public emissionEnd;
    uint256 public emissionPerDay = 25 * 1e18;

    mapping(uint256 => uint256) private _lastClaim;
    mapping(uint256 => uint256) private _tokenState;

    // Trade
    Trade[] public trades;

    // Metadata Variables
    mapping(uint256 => MonsutaState) public tokenState;

    string public defaultImageIPFSURIPrefix =
        "ipfs://QmWWMp4Srk6CC9nuGw7fJz6BfxNw7xT7QBHTtxFVRjQTzU/";
    string public evolvedImageIPFSURIPrefix =
        "ipfs://QmWWMp4Srk6CC9nuGw7fJz6BfxNw7xT7QBHTtxFVRjQTzU/";
    string public soulImageIPFSURIPrefix =
        "ipfs://QmWWMp4Srk6CC9nuGw7fJz6BfxNw7xT7QBHTtxFVRjQTzU/";
    string public placeholderImageIPFSURI =
        "ipfs://QmNpEwUUjBAqaKZ7hZcVDGnYqWyUdvATevxtvHmyVJVwLm";

    // Events
    event NameChange(uint256 indexed tokenId, string newName);
    event Sacrificed(
        uint256 indexed toEvolveId,
        uint256 indexed toSoulId,
        address caller
    );
    event Resurrect(
        uint256 indexed evolvedTokenId,
        uint256 indexed soulTokenId,
        address caller
    );

    event TradeOpened(
        uint256 indexed tradeId,
        address indexed tradeOpener,
        uint256 openingTokenId,
        uint256 closingTokenId,
        uint256 expiryDate
    );
    event TradeCancelled(uint256 indexed tradeId, address indexed tradeCloser);
    event TradeExecuted(
        uint256 indexed tradeId,
        address indexed tradeOpener,
        address indexed tradeCloser
    );

    // Modifiers
    modifier onlyTokenOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "!owner of token id");
        _;
    }

    /**
     * @dev Initializes the contract
     */
    constructor(string memory name, string memory symbol)
        ERC721A(name, symbol)
    {
        emissionStart = SALE_START_TIMESTAMP;
        emissionEnd = 1753876800;   // July 30th 2025 12:00 GMT
    }

    /**
     * @dev Returns name of the NFT at tokenId.
     */
    function tokenNameByIndex(uint256 tokenId)
        public
        view
        returns (string memory)
    {
        return tokenName[tokenId];
    }

    /**
     * @dev Returns if the name has been reserved.
     */
    function isNameReserved(string memory nameString)
        public
        view
        returns (bool)
    {
        return nameReserved[NameUtils.toLower(nameString)];
    }

    /**
     * @dev Returns the state of the NFT
     */
    function getTokenState(uint256 tokenId) public view returns (uint256) {
        return uint256(tokenState[tokenId]);
    }

    /**
     * @dev Gets current Monsuta Price
     */
    function getMintPrice() public view returns (uint256) {
        require(totalSupply() < MAX_NFT_SUPPLY, "Sale has already ended");

        return MINT_PRICE;
    }

    /**
     * @dev Mints Monsuta!
     */
    function mint(uint256 numberOfNfts) external payable nonReentrant {
        require(totalSupply() < MAX_NFT_SUPPLY, "Sale has already ended");
        require(!salePaused, "Sale is paused");
        require(block.timestamp >= SALE_START_TIMESTAMP, "not started");
        require(numberOfNfts > 0 && numberOfNfts < 21, "invalid numberOfNfts");
        require(
            totalSupply() + numberOfNfts <= MAX_NFT_SUPPLY,
            "Exceeds MAX_NFT_SUPPLY"
        );
        require(
            getMintPrice() * numberOfNfts == msg.value,
            "Ether value sent is not correct"
        );

        _safeMint(msg.sender, numberOfNfts, "");

        // Source of randomness.
        // Theoretical miner withhold manipulation possible but should be sufficient in a pragmatic sense
        if (
            startingIndexBlock == 0 &&
            (totalSupply() == MAX_NFT_SUPPLY ||
                block.timestamp >= REVEAL_TIMESTAMP)
        ) {
            startingIndexBlock = block.number;
        }
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 0;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721A, IERC721A)
        returns (string memory)
    {
        require(_exists(tokenId), "URI query for nonexistent token");

        string memory namePostfix = '"';
        if (bytes(tokenName[tokenId]).length != 0) {
            namePostfix = string(
                abi.encodePacked(": ", tokenName[tokenId], '"')
            );
        }

        if (startingIndex == 0) {
            return
                string(
                    abi.encodePacked(
                        "data:application/json;base64,",
                        Base64.encode(
                            abi.encodePacked(
                                '{"name": "Monsuta #',
                                tokenId.toString(),
                                namePostfix,
                                ', "description": "The Monsuta Collection", "image": "',
                                placeholderImageIPFSURI,
                                '" }'
                            )
                        )
                    )
                );
        }

        uint256 tokenIdToMetadataIndex = (tokenId + startingIndex) %
            MAX_NFT_SUPPLY;

        // Block scoping to avoid stack too deep error
        bytes memory uriPartsOfMetadata;
        {
            uriPartsOfMetadata = abi.encodePacked(
                ', "image": "',
                string(
                    abi.encodePacked(
                        baseURI(tokenId),
                        tokenIdToMetadataIndex.toString(),
                        ".jpeg"
                    )
                )
            );
        }

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        abi.encodePacked(
                            '{"name": "Monsuta #',
                            tokenId.toString(),
                            namePostfix,
                            ', "description": "The Monsuta Collection", ',
                            registry.getEncodedTraitsOfMonsutaId(
                                tokenId,
                                uint256(tokenState[tokenId])
                            ),
                            uriPartsOfMetadata,
                            '" }'
                        )
                    )
                )
            );
    }

    function baseURI(uint256 tokenId) public view returns (string memory) {
        MonsutaState _state = tokenState[tokenId];
        if (_state == MonsutaState.DEFAULT) {
            return defaultImageIPFSURIPrefix;
        } else if (_state == MonsutaState.EVOLVED) {
            return evolvedImageIPFSURIPrefix;
        } else {
            return soulImageIPFSURIPrefix;
        }
    }

    /**
     * @dev Finalize starting index
     */
    function finalizeStartingIndex() public {
        require(startingIndex == 0, "Starting index is already set");
        require(startingIndexBlock > 0, "Starting index block must be set");

        // Just a sanity case in the worst case if this function is called late (EVM only stores last 256 block hashes)
        if (block.number - startingIndexBlock > 255) {
            startingIndex =
                uint256(blockhash(block.number - 1)) %
                MAX_NFT_SUPPLY;
        } else {
            startingIndex =
                uint256(blockhash(startingIndexBlock)) %
                MAX_NFT_SUPPLY;
        }
        // Prevent default sequence
        if (startingIndex == 0) {
            startingIndex = startingIndex + 1;
        }
    }

    /**
     * @dev Changes the name for Monsuta tokenId
     */
    function changeName(uint256 tokenId, string memory newName)
        external
        onlyTokenOwner(tokenId)
    {
        require(NameUtils.validateName(newName) == true, "not valid new name");
        require(
            sha256(bytes(newName)) != sha256(bytes(tokenName[tokenId])),
            "same as the current one"
        );
        require(isNameReserved(newName) == false, "already reserved");

        // If already named, dereserve old name
        if (bytes(tokenName[tokenId]).length > 0) {
            toggleReserveName(tokenName[tokenId], false);
        }
        toggleReserveName(newName, true);
        tokenName[tokenId] = newName;

        _transferFavorAndBurn(msg.sender, nameChangePrice);

        emit NameChange(tokenId, newName);
    }

    /**
     * @dev Reserves the name if isReserve is set to true, de-reserves if set to false
     */
    function toggleReserveName(string memory str, bool isReserve) internal {
        nameReserved[NameUtils.toLower(str)] = isReserve;
    }

    /**
     * @dev sacrifice. 1 nft from default to evolved, 1 nft from default to soul
     */
    function sacrifice(uint256 toEvolveId, uint256 toSoulId)
        external
        onlyTokenOwner(toEvolveId)
        onlyTokenOwner(toSoulId)
    {
        require(
            tokenState[toEvolveId] == MonsutaState.DEFAULT,
            "!evolving item default"
        );
        require(
            tokenState[toSoulId] == MonsutaState.DEFAULT,
            "!soul item default"
        );

        tokenState[toEvolveId] = MonsutaState.EVOLVED;
        tokenState[toSoulId] = MonsutaState.SOUL;

        _transferFavorAndBurn(msg.sender, sacrificePrice);

        updateReward(toEvolveId);
        updateReward(toSoulId);

        emit Sacrificed(toEvolveId, toSoulId, msg.sender);
    }

    /**
     * @dev requires: evolved Monsuta NFT, soul Monsuta NFT and $FAVOR
     * For the evolved Monsuta NFT: retract() is activated
     * For the soul Monsuta NFT: descent() is activated
     * $FAVOR is burned
     */
    function resurrect(uint256 evolvedTokenId, uint256 soulTokenId)
        external
        onlyTokenOwner(evolvedTokenId)
        onlyTokenOwner(soulTokenId)
    {
        require(tokenState[soulTokenId] == MonsutaState.SOUL, "!soul");
        require(tokenState[evolvedTokenId] == MonsutaState.EVOLVED, "!evolved");

        tokenState[evolvedTokenId] = MonsutaState.DEFAULT;
        tokenState[soulTokenId] = MonsutaState.DEFAULT;

        updateReward(soulTokenId);
        updateReward(evolvedTokenId);

        _transferFavorAndBurn(msg.sender, resurrectPrice);

        emit Resurrect(evolvedTokenId, soulTokenId, msg.sender);
    }

    function _transferFavorAndBurn(address from, uint256 amount) internal {
        SafeERC20.safeTransferFrom(
            IERC20(favorAddress),
            from,
            address(this),
            amount
        );
        IFavor(favorAddress).burn(amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override(ERC721A, IERC721A) onlyAllowedOperator {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override(ERC721A, IERC721A) onlyAllowedOperator {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override(ERC721A, IERC721A) onlyAllowedOperator {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     */
    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual override(ERC721A) {
        super._beforeTokenTransfers(from, to, startTokenId, quantity);

        for (uint256 i; i < quantity; ) {
            uint256 tokenId = startTokenId + i;

            if (from != address(0)) {
                updateReward(tokenId);
                require(tokenState[tokenId] != MonsutaState.SOUL, "soul token");
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev When accumulated FAVORs have last been claimed for a Monsuta tokenId
     */
    function getLastClaim(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId), "!exist");

        uint256 lastClaimed = uint256(_lastClaim[tokenId]) != 0
            ? uint256(_lastClaim[tokenId])
            : emissionStart;
        return lastClaimed;
    }

    /**
     * @dev Accumulated FAVOR tokens for a Monsuta token id
     */
    function getAccumulated(uint256 tokenId) public view returns (uint256) {
        if (block.timestamp <= emissionStart) return 0;

        uint256 lastClaimed = getLastClaim(tokenId);

        // Sanity check if last claim was on or after emission end
        if (lastClaimed >= emissionEnd) return 0;

        uint256 accumulationPeriod = block.timestamp < emissionEnd
            ? block.timestamp
            : emissionEnd; // Getting the min value of both

        uint256 totalAccumulated = ((accumulationPeriod - lastClaimed) *
            emissionPerDay *
            multiplierFromState(tokenId)) / SECONDS_IN_A_DAY;

        // If claim hasn't been done before for the index, add initial allotment
        if (lastClaimed == emissionStart) {
            totalAccumulated += INITIAL_ALLOTMENT;
        }

        return totalAccumulated;
    }

    /**
     * @dev Accumulated all FAVOR tokens for all Monsuta balance
     */
    function getAccumulatedAll(address account) public view returns (uint256) {
        if (block.timestamp <= emissionStart) return 0;

        uint256 monsutaBalance = balanceOf(account);
        if (monsutaBalance == 0) return 0;

        uint256 totalAccumulated = 0;

        unchecked {
            uint256 tokenIdsIdx;
            address currOwnershipAddr;
            TokenOwnership memory ownership;
            for (
                uint256 i = _startTokenId();
                tokenIdsIdx != monsutaBalance;
                ++i
            ) {
                ownership = _ownershipAt(i);
                if (ownership.burned) {
                    continue;
                }
                if (ownership.addr != address(0)) {
                    currOwnershipAddr = ownership.addr;
                }
                if (currOwnershipAddr == account) {
                    tokenIdsIdx++;
                    uint256 claimQty = getAccumulated(i);
                    if (claimQty > 0) {
                        totalAccumulated = totalAccumulated + claimQty;
                    }
                }
            }
        }

        return totalAccumulated;
    }

    /**
     * @dev Claim mints FAVOR and supports multiple Monsuta token indices at once.
     */
    function claim(uint256[] memory tokenIndices) external returns (uint256) {
        require(
            block.timestamp > emissionStart,
            "Emission has not started yet"
        );

        uint256 totalClaimQty = 0;
        uint256 numOfToken = tokenIndices.length;
        require(numOfToken > 0, "zero length");

        for (uint256 i; i < numOfToken; ) {
            uint256 tokenId = tokenIndices[i];
            require(ownerOf(tokenId) == msg.sender, "sender is not the owner");

            uint256 claimQty = getAccumulated(tokenId);
            if (claimQty > 0) {
                totalClaimQty = totalClaimQty + claimQty;
                _lastClaim[tokenId] = block.timestamp;
            }

            unchecked {
                ++i;
            }
        }

        require(totalClaimQty > 0, "No accumulated Favor");
        IFavor(favorAddress).mint(msg.sender, totalClaimQty);
        return totalClaimQty;
    }

    /**
     * @dev Claim mints Favors for all my Monsuta nft balances
     */
    function claimAll() external returns (uint256) {
        uint256 monsutaBalance = balanceOf(msg.sender);
        require(monsutaBalance > 0, "zero balance");

        require(
            block.timestamp > emissionStart,
            "Emission has not started yet"
        );

        uint256 totalClaimQty = 0;

        unchecked {
            uint256 tokenIdsIdx;
            address currOwnershipAddr;
            TokenOwnership memory ownership;
            for (
                uint256 i = _startTokenId();
                tokenIdsIdx != monsutaBalance;
                ++i
            ) {
                ownership = _ownershipAt(i);
                if (ownership.burned) {
                    continue;
                }
                if (ownership.addr != address(0)) {
                    currOwnershipAddr = ownership.addr;
                }
                if (currOwnershipAddr == msg.sender) {
                    tokenIdsIdx++;
                    uint256 claimQty = getAccumulated(i);
                    if (claimQty > 0) {
                        totalClaimQty += claimQty;
                        _lastClaim[i] = block.timestamp;
                    }
                }
            }
        }

        require(totalClaimQty > 0, "No accumulated Favor");
        IFavor(favorAddress).mint(msg.sender, totalClaimQty);
        return totalClaimQty;
    }

    /**
     * @dev Hook for state change of monsuta nft
     * can be called by only Monsuta Token Contract
     */

    function updateReward(uint256 tokenId) internal {
        uint256 claimQty = getAccumulated(tokenId);
        if (claimQty > 0) {
            _lastClaim[tokenId] = block.timestamp;

            IFavor(favorAddress).mint(ownerOf(tokenId), claimQty);
        }
    }

    function multiplierFromState(uint256 tokenId)
        public
        view
        returns (uint256)
    {
        MonsutaState state = MonsutaState(_tokenState[tokenId]);
        if (state == MonsutaState.DEFAULT) {
            return 1;
        } else if (state == MonsutaState.EVOLVED) {
            return EVOLVED_MULTIPLIER;
        } else {
            return 0;
        }
    }

    function getTradeCount() public view returns (uint256) {
        return trades.length;
    }

    function isTradeExecutable(uint256 tradeId) public view returns (bool) {
        Trade memory trade = trades[tradeId];
        if (trade.expiryDate < block.timestamp) {
            return false;
        }
        if (!trade.active) {
            return false;
        }

        return true;
    }

    /**
     * @dev Open new trade
     */
    function openNewTrade(
        uint256 openingTokenId,
        uint256 closingTokenId,
        uint256 expiryDate
    ) external onlyTokenOwner(openingTokenId) {
        require(expiryDate > block.timestamp, "expiryDate <= block.timestamp");
        uint256 tradeId = trades.length;
        trades.push(
            Trade(
                tradeId,
                openingTokenId,
                closingTokenId,
                expiryDate,
                msg.sender,
                address(0),
                true
            )
        );

        emit TradeOpened(
            tradeId,
            msg.sender,
            openingTokenId,
            closingTokenId,
            expiryDate
        );
    }

    /**
     * @dev Cancel trade
     */
    function cancelTrade(uint256 tradeId) external {
        Trade memory trade = trades[tradeId];
        require(trade.tradeOpener == msg.sender, "!opener");
        require(
            trade.tradeCloser == address(0),
            "tradeCloser can't already be non-zero address"
        );
        require(
            trade.expiryDate > block.timestamp,
            "trade.expiryDate <= block.timestamp"
        );
        trades[tradeId] = Trade(
            trade.tradeId,
            trade.openingTokenId,
            trade.closingTokenId,
            trade.expiryDate,
            trade.tradeOpener,
            msg.sender,
            false
        );

        emit TradeCancelled(tradeId, msg.sender);
    }

    /**
     * @dev Execute Trade
     */
    function executeTrade(uint256 tradeId) external {
        Trade memory trade = trades[tradeId];
        require(trade.active, "!active trade");
        require(trade.expiryDate > block.timestamp, "expired");
        require(
            ownerOf(trade.closingTokenId) == msg.sender,
            "!owner of closing token"
        );

        _transfer(trade.tradeOpener, msg.sender, trade.openingTokenId);
        _transfer(msg.sender, trade.tradeOpener, trade.closingTokenId);

        trades[tradeId] = Trade(
            trade.tradeId,
            trade.openingTokenId,
            trade.closingTokenId,
            trade.expiryDate,
            trade.tradeOpener,
            msg.sender,
            false
        );

        emit TradeExecuted(trade.tradeId, trade.tradeOpener, msg.sender);
    }

    /// Admin Funcs

    /**
     * @dev Set Favor Contract address (Callable by owner)
     */
    function setFavor(address _favor) external onlyOwner {
        require(_favor != address(0), "!zero address");

        favorAddress = _favor;
    }

    /**
     * @dev Set MonsutaRegistry Contract address (Callable by owner)
     */
    function setRegistry(address _registry) external onlyOwner {
        require(_registry != address(0), "!zero address");

        registry = IMonsutaRegistry(_registry);
    }

    /**
     * @dev Starts / resumes / pauses the sale based on the state (Callable by owner)
     */
    function toggleSale() external onlyOwner {
        require(totalSupply() < MAX_NFT_SUPPLY, "Sale has ended");

        salePaused = !salePaused;
    }

    /**
     * @dev Metadata will be frozen once ownership of the contract is renounced
     */
    function changeURIs(
        string memory defaultImageURI,
        string memory evolvedImageURI,
        string memory soulImageURI,
        string memory placeholderURI
    ) external onlyOwner {
        defaultImageIPFSURIPrefix = defaultImageURI;
        evolvedImageIPFSURIPrefix = evolvedImageURI;
        soulImageIPFSURIPrefix = soulImageURI;
        placeholderImageIPFSURI = placeholderURI;
    }

    /**
     * @dev Set Name change price (Callable by owner)
     */
    function setNameChangePrice(uint256 _price) external onlyOwner {
        nameChangePrice = _price;
    }

    /**
     * @dev Set Sacrifice price (Callable by owner)
     */
    function setSacrificePrice(uint256 _price) external onlyOwner {
        sacrificePrice = _price;
    }

    /**
     * @dev Set Resurrection price (Callable by owner)
     */
    function setResurrectPrice(uint256 _price) external onlyOwner {
        resurrectPrice = _price;
    }

    /**
     * @dev Withdraw ether from this contract (Callable by owner)
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;

        uint256 dev = (balance * 15) / 100;
        Address.sendValue(
            payable(0xfed505c80b72cDca5f72292D4bF1D6194cF23669),
            dev
        );
        Address.sendValue(payable(msg.sender), balance - dev);
    }
}
