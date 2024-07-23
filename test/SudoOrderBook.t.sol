// SPDX-License-Identifier: AGPL-3.0

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable var-name-mixedcase */
/* solhint-disable func-param-name-mixedcase */
/* solhint-disable no-unused-vars */
/* solhint-disable func-name-mixedcase */

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "lib/lssvm2/lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

// Sudo specific imports
import {LSSVMPairFactory} from "lib/lssvm2/src/LSSVMPairFactory.sol";
import {RoyaltyEngine} from "lib/lssvm2/src/RoyaltyEngine.sol";
import {LSSVMPairERC721ETH} from "lib/lssvm2/src/erc721/LSSVMPairERC721ETH.sol";
import {LSSVMPairERC1155ETH} from "lib/lssvm2/src/erc1155/LSSVMPairERC1155ETH.sol";
import {LSSVMPairERC721ERC20} from "lib/lssvm2/src/erc721/LSSVMPairERC721ERC20.sol";
import {LSSVMPairERC1155ERC20} from "lib/lssvm2/src/erc1155/LSSVMPairERC1155ERC20.sol";
import {LSSVMPair} from "lib/lssvm2/src/LSSVMPair.sol";
import {LinearCurve} from "lib/lssvm2/src/bonding-curves/LinearCurve.sol";
import {XykCurve} from "lib/lssvm2/src/bonding-curves/XykCurve.sol";
import {ICurve} from "lib/lssvm2/src/bonding-curves/ICurve.sol";
import {OrderBhook} from "lib/lssvm2/src/hooks/OrderBhook.sol";

import {Test721} from "./mocks/Test721.sol";

contract SudoOrderBookTest is Test {

    LSSVMPairFactory pairFactory;
    LinearCurve linearCurve;
    Test721 testNFT;
    OrderBhook book;

    address payable constant ALICE = payable(address(123456));
    address payable constant BOB = payable(address(7890));

    function setUp() public {
        
        // Initialize sudo factory
        RoyaltyEngine royaltyEngine = new RoyaltyEngine(address(0)); // We use a fake registry
        LSSVMPairERC721ETH erc721ETHTemplate = new LSSVMPairERC721ETH(royaltyEngine);
        LSSVMPairERC721ERC20 erc721ERC20Template = new LSSVMPairERC721ERC20(royaltyEngine);
        LSSVMPairERC1155ETH erc1155ETHTemplate = new LSSVMPairERC1155ETH(royaltyEngine);
        LSSVMPairERC1155ERC20 erc1155ERC20Template = new LSSVMPairERC1155ERC20(royaltyEngine);
        pairFactory = new LSSVMPairFactory(
            erc721ETHTemplate,
            erc721ERC20Template,
            erc1155ETHTemplate,
            erc1155ERC20Template,
            payable(address(0)),
            0, // Zero protocol fee
            address(this)
        );
        linearCurve = new LinearCurve();
        pairFactory.setBondingCurveAllowed(ICurve(address(linearCurve)), true);
        book = new OrderBhook(pairFactory, ALICE);

        // Initialize the order book to take in only linear curve pool
        vm.startPrank(ALICE);
        book.addCurve(address(linearCurve));

        // Mint IDs 1-10 to Alice
        testNFT = new Test721();
        for (uint i; i < 10; ++i) {
            testNFT.mint(ALICE, i);
        }

        // As Alice, approve the factory
        vm.startPrank(ALICE);
        testNFT.setApprovalForAll(address(pairFactory), true);
    }

    function testListOneNFT() public {

        // List ID 1 for 0.1 ETH
        vm.startPrank(ALICE);
        uint256[] memory nftToList = new uint256[](1);
        nftToList[0] = 1;
        uint128 listPrice = 0.1 ether;
        LSSVMPair listingPool = pairFactory.createPairERC721ETH(
            IERC721(address(testNFT)), 
            linearCurve, 
            payable(address(0)), 
            LSSVMPair.PoolType.TRADE, // Set this to be NFT if it's sell only, i.e. not a two-way pool
            0, 
            0, 
            listPrice, 
            address(0), 
            nftToList, 
            address(0), // optional, can be address(0) unless you want hook logic
            address(0)
        );

        // Take ID 1 for 0.1 ETH
        vm.startPrank(BOB);
        vm.deal(BOB, 2*listPrice);
        listingPool.swapTokenForSpecificNFTs{value: listPrice}(nftToList, listPrice, BOB, false, address(0));
        assertEq(testNFT.balanceOf(BOB), 1);
    }

    function testBidOneNFT() public {

        // We bid 0.1 ETH for any NFT
        vm.startPrank(BOB);
        uint256[] memory empty = new uint256[](0);
        uint128 bidPrice = 0.1 ether;

        vm.deal(BOB, 2*bidPrice);
        LSSVMPair listingPool = pairFactory.createPairERC721ETH{value: bidPrice}(
            IERC721(address(testNFT)), 
            linearCurve, 
            payable(address(0)), 
            LSSVMPair.PoolType.TRADE, // Set this to be TOKEN if it's sell only, i.e. not a two-way pool
            0, 
            0, 
            bidPrice, 
            address(0), // if set to address(0), can fill for any ID, otherwise implement IPropertyChecker
            empty, 
            address(0), // optional, can be address(0) unless you want hook logic
            address(0)
        );
        
        vm.startPrank(ALICE);
        testNFT.setApprovalForAll(address(listingPool), true);
        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = 1;
        listingPool.swapNFTsForToken(nftIds, bidPrice, ALICE, false, address(0));
    }   
}