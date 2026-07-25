// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {SkeenAMC} from "../src/SkeenAMC.sol";
import {SkeenMessenger} from "../src/SkeenMessenger.sol";
import {IMailbox} from "@hyperlane-xyz/core/interfaces/IMailbox.sol";
import {IPostDispatchHook} from "@hyperlane-xyz/core/interfaces/hooks/IPostDispatchHook.sol";
import {IInterchainSecurityModule} from "@hyperlane-xyz/core/interfaces/IInterchainSecurityModule.sol";

// ─────────────────────────────────────────────────────────────────────────────
// Mock Mailbox para testes do SkeenAMC
// ─────────────────────────────────────────────────────────────────────────────
contract MockMailboxAMC is IMailbox {
    uint32 private _localDomain;
    uint32 private _nonce;
    bytes32 private _latestId;
    bytes[] public dispatchedMessages;

    constructor(uint32 domain) { _localDomain = domain; }

    function localDomain() external view returns (uint32) { return _localDomain; }
    function delivered(bytes32) external pure returns (bool) { return false; }
    function defaultIsm() external pure returns (IInterchainSecurityModule) {
        return IInterchainSecurityModule(address(0));
    }
    function defaultHook() external pure returns (IPostDispatchHook) {
        return IPostDispatchHook(address(0));
    }
    function requiredHook() external pure returns (IPostDispatchHook) {
        return IPostDispatchHook(address(0));
    }
    function latestDispatchedId() external view returns (bytes32) { return _latestId; }
    function nonce() external view returns (uint32) { return _nonce; }

    function dispatch(uint32 dest, bytes32 recipient, bytes calldata body)
        external payable returns (bytes32 messageId)
    {
        messageId = keccak256(abi.encode(dest, recipient, body, _nonce++));
        dispatchedMessages.push(body);
        _latestId = messageId;
        emit Dispatch(msg.sender, dest, recipient, body);
        emit DispatchId(messageId);
    }
    function dispatch(uint32 d, bytes32 r, bytes calldata b, bytes calldata)
        external payable returns (bytes32) { return this.dispatch(d, r, b); }
    function dispatch(uint32 d, bytes32 r, bytes calldata b, bytes calldata, IPostDispatchHook)
        external payable returns (bytes32) { return this.dispatch(d, r, b); }

    function quoteDispatch(uint32, bytes32, bytes calldata) external pure returns (uint256) { return 0; }
    function quoteDispatch(uint32, bytes32, bytes calldata, bytes calldata) external pure returns (uint256) { return 0; }
    function quoteDispatch(uint32, bytes32, bytes calldata, bytes calldata, IPostDispatchHook) external pure returns (uint256) { return 0; }

    function process(bytes calldata, bytes calldata) external payable {}
    function recipientIsm(address) external pure returns (IInterchainSecurityModule) {
        return IInterchainSecurityModule(address(0));
    }

    /// @dev Simula o relayer entregando uma mensagem a um destinatário.
    function deliverTo(address recipient, uint32 origin, bytes32 sender, bytes calldata body) external {
        (bool ok,) = recipient.call(
            abi.encodeWithSignature("handle(uint32,bytes32,bytes)", origin, sender, body)
        );
        require(ok, "MockMailboxAMC: delivery failed");
    }
}
