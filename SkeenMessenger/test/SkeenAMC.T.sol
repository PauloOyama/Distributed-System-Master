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


// ─────────────────────────────────────────────────────────────────────────────
// Suite de testes do SkeenAMC
// ─────────────────────────────────────────────────────────────────────────────
contract SkeenAMCTest is Test {

    uint32 constant CHAIN_A = 31337;
    uint32 constant CHAIN_B = 31338;
    address constant CALLER = address(0xCAFE);

    MockMailboxAMC mailboxA;
    MockMailboxAMC mailboxB;
    SkeenMessenger messengerA;
    SkeenMessenger messengerB;
    SkeenAMC amcA;
    SkeenAMC amcB;

    uint32[] destinations;
    bytes txnData;
    bytes32 txnId;

    function setUp() public {
        // Criar mailboxes mock
        mailboxA = new MockMailboxAMC(CHAIN_A);
        mailboxB = new MockMailboxAMC(CHAIN_B);

        // Criar messengers
        messengerA = new SkeenMessenger(address(mailboxA));
        messengerB = new SkeenMessenger(address(mailboxB));

        // Criar AMCs — mailbox é quem chama handle()
        amcA = new SkeenAMC(address(messengerA), address(mailboxA));
        amcB = new SkeenAMC(address(messengerB), address(mailboxB));

        // Dados padrão de teste
        destinations = new uint32[](2);
        destinations[0] = CHAIN_A;
        destinations[1] = CHAIN_B;

        txnData = abi.encode("test-transaction", uint256(42));
        txnId   =  keccak256(txnData);
        
    }

// =========================================================================
    // RODADA 1: START
    // =========================================================================

    function test_StartPhase_MulticastEmitsEvents() public {
        console2.log("=== test_StartPhase_MulticastEmitsEvents ===");

        vm.expectEmit(true, false, false, true);
        emit SkeenAMC.TxnStarted(txnId, destinations, block.timestamp);

        vm.expectEmit(true, false, false, true);
        emit SkeenAMC.PhaseAdvanced(txnId, SkeenAMC.Phase.START);

        vm.prank(CALLER);
        amcA.multicast(txnData, destinations, SkeenAMC.Mode.Cooperative);

        // console2.log("[txnId] ---> ", txnId);
        assertEq(uint8(amcA.getPhase(txnId)), uint8(SkeenAMC.Phase.START));
        console2.log("[START] txnId phase:", uint8(amcA.getPhase(txnId)));
        // console2.log("[START] txnId phase:", amcA.getPhase(txnId));
        console2.log("[START] Mensagens dispatch no Mailbox A:", mailboxA.nonce());
    }


    function test_StartPhase_DispatchesMsgToAllDestinations() public {
        console2.log("=== test_StartPhase_DispatchesMsgToAllDestinations ===");

        vm.prank(CALLER);
        amcA.multicast(txnData, destinations, SkeenAMC.Mode.Cooperative);

        // Cada destino recebe uma mensagem START
        assertEq(mailboxA.nonce(), uint32(destinations.length),
            "Mailbox deve ter dispatch para cada destino");
        console2.log("[START] Dispatches realizados:", mailboxA.nonce());
    }

    function test_StartPhase_RevertOnDuplicate() public {
        console2.log("=== test_StartPhase_RevertOnDuplicate ===");

        vm.prank(CALLER);
        amcA.multicast(txnData, destinations, SkeenAMC.Mode.Cooperative);

        vm.prank(CALLER);
        vm.expectRevert("Transacao ja iniciada");
        amcA.multicast(txnData, destinations, SkeenAMC.Mode.Cooperative);
        console2.log("[START] Revert em duplicata: OK");
    }
}