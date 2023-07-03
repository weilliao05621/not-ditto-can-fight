// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";

import "./NotDittoConfig.sol";
import "./ErrorConfig.sol";

// 外部呼叫的 function 要想清楚「誰會來呼叫」，它會不會被省略掉什麼檢查

// TODO: 之後比賽獎勵可以獲得的星星，用來加速升等
contract NotDittoAndItems is
    NotDittoConfig,
    ErrorConfig,
    IERC165,
    ERC165,
    IERC1155
{
    event MintNotDitto(address from, address to, uint256 id, uint256 amount);
    event Approval(address owner, address operator, uint256 id);
    event ApprovalBatch(
        address indexed operator,
        uint256[] ids,
        uint256[] values
    );

    using Address for address;

    uint256 public constant NOT_DITTO = 0;
    uint256 public constant BASIC_STAR = 1;
    uint256 public constant MEDIAN_STAR = 2;
    uint256 public constant LEVEL_UP_STAR = 3;

    uint256 public constant MINT_PRICE = 0.001 ether;
    uint256 public constant RASIE_SUPPORT_FEE = (MINT_PRICE * 250) / 10000; // 2.5%

    uint256 public constant MAX_NOT_DITTO_SUPPLY_PER_ADDRESS = 3;
    uint256 public constant MAX_NOT_DITTO_SUPPLY = 10; // TODO: 先用 10 隻做測試，最多只支援 1_000

    // tokenId => owner => amount
    mapping(uint256 => mapping(address => uint256)) private _balances;
    // tokenId => totalSupply
    uint256[4] public totalSupplies;

    // notDittoId => operator => bool
    mapping(uint256 => mapping(address => bool)) private _approvals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // 為了減省 gas，所以會採 stack 的方式達成 re-mint
    uint256[] public currentOrphanNotDittos;

    mapping(bytes32 => bool) public morphedNftHash;
    mapping(uint256 => NotDittoInfo) public notDittoInfos;
    mapping(uint256 => NotDittoSnapshot) public notDittoSnapshots;

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            super.supportsInterface(interfaceId);
    }

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

    // 不提供選擇 mint 哪一個
    // mint 只檢查條件
    function mintNotDitto(address nftAddress, uint256 nftId) external payable {
        if (msg.value != MINT_PRICE) {
            revert ErrorFromInteractWithNotDitto(
                uint256(ErrorNotDitto.WRONG_MINT_PRICE)
            );
        }

        _checkIsOwnerOfTokenId(msg.sender, nftAddress, nftId);

        bytes32 nftInfoHash = keccak256(abi.encodePacked(nftAddress, nftId));
        bool existed = morphedNftHash[nftInfoHash];

        require(!existed);
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
            elementalAttr: _getElementalAttribute(nftAddress, nftId)
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

    function mintBatchNotDitto(
        uint256 amount,
        address[] memory nftAddresses,
        uint256[] memory nftIds
    ) external payable {
        if (msg.value != MINT_PRICE * amount) {
            revert ErrorFromInteractWithNotDitto(
                uint256(ErrorNotDitto.WRONG_MINT_PRICE)
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

                    require(!existed);

                    unchecked {
                        morphedNftHash[nftInfoHash] = true;
                        // orphan is the index of NotDitto
                        uint256 orphan = currentOrphanNotDittos[
                            orphans - i - 1
                        ];

                        notDittoInfo.nftAddress = nftAddresses[i];
                        notDittoInfo.nftId = nftIds[i];
                        notDittoInfo.elementalAttr = _getElementalAttribute(
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
            if ((MAX_NOT_DITTO_SUPPLY - currentNotDittoIndex) + orphans < amount) {
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

                    require(!existed);

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
                        notDittoInfo.elementalAttr = _getElementalAttribute(
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

    // 僅支援 NotDitto 去做單獨 Approval，星星目前是自己使用
    // advanced: 星星未來可以考慮質押，會有跟 NotDitto 升等很像的機制
    function approve(address _operator, uint256 _id, bool approved) external {
        if (_operator == address(0)) {
            revert ErrorFromInteractWithNotDitto(
                uint256(ErrorNotDitto.ZERO_ADDRESS_IS_NOT_AVAIABLE_OPERATOR)
            );
        }

        address owner = ownerOf(_id);
        if (owner != msg.sender) {
            revert ErrorFromErc1155(
                uint256(ErrorErc1155.CALLER_IS_NOT_TOKEN_OWNER_NOR_APPROVED)
            );
        }

        _approvals[_id][_operator] = approved;
        emit Approval(owner, _operator, _id);
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

    // TODO: 目前僅支援 NotDitto 可以全部有動用權 > 目前 star 的 transferFrom 不會檢查 approve，只會檢查 msg.sender 是不是 _from
    function setApprovalForAll(address _operator, bool _approved) external {
        if (_operator == address(0)) {
            revert ErrorFromInteractWithNotDitto(
                uint256(ErrorNotDitto.ZERO_ADDRESS_IS_NOT_AVAIABLE_OPERATOR)
            );
        }

        _operatorApprovals[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function isApprovedForAll(
        address _owner,
        address _operator
    ) public view returns (bool) {}

    function ownerOf(uint256 tokenId) public view returns (address owner) {
        owner = notDittoInfos[tokenId].owner;
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

    // 這個 function 只支援 Stars
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

    function _burnNotDitto(uint256 id, bool isPendingOrphan) internal {
        // 檢查是否為 NotDitto 的 owner 要參加抽獎
        address owner = notDittoInfos[id].owner;
        require(isPendingOrphan || owner == msg.sender);
        require(owner != address(0));

        NotDittoInfo memory _info = notDittoInfos[id];

        bytes32 nftInfoHash = keccak256(
            abi.encodePacked(_info.nftAddress, _info.nftId)
        );

        notDittoInfos[id].owner = address(0);
        currentOrphanNotDittos[currentOrphanNotDittos.length] = id;
        morphedNftHash[nftInfoHash] = false;

        _transferNotDitto(owner, address(0), 1);
    }

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

    function _replaceMorphNFT(
        uint256 tokenId,
        address nftAddr,
        uint256 nftTokenId
    ) external {
        if (!checkIsNotDittoOwner(tokenId)) {
            revert NotOwnerOfTheNotDitto();
        }

        if (nftAddr == address(0)) {
            revert NotDittoIsUnhappyToMorphZeroAddress();
        }

        if (nftTokenId == 0) {
            revert();
        }

        notDittoInfos[tokenId].nftAddress = nftAddr;
        notDittoInfos[tokenId].nftId = nftTokenId;
    }

    function checkIsNotDittoOwner(
        uint256 tokenId
    ) public view returns (bool isOwner) {
        isOwner = msg.sender == ownerOf(tokenId);
    }

    function checkIsExistedMorphedNft(
        address nftAddress,
        uint256 nftId
    ) public view returns (bool existed) {
        bytes32 nftInfoHash = keccak256(abi.encodePacked(nftAddress, nftId));
        existed = morphedNftHash[nftInfoHash];
    }

    function _checkIsOwnerOfTokenId(
        address player,
        address nftAddr,
        uint256 tokenId
    ) internal view returns (bool isOwner) {
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
        require(success, "NotDitto: failed to call ERC721's ownerOf()");
        isOwner = abi.decode(rawOwner, (address)) == player;
    }

    // 0 - 15 對應 16 種屬性，沒有普通和幽靈
    function _getElementalAttribute(
        address nftAddress,
        uint256 nftTokenId
    ) private pure returns (uint256) {
        bytes1 attributeHash = bytes1(
            keccak256((abi.encodePacked(nftAddress, nftTokenId)))
        );
        return uint8(attributeHash) / 15;
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
