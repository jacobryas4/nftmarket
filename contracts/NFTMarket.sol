// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFTMarket is ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;

    address payable owner;
    uint256 listingPrice = 0.025 ether;

    constructor() {
        owner = payable(msg.sender);
    }

    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    }

    mapping(uint256 => MarketItem) private idToMarketItem;

    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address ownder,
        uint256 price,
        bool sold
    );

    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) public payable nonReentrant {
        // require statement to ensure they are sending some money
        require(price > 0, "Price must be at least 1 wei");

        // require statement to ensure they sent in enough money
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );

        // increment id to create unique for market item
        _itemIds.increment();

        // set the new id as a variable
        uint256 itemId = _itemIds.current();

        // pass it in to idToMarketItem, create mapping
        idToMarketItem[itemId] = MarketItem(
            itemId,
            nftContract,
            tokenId,
            payable(msg.sender),
            payable(address(0)), // the owner address is set to 0 because its a new item no one has purchased yet
            price,
            false
        );

        // transfer ownwership of the NFT to this contract from the seller (comes from openzeppelin)
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        // emit event that MarketItemCreated
        emit MarketItemCreated(
            itemId,
            nftContract,
            tokenId,
            msg.sender,
            address(0),
            price,
            false
        );
    }

    function createMarketSale(address nftContract, uint256 itemId)
        public
        payable
        nonReentrant
    {
        // get price and tokenId of item
        uint256 price = idToMarketItem[itemId].price;
        uint256 tokenId = idToMarketItem[itemId].tokenId;

        // require that the value sent is equal to the price, throw error if not
        require(
            msg.value == price,
            "Please submit the asking price in order to complete the purchase"
        );

        // send value to seller
        idToMarketItem[itemId].seller.transfer(msg.value);

        // transfer NFT from contract to new owner
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);

        // set the owner of the item to the buyer
        idToMarketItem[itemId].owner = payable(msg.sender);

        // set the items 'sold' value to true
        idToMarketItem[itemId].sold = true;

        // increment itemsSold to keep track of number of items sold
        _itemsSold.increment();

        // pay the owner of the contract
        payable(owner).transfer(listingPrice);
    }

    function fetchMarketItems() public view returns (MarketItem[] memory) {
        // total number of items currently created
        uint itemCount = _itemIds.current();

        // total number of unsold items
        uint unsoldItemCount = _itemIds.current() - _itemsSold.current();

        // local varable to keep track of items index in loop
        uint currentIndex = 0;

        // create empty array
        MarketItem[] memory items = new MarketItem[](unsoldItemCount);

        // loop through items to get a count of unsold
        for (uint i = 0; i < itemCount; i++) {
            // check items address and if its 0 we know its unsold
            if (idToMarketItem[i + 1].owner == address(0)) {
                // get the id of current looped item
                uint currentId = idToMarketItem[i + 1].itemId;
                // get that item
                MarketItem storage currentItem = idToMarketItem[currentId];
                // put current item in that items array
                items[currentIndex] = currentItem;
                // increment the currentIndex
                currentIndex += 1;
            }
        }
        
        // return the array
        return items;
    }

    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint totalItemCount = _itemIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;

        for (uint i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);

        for (uint i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                uint currentId = idToMarketItem[i + 1].itemId;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function fetchItemsCreated() public view returns (MarketItem[] memory) {
        uint totalItemCount = _itemIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;

        for (uint i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);

        for (uint i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                uint currentId = idToMarketItem[i + 1].itemId;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }

        return items;
    }
}
