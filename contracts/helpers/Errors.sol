
library Errors {
    //common errors
    string public constant TR_SENDER_NOT_ERC1400_TOKEN = '55';
    string public constant TR_TO_ADDRESS_NOT_ME = '50';
    string public constant TR_INVALID_RECEIVER = '57';
    string public constant ZERO_ADDRESS_NOT_ALLOWED = '10';
    string public constant NO_CONTRACT_OWNER = '33';

    //swap specific errors
    string public constant SW_SENDER_NOT_TOKEN_CONTROLLER = '1';
    string public constant SW_SENDER_NOT_PRICE_ORACLE = '2';
    string public constant SW_WRONG_TOKEN_SENT = '3';
    string public constant SW_TOKENS_IN_WRONG_PARTITION = '4';
    string public constant SW_TOKEN_INCORRECT_STANDARD = '5';
    string public constant SW_ETH_TRADE_REQUIRES_ESCROW = '6';
    string public constant SW_TOKEN_STANDARD_NOT_SUPPORTED = '7';
    string public constant SW_NO_HOLDID_GIVEN = '8';
    string public constant SW_TRADE_EXECUTER_NOT_ALLOWED = '9';
    string public constant SW_TRADE_NOT_PENDING = '11';
    string public constant SW_ONLY_REGISTERED_HOLDERS = '12';
    string public constant SW_TRADE_ALREADY_ACCEPTED = '13';
    string public constant SW_ETH_AMOUNT_INCORRECT = '14';
    string public constant SW_TOKEN_AMOUNT_INCORRECT = '15';
    string public constant SW_HOLD_DOESNT_EXIST = '16';
    string public constant SW_ALLOWANCE_NOT_GIVEN = '17';
    string public constant SW_SENDER_NOT_EXECUTER = '18';
    string public constant SW_BEFORE_SETTLEMENT_DATE = '19';
    string public constant SW_TRADE_NOT_FULLY_ACCEPTED = '20';
    string public constant SW_TRADE_NOT_FULLY_APPROVED = '21';
    string public constant SW_PRICE_HIGHER_THAN_AMOUNT = '22';
    string public constant SW_EXECUTE_TRADE_POSSIBLE = '23';
    string public constant SW_ONLY_EXECUTER_CAN_FORCE_TRADE = '24';
    string public constant SW_SENDER_CANT_FORCE_TRADE = '25';
    string public constant SW_FORCE_TRADE_NOT_POSSIBLE_NO_TOKENS = '26';
    string public constant SW_SENDER_CANT_CANCEL_TRADE_0 = '27';
    string public constant SW_SENDER_CANT_CANCEL_TRADE_1 = '28';
    string public constant SW_SENDER_CANT_CANCEL_TRADE_2 = '29';
    string public constant SW_SENDER_CANT_CANCEL_TRADE_3 = '30';
    string public constant SW_TRADE_EXPIRED = '31';
    string public constant SW_HOLD_TOKEN_EXTENSION_MISSING = '32';
    string public constant SW_START_DATE_MUST_BE_ONE_WEEK_BEFORE = '34';
    string public constant SW_COMPETITION_ON_PRICE_OWNERSHIP = '35';
    string public constant SW_PRICE_SETTER_NOT_TOKEN_ORACLE_1 = '36';
    string public constant SW_PRICE_SETTER_NOT_TOKEN_ORACLE_2 = '37';
    string public constant SW_NO_PRICE_OWNERSHIP = '38';

    //diamond
    string public constant DIAMOND_NO_FUNCTION = '39';
    string public constant NO_SELECTORS_IN_FACET = '40'; // LibDiamondCut: No selectors in facet to cut
    string public constant FACET_CANNOT_BE_ZERO = '41'; // LibDiamondCut: Add facet can't be address(0)
    string public constant FACET_HAS_NO_CODE = '42'; // LibDiamondCut: New facet has no code
    string public constant FUNCTION_CONFLICT = '43'; // LibDiamondCut: Can't add function that already exists
    string public constant FACET_MUST_BE_ZERO = '44'; // LibDiamondCut: Remove facet address must be address(0)
    string public constant FUNCTION_NOT_FOUND = '45'; // LibDiamondCut: Can't remove function that doesn't exist
    string public constant FUNCTION_IMMUTABLE = '46'; // LibDiamondCut: Can't remove immutable function
    string public constant UNEXPECTED_CALLDATA = '47'; // LibDiamondCut: _init is address(0) but_calldata is not empty
    string public constant MISSING_INIT_ADDRESS = '48'; // LibDiamondCut: _calldata is empty but _init is not address(0)
    string public constant INIT_ADDRESS_NO_CODE = '49'; // LibDiamondCut: _init address has no code
    string public constant INIT_REVERTED = '50'; // LibDiamondCut: _init function reverted

    //token proxy
    string public constant NO_LOGIC_ADDRESS = "51"; // Logic address must be given
    string public constant LOGIC_INIT_FAILED = '52'; // Logic initializing failed
    string public constant UNAUTHORIZED_FOR_STATICCALL_MAGIC = '53'; // STATICCALLMAGIC can only be used by the Proxy
    string public constant UNAUTHORIZED_ONLY_EXTENSIONS = '54'; // Only extensions can call

    //erc20 token
    string public constant MAX_SUPPLY_ZERO = '55'; // Max supply must be non-zero
    string public constant MINTING_DISABLED = '56'; // Minting is disabled
    string public constant BURNING_DISABLED = '57'; // Burning is disabled
    string public constant INVALID_TOKEN_TRANSFER = '58'; // Invalid token

    string public constant NOT_A_LOGIC_CONTRACT = '59'; // Not registered as a logic contract
    string public constant EXTENSION_ALREADY_EXISTS = '60'; // The extension must not already exist
    string public constant EXTENSION_DOESNT_EXISTS = '61'; // The extension must not already exist

    string public constant DEPLOYERS_DONT_MATCH = '62'; // Deployer address for new extension is different than current
    string public constant PACKAGE_HASH_DONT_MATCH = '63'; // Package for new extension is different than current
    string public constant VERSION_DONT_MATCH = '64'; // Versions should not match
    string public constant INTERFACE_LABELS_DONT_MATCH = '65'; // Interface labels do not match
    string public constant EXTENSION_DISABLED = '66'; // Extension is disabled
    string public constant EXTENSION_ENABLED = '67'; // Extension is already enabled
}