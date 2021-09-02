pragma solidity ^0.8.0;

/**
 Hook into all transfer calls
 */
interface ITransferHook {
    function transfer(address recipient, uint256 amount) external;
}

/**
 Hook into all approve calls
 */
interface IApproveHook {
    function approve(address spender, uint256 amount) external;
}

/**
 Hook into all transferFrom calls
 */
interface ITransferFromHook {
    function transferFrom(address recipient, uint256 amount) external;
}

/**
 Hook into all successful transfer calls
 */
interface IAfterTransferHook {
    function afterTransfer(address recipient, uint256 amount) external;
}

/**
 Hook into all successful approve calls
 */
interface IAfterApproveHook {
    function afterApprove(address spender, uint256 amount) external;
}

/**
 Hook into all successful transferFrom calls
 */
interface IAfterTransferFromHook {
    function afterTransferFrom(address recipient, uint256 amount) external;
}