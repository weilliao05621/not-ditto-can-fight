// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

error MaxNotDittoSupplyPerAddressReached();
error MaxNotDittoSupplyReached();
error NotAllowNotDittoToBeSelfMinted();
error NotOwnerOfTheNotDitto();
error NotDittoIsUnhappyToMorphZeroAddress();
// NotDitto
error ErrorFromInteractWithNotDitto(uint256 errorCode);
// ERC1155
error ErrorFromErc1155(uint256 errorCode);

contract ErrorConfig {
    enum ErrorNotDitto {
        EXCEED_MAX_NOT_DITTO_SUPPLY_PER_ADDRESS,
        MAX_NOT_DITTO_SUPPLY_REACHED,
        NOT_ALLOW_NOT_DITTO_TO_BE_SELF_MINTED,
        NOT_OWNER_OF_THE_NOT_DITTO,
        NOT_DITTO_IS_UNHAPPY_TO_MORPH_ZERO_ADDRESS,
        NOT_DITTO_IS_UNHAPPY_TO_MORPH_ITSELF,
        ZERO_ADDRESS_IS_NOT_AVAIABLE_OPERATOR,
        ZERO_ADDRESS_IS_NOT_AVAIABLE_OWNER,
        INVALID_IDS_AND_VALUES,
        NOT_DITTOS_ARE_UNHAPPY_TO_LEAVE_YOU_TOGETHER,
        WRONG_MINT_PRICE,
        ALL_NOT_DITTO_HAS_PARENTS,
        NOT_DITTOS_ARE_ONLY_MINTABLE_AND_BURNABLE
    }

    enum ErrorErc1155 {
        ZERO_ADDRESS_IS_NOT_AVAIABLE_OWNER,
        MISMATCH_ACCOUNTS_AND_IDS,
        MISTMATCH_IDS_AND_VALUES_LENGTH,
        MISMATCH_IDS_AND_AMOUNTS,
        CALLER_IS_NOT_TOKEN_OWNER_NOR_APPROVED,
        INSUFFICIENT_BALANCE_FOR_TRANSFER
    }
}
