// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";

import "./NotDittoAndItemsStorage.sol";

// TODO: 之後比賽獎勵可以獲得的星星，用來加速升等
contract NotDittoAndItems is
    IERC165,
    ERC165,
    IERC1155,
    NotDittoAndItemsStorage
{
    event MintNotDitto(address from, address to, uint256 id, uint256 amount);
    event Approval(address owner, address operator, uint256 id);
    event ApprovalBatch(
        address indexed operator,
        uint256[] ids,
        uint256[] values
    );

    using Address for address;

    // 不提供選擇 mint 哪一個，mint 只檢查條件
    function mintNotDitto(address nftAddress, uint256 nftId) external payable {
        if (msg.value < MINT_PRICE) {
            revert ErrorFromInteractWithNotDitto(
                uint256(ErrorNotDitto.WRONG_MINT_PRICE)
            );
        }
        bool reachMaxMintAmount = balanceOf(msg.sender, NOT_DITTO) >=
            MAX_NOT_DITTO_SUPPLY_PER_ADDRESS;
        if (reachMaxMintAmount) {
            revert ErrorFromInteractWithNotDitto(
                uint256(ErrorNotDitto.ALL_NOT_DITTO_HAS_PARENTS)
            );
        }

        _checkIsOwnerOfTokenId(msg.sender, nftAddress, nftId);

        bytes32 nftInfoHash = keccak256(abi.encodePacked(nftAddress, nftId));
        bool existed = morphedNftHash[nftInfoHash];

        if (existed) {
            revert ErrorFromInteractWithNotDitto(
                uint256(ErrorNotDitto.NOT_DITTO_IS_UNHAPPY_TO_MORPH_EXISTED_NFT)
            );
        }

        morphedNftHash[nftInfoHash] = true;

        // 用同一個 index 去 mint，只是不同 mint 方式，更新 index 不一樣
        uint256 currentNotDittoIndex = totalSupplies[NOT_DITTO];
        bool allNotDittoIsMinted = currentNotDittoIndex == MAX_NOT_DITTO_SUPPLY;

        // 如果 currentNotDittoIndex == MAX_NOT_DITTO_SUPPLY，則要去看放養場有沒有等待被領養的百變怪
        // 讀取新的 notDittoIndex，並更新 totalSupply
        // 修改 totalSupply 或 orphans 狀態
        if (allNotDittoIsMinted) {
            // 複印
            uint256 orphans = currentOrphanNotDittos.length;
            if (orphans == 0) {
                revert ErrorFromInteractWithNotDitto(
                    uint256(ErrorNotDitto.ALL_NOT_DITTO_HAS_PARENTS)
                );
            }
            // 配合 solidity 語法採用 stack 先進後出來處理
            currentNotDittoIndex = currentOrphanNotDittos[orphans - 1];
            currentOrphanNotDittos.pop();
        } else {
            currentNotDittoIndex = currentNotDittoIndex + 1;
            totalSupplies[NOT_DITTO] = currentNotDittoIndex;
        }

        address from = address(0);
        address to = msg.sender;

        NotDittoInfo memory notDittoInfo = NotDittoInfo({
            owner: to,
            nftAddress: nftAddress,
            nftId: nftId,
            elementalAttr: getElementalAttribute(nftAddress, nftId)
        });
        uint256 effort = allNotDittoIsMinted ? 5 : 0;
        NotDittoSnapshot memory notDittoSnapshot = NotDittoSnapshot(
            block.timestamp,
            0,
            effort
        );

        notDittoInfos[currentNotDittoIndex] = notDittoInfo;
        notDittoSnapshots[currentNotDittoIndex] = notDittoSnapshot;
        emit MintNotDitto(from, to, currentNotDittoIndex, 1);

        _safeTransferFrom(from, to, NOT_DITTO, 1);
    }

    // TODO: 為了確保 NotDitto 變成 Orphan 後不會馬上被同一個 owner 領養，要變成 internal，然後到game去實作
    function mintNotDittoBatch(
        uint256 amount,
        address[] memory nftAddresses,
        uint256[] memory nftIds
    ) external payable {
        if (msg.value < MINT_PRICE * amount) {
            revert ErrorFromInteractWithNotDitto(
                uint256(ErrorNotDitto.WRONG_MINT_PRICE)
            );
        }

        bool reachMaxMintAmount = balanceOf(msg.sender, NOT_DITTO) >=
            MAX_NOT_DITTO_SUPPLY_PER_ADDRESS;
        if (reachMaxMintAmount) {
            revert ErrorFromInteractWithNotDitto(
                uint256(ErrorNotDitto.EXCEED_MAX_NOT_DITTO_SUPPLY_PER_ADDRESS)
            );
        }

        // Record Index
        uint256 currentNotDittoIndex = totalSupplies[NOT_DITTO];
        // For validation
        bool allNotDittoIsMinted = currentNotDittoIndex == MAX_NOT_DITTO_SUPPLY;
        uint256 orphans = currentOrphanNotDittos.length;

        NotDittoInfo memory notDittoInfo = NotDittoInfo(
            1,
            address(1),
            0,
            msg.sender
        );
        uint256 effort = allNotDittoIsMinted ? 5 : 0;
        NotDittoSnapshot memory notDittoSnapshot = NotDittoSnapshot(
            block.timestamp,
            0,
            effort
        );

        // 3_000
        if (allNotDittoIsMinted) {
            if (orphans < amount) {
                revert ErrorFromInteractWithNotDitto(
                    uint256(ErrorNotDitto.ALL_NOT_DITTO_HAS_PARENTS)
                );
            } else {
                for (uint256 i = 0; i < amount; ) {
                    _checkIsOwnerOfTokenId(
                        msg.sender,
                        nftAddresses[i],
                        nftIds[i]
                    );

                    bytes32 nftInfoHash = keccak256(
                        abi.encodePacked(nftAddresses[i], nftIds[i])
                    );
                    bool existed = morphedNftHash[nftInfoHash];

                    if (existed) {
                        revert ErrorFromInteractWithNotDitto(
                            uint256(
                                ErrorNotDitto
                                    .NOT_DITTO_IS_UNHAPPY_TO_MORPH_EXISTED_NFT
                            )
                        );
                    }

                    unchecked {
                        morphedNftHash[nftInfoHash] = true;
                        // orphan is the index of NotDitto
                        uint256 orphan = currentOrphanNotDittos[
                            orphans - i - 1
                        ];

                        notDittoInfo.nftAddress = nftAddresses[i];
                        notDittoInfo.nftId = nftIds[i];
                        notDittoInfo.elementalAttr = getElementalAttribute(
                            nftAddresses[i],
                            nftIds[i]
                        );

                        notDittoInfos[orphan] = notDittoInfo;
                        notDittoSnapshots[orphan] = notDittoSnapshot;
                        ++i;
                    }
                }
            }
        } else {
            if (
                (MAX_NOT_DITTO_SUPPLY - currentNotDittoIndex) + orphans < amount
            ) {
                revert ErrorFromInteractWithNotDitto(
                    uint256(ErrorNotDitto.ALL_NOT_DITTO_HAS_PARENTS)
                );
            } else {
                // 還可以誕生的總數
                uint256 notDittosBorn = MAX_NOT_DITTO_SUPPLY -
                    currentNotDittoIndex;

                // 這次會誕生的數量
                uint256 newBornNotDitto = notDittosBorn > amount
                    ? amount
                    : notDittosBorn;
                // 需要領養的數量
                uint256 orphansAdopted = amount - newBornNotDitto;
                bool hasMoreBornNotDitto = newBornNotDitto > orphansAdopted;
                // 看用哪一個去跑迴圈
                uint256 loopTimes = hasMoreBornNotDitto
                    ? newBornNotDitto
                    : orphansAdopted;

                for (uint256 i = 0; i < loopTimes; ) {
                    _checkIsOwnerOfTokenId(
                        msg.sender,
                        nftAddresses[i],
                        nftIds[i]
                    );

                    bytes32 nftInfoHash = keccak256(
                        abi.encodePacked(nftAddresses[i], nftIds[i])
                    );
                    bool existed = morphedNftHash[nftInfoHash];

                    if (existed) {
                        revert ErrorFromInteractWithNotDitto(
                            uint256(
                                ErrorNotDitto
                                    .NOT_DITTO_IS_UNHAPPY_TO_MORPH_EXISTED_NFT
                            )
                        );
                    }

                    unchecked {
                        morphedNftHash[nftInfoHash] = true;
                        if (newBornNotDitto == 3) {
                            currentNotDittoIndex = currentNotDittoIndex + 1;
                        } else {
                            bool isOrphan = newBornNotDitto == 2
                                ? i > 1
                                : i > 0;
                            currentNotDittoIndex = isOrphan
                                ? currentOrphanNotDittos[orphans - i - 1]
                                : currentNotDittoIndex + 1;
                            if (isOrphan) {
                                currentOrphanNotDittos.pop();
                                notDittoSnapshot.effort = 5;
                            }
                        }

                        notDittoInfo.nftAddress = nftAddresses[i];
                        notDittoInfo.nftId = nftIds[i];
                        notDittoInfo.elementalAttr = getElementalAttribute(
                            nftAddresses[i],
                            nftIds[i]
                        );

                        notDittoInfos[currentNotDittoIndex] = notDittoInfo;
                        notDittoSnapshots[
                            currentNotDittoIndex
                        ] = notDittoSnapshot;

                        ++i;
                        emit MintNotDitto(
                            address(0),
                            msg.sender,
                            currentNotDittoIndex,
                            1
                        );
                    }
                }

                totalSupplies[NOT_DITTO] =
                    totalSupplies[NOT_DITTO] +
                    newBornNotDitto;
            }
        }
        _safeTransferFrom(address(0), msg.sender, NOT_DITTO, amount);
    }

    function burnNotDitto(uint256 id, bool isPendingOrphan) internal {
        address owner = notDittoInfos[id].owner;
        require(owner != address(0));
        require(isPendingOrphan || owner == msg.sender);

        NotDittoInfo memory _info = notDittoInfos[id];

        bytes32 nftInfoHash = keccak256(
            abi.encodePacked(_info.nftAddress, _info.nftId)
        );

        notDittoInfos[id].owner = address(0);
        currentOrphanNotDittos.push(id);
        morphedNftHash[nftInfoHash] = false;

        _transferNotDitto(owner, address(0), 1);
    }

    function totalOrphans() public view returns (uint256) {
        return currentOrphanNotDittos.length;
    }

    function multicallTotalSupplies(
        uint256[] memory tokenIds
    ) external view returns (uint256[] memory amounts) {
        require(tokenIds.length <= 4);
        uint256[4] memory _totalSupplies = totalSupplies;
        for (uint256 i = 0; i < tokenIds.length; ) {
            amounts[i] = _totalSupplies[tokenIds[i]];
            unchecked {
                ++i;
            }
        }
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // TODO:[advanced-feat] 對戰功能的擴充
    // 星星糖果獎勵是由玩家向系統提領 or 玩家之間自由交換
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _value,
        bytes calldata _data
    ) external {
        if (_id == NOT_DITTO) {
            revert ErrorFromInteractWithNotDitto(
                uint256(ErrorNotDitto.NOT_DITTOS_ARE_ONLY_MINTABLE_AND_BURNABLE)
            );
        } else {
            // TODO: approve 星星的用途還要再想想
            bool isApproved = _from == msg.sender ||
                isApprovedForAll(_from, msg.sender);

            if (!isApproved) {
                revert ErrorFromErc1155(
                    uint256(ErrorErc1155.CALLER_IS_NOT_TOKEN_OWNER_NOR_APPROVED)
                );
            } else {
                _safeTransferFrom(_from, _to, _id, _value);
            }
        }
    }

    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external {
        if (ids.length != values.length) {
            revert ErrorFromErc1155(
                uint256(ErrorErc1155.MISMATCH_IDS_AND_AMOUNTS)
            );
        }

        bool isApproved = _from == msg.sender ||
            isApprovedForAll(_from, msg.sender);
        if (!isApproved) {
            revert ErrorFromErc1155(
                uint256(ErrorErc1155.CALLER_IS_NOT_TOKEN_OWNER_NOR_APPROVED)
            );
        }

        _safeBatchTransferFrom(_from, _to, ids, values);
    }

    // TODO:[advanced-feat]: approve 不會改變持有，而是在對戰時可以檢查是否有 approval，藉此在自己的賽區使用
    // 僅支援 NotDitto 去做單獨 Approval，approve 的概念是類似通信
    function approve(address _operator, uint256 _id, bool approved) external {
        if (_operator == address(0)) {
            revert ErrorFromInteractWithNotDitto(
                uint256(ErrorNotDitto.ZERO_ADDRESS_IS_NOT_AVAIABLE_OPERATOR)
            );
        }

        address owner = _checkIsOwnerOfNotDitto(msg.sender, _id);

        _approvals[_id][_operator] = approved;
        emit Approval(owner, _operator, _id);
    }

    // TODO:[advanced-feat]: 目前僅支援 NotDitto 可以全部有動用權
    function setApprovalForAll(address _operator, bool _approved) external {}

    function isApprovedForAll(
        address _owner,
        address _operator
    ) public view returns (bool) {}

    function ownerOf(uint256 id) public view returns (address owner) {
        owner = notDittoInfos[id].owner;
    }

    function balanceOf(
        address _owner,
        uint256 _id
    ) public view returns (uint256) {
        if (_owner == address(0)) {
            revert ErrorFromErc1155(
                uint256(ErrorErc1155.ZERO_ADDRESS_IS_NOT_AVAIABLE_OWNER)
            );
        }

        return _balances[_id][_owner];
    }

    function balanceOfBatch(
        address[] calldata _owners,
        uint256[] calldata _ids
    ) public view returns (uint256[] memory) {
        if (_owners.length != _ids.length) {
            uint256 errorCode = uint256(ErrorErc1155.MISMATCH_ACCOUNTS_AND_IDS);
            revert ErrorFromErc1155(errorCode);
        }

        uint256[] memory batchBalances = new uint256[](_owners.length);

        for (uint256 i = 0; i < _owners.length; ) {
            batchBalances[i] = balanceOf(_owners[i], _ids[i]);
            unchecked {
                ++i;
            }
        }

        return batchBalances;
    }

    // TODO:[advanced-feat] 對戰功能的擴充
    // 0 - 15 對應 16 種屬性，沒有普通和幽靈
    function getElementalAttribute(
        address nftAddress,
        uint256 nftTokenId
    ) public pure returns (uint256) {
        bytes1 attributeHash = bytes1(
            keccak256((abi.encodePacked(nftAddress, nftTokenId)))
        );
        return uint8(attributeHash) / 15;
    }

    function _safeTransferFrom(
        address _from,
        address _to,
        uint256 id,
        uint256 amount
    ) internal {
        if (id == NOT_DITTO) {
            _transferNotDitto(_from, _to, amount);
        } else {
            _transferStar(_from, _to, id, amount);
        }

        emit TransferSingle(msg.sender, _from, _to, id, amount);
        _doSafeTransferAcceptanceCheck(msg.sender, _from, _to, id, amount, "");
    }

    // TODO:[advanced-feat]: 這個 function 只支援 Stars
    function _safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal {
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            if (id == NOT_DITTO) {
                revert ErrorFromInteractWithNotDitto(
                    uint256(
                        ErrorNotDitto.NOT_DITTOS_ARE_ONLY_MINTABLE_AND_BURNABLE
                    )
                );
            }
            uint256 amount = amounts[i];
            _transferStar(_from, _to, id, amount);
        }

        emit TransferBatch(msg.sender, _from, _to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(
            msg.sender,
            _from,
            _to,
            ids,
            amounts,
            ""
        );
    }

    // transfer 僅作 balance 的改動
    function _transferNotDitto(
        address _from,
        address _to,
        uint256 amount
    ) internal {
        unchecked {
            if (_from != address(0) && _to == address(0)) {
                uint256 fromBalance = _balances[NOT_DITTO][_from];
                require(fromBalance >= amount);
                _balances[NOT_DITTO][_from] = fromBalance - amount;
            } else if (_from == address(0) && _to != address(0)) {
                uint256 toBalances = _balances[NOT_DITTO][_to];
                require(toBalances < MAX_NOT_DITTO_SUPPLY_PER_ADDRESS);
                require(
                    toBalances + amount <= MAX_NOT_DITTO_SUPPLY_PER_ADDRESS
                );
                _balances[NOT_DITTO][_to] = toBalances + amount;
            } else {
                revert();
            }
        }
    }

    function _transferStar(
        address _from,
        address _to,
        uint256 id,
        uint256 amount
    ) internal {
        uint256 fromBalance = _balances[id][_from];

        if (fromBalance < amount) {
            revert ErrorFromErc1155(
                uint256(ErrorErc1155.INSUFFICIENT_BALANCE_FOR_TRANSFER)
            );
        }

        unchecked {
            _balances[id][_from] = fromBalance - amount;
        }

        _balances[id][_to] += amount;
    }

    function _checkIsOwnerOfNotDitto(
        address player,
        uint256 tokenId
    ) internal view returns (address owner) {
        owner = ownerOf(tokenId);
        if (owner != player) {
            revert ErrorFromErc1155(
                uint256(ErrorErc1155.CALLER_IS_NOT_TOKEN_OWNER_NOR_APPROVED)
            );
        }
    }

    function _checkIsOwnerOfTokenId(
        address player,
        address nftAddr,
        uint256 tokenId
    ) internal view {
        uint256 errorCode;

        if (nftAddr == address(0)) {
            errorCode = uint256(
                ErrorNotDitto.NOT_DITTO_IS_UNHAPPY_TO_MORPH_ZERO_ADDRESS
            );
            revert ErrorFromInteractWithNotDitto(errorCode);
        }

        if (nftAddr == address(this)) {
            errorCode = uint256(
                ErrorNotDitto.NOT_DITTO_IS_UNHAPPY_TO_MORPH_ITSELF
            );
            revert ErrorFromInteractWithNotDitto(errorCode);
        }

        bytes memory payload = abi.encodeWithSignature(
            "ownerOf(uint256)",
            tokenId
        );
        (bool success, bytes memory rawOwner) = nftAddr.staticcall(payload);
        require(success);
        bool notOwner = abi.decode(rawOwner, (address)) != player;
        if (notOwner) {
            errorCode = uint256(ErrorNotDitto.NOT_OWNER_OF_THE_NFT);
            revert ErrorFromInteractWithNotDitto(errorCode);
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try
                IERC1155Receiver(to).onERC1155BatchReceived(
                    operator,
                    from,
                    ids,
                    amounts,
                    data
                )
            returns (bytes4 response) {
                if (
                    response != IERC1155Receiver.onERC1155BatchReceived.selector
                ) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try
                IERC1155Receiver(to).onERC1155Received(
                    operator,
                    from,
                    id,
                    amount,
                    data
                )
            returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }
}
