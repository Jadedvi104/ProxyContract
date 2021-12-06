// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ECIOMarketplace is ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;
    Counters.Counter private _itemsCanceled;

    uint256 feesRate = 425;
    uint256 listingPrice = 100;

    constructor() {}

    struct MarketItem {
        address nftContract;
        uint256 itemId;
        uint256 tokenId;
        address seller;
        address owner;
        uint256 price;
        address buyWithTokenContract;
        bool sold;
        bool cancel;
    }

    mapping(uint256 => MarketItem) private idToMarketItem;

    event MarketItemUpdate(
        address indexed nftContract,
        uint256 indexed itemId,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        address buyWithTokenContract,
        bool sold,
        bool cancel
    );




    /* Returns the listing price of the contract */
    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    function cancelMarketItem(uint256 itemId) public nonReentrant {
        require(idToMarketItem[itemId].sold == false, "Sold item");
        require(idToMarketItem[itemId].cancel == false, "Canceled item");
        require(idToMarketItem[itemId].seller == msg.sender); // check if the person is seller

        idToMarketItem[itemId].cancel = true;

        //Transfer back to owner :: owner is marketplace now >>> original owner
        IERC721(idToMarketItem[itemId].nftContract).transferFrom(
            address(this),
            msg.sender,
            idToMarketItem[itemId].tokenId
        );
        _itemsCanceled.increment();

        emit MarketItemUpdate(
            idToMarketItem[itemId].nftContract,
            idToMarketItem[itemId].itemId,
            idToMarketItem[itemId].tokenId,
            address(0),
            msg.sender,
            idToMarketItem[itemId].price,
            idToMarketItem[itemId].buyWithTokenContract,
            true,
            false
        );

    }

    /* Places an item for sale on the marketplace */
    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        address buyWithTokenContract
    ) public payable nonReentrant {
        // set require ERC721 approve below
        require(price > 100, "Price must be at least 100 wei");
        _itemIds.increment();
        uint256 itemId = _itemIds.current();
        idToMarketItem[itemId] = MarketItem(
            nftContract,
            itemId,
            tokenId,
            msg.sender,
            address(0),
            price,
            buyWithTokenContract,
            false,
            false
        );

        // seller must approve market contract
        IERC721(nftContract).approve(address(this), tokenId);

        // tranfer NFT ownership to Market contract
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        emit MarketItemUpdate(
            nftContract,
            itemId,
            tokenId,
            msg.sender,
            address(0),
            price,
            buyWithTokenContract,
            false,
            false
        );
    }

    /* Creates the sale of a marketplace item */
    /* Transfers ownership of the item, as well as funds between parties */
    function createMarketSale(address nftContract, uint256 itemId)
        public
        payable
        nonReentrant
    {
        uint256 price = idToMarketItem[itemId].price;
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        address buyWithTokenContract = idToMarketItem[itemId].buyWithTokenContract;
        uint256 balance = ERC20(buyWithTokenContract).balanceOf(msg.sender);
        uint256 fee = price * feesRate / 10000;
        uint256 amount = price - fee;
        uint256 totalAmount = price + fee;

        require(
            balance >= totalAmount,
            "Your balance has not enough amount + including fee."
        );

        //call approve
        IERC20(buyWithTokenContract).approve(address(this), totalAmount);

        //Transfer fee to platform.
        IERC20(buyWithTokenContract).transferFrom(msg.sender, address(this), fee);

        //Transfer token(BUSD) to nft seller.
        IERC20(buyWithTokenContract).transferFrom(msg.sender, idToMarketItem[itemId].seller, amount);

        // idToMarketItem[itemId].seller.transfer(msg.value);
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);

        idToMarketItem[itemId].owner = msg.sender;
        idToMarketItem[itemId].sold = true;
        _itemsSold.increment();


        emit MarketItemUpdate(
            nftContract,
            itemId,
            tokenId,
            address(0),
            msg.sender,
            price,
            buyWithTokenContract,
            true,
            false
        );

    }

    /* Returns all unsold market items */
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 unsoldItemCount = _itemIds.current() -
            _itemsSold.current() -
            _itemsCanceled.current();

        uint256 currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);

        for (uint256 i = 0; i < itemCount; i++) {
            if (
                idToMarketItem[i + 1].sold == false &&
                idToMarketItem[i + 1].cancel == false
            ) {
                MarketItem storage currentItem = idToMarketItem[i + 1];
                items[currentIndex] = currentItem; /// ?
                currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns only items that a user has purchased */
    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                MarketItem storage currentItem = idToMarketItem[i + 1];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }



    /* Returns only items a user has created */
    function fetchItemsCreated() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }
}
