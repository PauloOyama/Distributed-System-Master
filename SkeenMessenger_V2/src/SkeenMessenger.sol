// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMessageRecipient} from "@hyperlane-xyz/core/interfaces/IMessageRecipient.sol";
import {IMailbox} from "@hyperlane-xyz/core/interfaces/IMailbox.sol";

contract SkeenMessenger is IMessageRecipient {
    IMailbox public mailbox;
    address public owner;

    // Sender side: nonce per sender address
    mapping(address => uint256) public nextOutgoingNonce;

    // Receiver side: next expected nonce per (origin, sender)
    mapping(uint32 => mapping(bytes32 => uint256)) public nextExpectedNonce;

    // Buffer for out-of-order messages: (origin, sender, nonce) => message
    mapping(uint32 => mapping(bytes32 => mapping(uint256 => string))) private _buffer;

    event MessageSent(uint32 indexed destination, bytes32 recipient, string message);
    event MessageReceived(uint32 indexed origin, bytes32 sender, string message);

    constructor(address _mailbox) {
        mailbox = IMailbox(_mailbox);
        owner = msg.sender;
    }

    function sendMessage(
        uint32 _destinationDomain,
        address _recipient,
        string calldata _message
    ) external payable {
        uint256 nonce = ++nextOutgoingNonce[msg.sender];
        bytes memory encodedMessage = abi.encode(msg.sender, nonce, _message);
        bytes32 recipient = bytes32(uint256(uint160(_recipient)));

        mailbox.dispatch{value: msg.value}(_destinationDomain, recipient, encodedMessage);

        emit MessageSent(_destinationDomain, recipient, _message);
    }

    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _messageBody
    ) external payable {
        require(msg.sender == address(mailbox), "Only mailbox can call handle");

        (address originalSender, uint256 nonce, string memory message) =
            abi.decode(_messageBody, (address, uint256, string));

        bytes32 senderKey = bytes32(uint256(uint160(originalSender)));
        uint256 expected = nextExpectedNonce[_origin][senderKey];

        if (nonce == expected + 1) {
            // Deliver in order
            nextExpectedNonce[_origin][senderKey] = nonce;
            emit MessageReceived(_origin, _sender, message);

            // Flush any buffered consecutive messages
            uint256 next = nonce + 1;
            while (bytes(_buffer[_origin][senderKey][next]).length > 0) {
                emit MessageReceived(_origin, _sender, _buffer[_origin][senderKey][next]);
                delete _buffer[_origin][senderKey][next];
                next++;
            }
            nextExpectedNonce[_origin][senderKey] = next - 1;
        } else if (nonce > expected + 1) {
            // Out of order: buffer it
            _buffer[_origin][senderKey][nonce] = message;
        }
        // nonce <= expected: duplicate, ignore
    }
}
