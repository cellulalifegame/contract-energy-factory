// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/Strings.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import "../Helps.sol";
import "../lib/BitMap.sol";

interface ICell {
    function _withdrawable() external view returns (bool);
}

contract LifeV3 is ERC721Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using BitMaps for BitMaps.BitMap;

    uint256 public constant BLOCK_TIME = 3; //Set the time for each block
    uint32 public constant EVOLUTION_TIME = 5 * 60; // Evolution time

    address public _cell;

    // The internal life ID tracker
    uint256 public _currentLifeId;

    mapping(uint256 => LifeGene) _lifePool;

    mapping(uint256 => uint256) public _foodPrices;

    address public _foodPayToken;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error MustBeNftOwner(address account);
    error FoodNotOnSale(uint256 workTime);
    error EtherNotEnough(uint256 price);

    event LifeCreation(uint256 tokenId);
    event FeedEvent(uint256 tokenId, uint256 startTime, uint256 workTime);

    string private _baseUrl;

    /**
     * @notice Require that the sender is the minter.
     */
    modifier onlyCell() {
        require(msg.sender == address(_cell), "Sender is not cell contract");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        string memory name_,
        string memory symbol_
    ) public initializer {
        _baseUrl = "https://factoryapi.cellula.life/lifeToken/";

        __ERC721_init(name_, symbol_);
        __Ownable_init(owner_);
    }

    function setCellAddress(address cell_) public onlyOwner {
        _cell = cell_;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function createLife(
        address to,
        uint256 bornPrice,
        uint256[][] calldata cellsPositions,
        uint256[] calldata cellGenes,
        uint32[] calldata livingCellTotals
    ) external onlyCell returns(uint256) {
        for (uint256 i = 0; i < cellsPositions.length; i++) {
            require(
                cellsPositions[i][1] < 17 && cellsPositions[i][1] > 0,
                "position error"
            );
            for (uint256 j = i + 1; j < cellsPositions.length; j++) {
                require(
                    cellsPositions[i][1] != cellsPositions[j][1],
                    "Two NFTs cannot be placed in the same position"
                );
            }
        }

        uint256 newTokenId = _currentLifeId++;
        LifeGene storage newLife = _lifePool[newTokenId];
        newLife.id = newTokenId;
        newLife.bornBlock = uint64(block.number);
        newLife.bornTime = uint64(block.timestamp);
        newLife.bornPrice = bornPrice;

        uint32 cellCount = 0;

        for (uint256 i = 0; i < cellsPositions.length; i++) {
            uint256 parentTokenID = cellsPositions[i][0];

            newLife.parentTokenIds.push(parentTokenID);
            uint256 position = cellsPositions[i][1];

            uint256 x = ((position - 1) % 4) * 3;
            uint256 y = ((position - 1) / 4) * 3;

            (uint256 top, uint256 mid, uint256 bottom) = Helps.getDigits(
                cellGenes[i]
            );
            uint256 Mask = 144 - (x + 12 * y) - 3;
            newLife.bitmap.setBucket(0, bottom << Mask);
            newLife.bitmap.setBucket(0, mid << (Mask - 12));
            newLife.bitmap.setBucket(0, top << (Mask - 24));

            cellCount = cellCount + livingCellTotals[i];
        }
        newLife.livingCellTotal = cellCount;

        // Detecting the number of lifes based on gene
        string memory sequenceGene = getGenesSequence(newTokenId);
        ++lifeCounterByGene[sequenceGene];
        require(lifeCounterByGene[sequenceGene] <= lifeLimitByGene, "insufficient number of lifes");

        _mint(to, newTokenId);

        emit LifeCreation(newTokenId);

        return newTokenId;
    }

    function changeFoodPrice(
        uint256[] memory foodWorkTimes,
        uint256[] memory foodPrices
    ) external onlyOwner {
        require(foodWorkTimes.length == foodPrices.length, "invalid params");
        for (uint256 i = 0; i < foodWorkTimes.length; i++) {
            _foodPrices[foodWorkTimes[i]] = foodPrices[i];
        }
    }

    function buyFood(
        uint256[] memory tokenIds,
        uint256 foodWorkTime
    ) external payable {
        require(pauseStatus == false, "pause");
        uint256 foodPrice = _foodPrices[foodWorkTime];
        if (foodPrice <= 0) {
            revert FoodNotOnSale(foodWorkTime);
        }
        uint256 foodPriceSum = tokenIds.length * foodPrice;

        // Payment
        if (tokenPaymentStatus) {
            require(msg.value == 0, "value must be 0");
            IERC20(_foodPayToken).safeTransferFrom(address(msg.sender), address(this), foodPriceSum);
        } else {
            if (msg.value < foodPriceSum) {
                revert EtherNotEnough(foodPriceSum);
            }
        }

        // workEndTime
        uint256 currentTime = block.timestamp;
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            address owner = _ownerOf(tokenIds[i]);
            if (publicBuyStatus == false) {
                if (msg.sender != owner) {
                    revert MustBeNftOwner(owner);
                }
            }else{
                require(owner != address(0), "contains an invalid tokenId");
            }

            uint256 actualWorkingTime = foodWorkTime;
            if (_lifePool[tokenIds[i]].workEndTime > currentTime) {
                actualWorkingTime += (_lifePool[tokenIds[i]].workEndTime - currentTime);
            }
            require(actualWorkingTime <= maxWorkTime, "time limit exceeded");
            _lifePool[tokenIds[i]].workEndTime = uint64(currentTime + actualWorkingTime);
            emit FeedEvent(tokenIds[i], currentTime, foodWorkTime);
        }

        // refund
        if (msg.value > foodPriceSum) {
            (bool sent, ) = payable(msg.sender).call{ value: msg.value - foodPriceSum }(""); // Returns false on failure
            require(sent, "eth return failed");
        }
    }

    // withdraw eth from the contract
    function withdraw(uint256 amount, address receiver) public onlyOwner {
        require(ICell(_cell)._withdrawable(), "withdraw paused");
        require(amount <= address(this).balance, "Insufficient balance");
        (bool sent, ) = payable(receiver).call{value: amount}(""); // Returns false on failure
        require(sent, "failed to return Ether");
    }

    //Get Cellula information
    function getLifeGene(
        uint256 tokenID
    )
        public
        view
        returns (
            string memory genes,
            uint256 bornBlock,
            uint256 livingCellTotal,
            uint64 bornTime,
            uint64 workEndTime,
            uint256 bornPrice,
            uint256[] memory parentTokenIds
        )
    {
        LifeGene storage cell = _lifePool[tokenID];
        bornBlock = cell.bornBlock;
        livingCellTotal = cell.livingCellTotal;
        genes = getGenesSequence(tokenID);
        bornTime = cell.bornTime;
        workEndTime = cell.workEndTime;
        bornPrice = cell.bornPrice;
        parentTokenIds = cell.parentTokenIds;
    }

    function getRLESting(
        uint256 tokenId
    ) public view returns (string memory rleSting) {
        string memory rle = decodeGenes(tokenId);
        uint256 cellCount = tokenId >= first4x4LifeId ? 12 : 9;
        rleSting = string(
            abi.encodePacked(
                "x = ",
                Strings.toString(cellCount),
                ", y = ",
                Strings.toString(cellCount),
                "\n",
                rle
            )
        );
    }

    //Serialize and display gene information
    function getGenesSequence(
        uint256 tokenID
    ) public view returns (string memory genes) {
        LifeGene storage currentLife = _lifePool[tokenID];
        string memory result;
        uint256 count = tokenID >= first4x4LifeId ? 144 : 81;
        for (uint256 i = count; i > 0; i--) {
            bool value = currentLife.bitmap.get(i - 1);
            if (value) {
                result = string(abi.encodePacked(result, "1"));
            } else {
                result = string(abi.encodePacked(result, "0"));
            }
        }

        return result;
    }

    function decodeGenes(
        uint256 tokenId
    ) internal view returns (string memory) {
        // Convert the bitmap to a 2D array

        LifeGene storage cell = _lifePool[tokenId];
        uint256 cellCount = tokenId >= first4x4LifeId ? 12 : 9;
        uint256 width = cellCount;
        uint256 height = cellCount;

        uint256[][] memory pixels = new uint256[][](height);
        for (uint256 i = 0; i < height; i++) {
            pixels[i] = new uint256[](width);
            for (uint256 j = 0; j < width; j++) {
                pixels[i][j] = cell.bitmap.get(
                    width * height - (i * width + j) - 1
                )
                    ? 1
                    : 0;
            }
        }

        // Initialize an empty RLE string
        string memory rle = "";

        for (uint256 i = 0; i < height; i++) {
            uint256 runValue = pixels[i][0];
            uint256 runLength = 0;

            for (uint256 j = 0; j < width; j++) {
                uint256 pixelValue = pixels[i][j];

                if (pixelValue == runValue) {
                    runLength++;
                } else {
                    rle = string(
                        abi.encodePacked(
                            rle,
                            Strings.toString(runLength),
                            runValue == 1 ? "o" : "b"
                        )
                    );
                    runValue = pixelValue;
                    runLength = 1;
                }
            }
            rle = string(
                abi.encodePacked(
                    rle,
                    Strings.toString(runLength),
                    runValue == 1 ? "o" : "b",
                    "$"
                )
            );
        }

        return rle;
    }

    function getEvolutionaryAlgebra(
        uint256 tokenId
    ) public view returns (uint256) {
        uint256 mintBlockNum = _lifePool[tokenId].bornBlock;
        uint256 algebra = ((block.number - mintBlockNum) * BLOCK_TIME) /
            EVOLUTION_TIME;
        return algebra;
    }

    function lifeBaseRules(
        uint8[9] calldata cellGenes
    ) public pure returns (uint8) {
        uint8 liveCellNum = 0;

        for (uint256 i = 0; i < 9; i++) {
            if ((i != 4) && (cellGenes[i] == 1)) {
                liveCellNum += 1;
            }
        }
        if (liveCellNum == 2) {
            return cellGenes[4];
        }
        return liveCellNum <= 1 || liveCellNum >= 4 ? 0 : 1;
    }

    receive() external payable {}

    function changeBaseURL(string calldata newBaseURL) public onlyOwner {
        _baseUrl = newBaseURL;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseUrl;
    }

    function isCenterCellAlive(
        uint8[9] memory cells
    ) public pure returns (bool) {
        // Convert a one-dimensional array to a two-dimensional state matrix
        bool[3][3] memory matrix = [
            [false, false, false],
            [false, false, false],
            [false, false, false]
        ];
        for (uint256 i = 0; i < cells.length; i++) {
            matrix[i / 3][i % 3] = cells[i] == 1;
        }

        // Get the coordinates of the center cell
        uint8 centerX = 1;
        uint8 centerY = 1;

        // Calculate the state of the cells surrounding the center cell
        uint8 aliveCount = 0;
        for (uint8 i = 0; i < 3; i++) {
            for (uint8 j = 0; j < 3; j++) {
                if (i == centerX && j == centerY) {
                    continue;
                }
                if (matrix[i][j]) {
                    aliveCount++;
                }
            }
        }

        // Calculate the state of the center cell according to the rules of the Game of Life
        if (matrix[centerX][centerY]) {
            if (aliveCount == 2 || aliveCount == 3) {
                return true;
            } else {
                return false;
            }
        } else {
            if (aliveCount == 3) {
                return true;
            } else {
                return false;
            }
        }
    }

    // ============ V2 ============
    using SafeERC20 for IERC20;
    uint256 public maxWorkTime;
    bool public pauseStatus; // Control charging
    bool public tokenPaymentStatus;
    bool public publicBuyStatus; // limit buy food

    event WithdrawPayToken(address indexed ads, uint256 amount);
    event ChangePayTokenAddress(address old_address, address new_address);
    event ChangeMaxWorkTime(uint256 oldTime, uint256 newTime);
    event ChangePauseStatus(bool old_status, bool new_status);
    event ChangeTokenPaymentStatus(bool old_status, bool new_status);
    event ChangePublicBuyStatus(bool old_status, bool new_status);

    function withdrawPayToken(address receiver, uint256 amount) public onlyOwner {
        require(ICell(_cell)._withdrawable(), "withdraw paused");
        IERC20 foodPayToken = IERC20(_foodPayToken);
        require(amount <= foodPayToken.balanceOf(address(this)), "Insufficient balance");
        foodPayToken.safeTransfer(receiver, amount);
        emit WithdrawPayToken(receiver, amount);
    }
    function setPayTokenAddress(address food_pay_token) public onlyOwner {
        require(_foodPayToken == address(0), "unchangeable");
        emit ChangePayTokenAddress(_foodPayToken, food_pay_token);
        _foodPayToken = food_pay_token;
    }
    function setMaxWorkTime(uint256 work_time_) public onlyOwner {
        emit ChangeMaxWorkTime(maxWorkTime, work_time_);
        maxWorkTime = work_time_;
    }
    function setPauseStatus(bool new_status) public onlyOwner {
        emit ChangePauseStatus(pauseStatus, new_status);
        pauseStatus = new_status;
    }
    function setTokenPaymentStatus(bool new_status) public onlyOwner {
        emit ChangeTokenPaymentStatus(tokenPaymentStatus, new_status);
        tokenPaymentStatus = new_status;
    }
    function setPublicBuyStatus(bool new_status) public onlyOwner {
        emit ChangePublicBuyStatus(publicBuyStatus, new_status);
        publicBuyStatus = new_status;
    }

    // ============ V3 ============
    uint256 public first4x4LifeId;
    uint256 public lifeLimitByGene;
    mapping(string => uint256) public lifeCounterByGene;

    event ChangeLifeLimit(uint256 old_limit, uint256 new_limit);

    function setFirst4x4LifeId() public onlyOwner {
        require(first4x4LifeId == 0, "unchangeable");
        first4x4LifeId = _currentLifeId;
    }

    function changeLifeLimit(uint256 new_limit) public onlyOwner {
        require(new_limit > 0, "invalid limit");
        emit ChangeLifeLimit(lifeLimitByGene, new_limit);
        lifeLimitByGene = new_limit;
    }

}
