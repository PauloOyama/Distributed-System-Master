// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMailboxLike {
    function dispatch(uint32 destinationDomain, bytes32 recipient, bytes calldata messageBody)
        external
        payable
        returns (bytes32);
}

interface IMessageRecipientLike {
    function handle(uint32 originDomain, bytes32 sender, bytes calldata messageBody) external;
}

contract HelloRelayer is IMessageRecipientLike {
    IMailboxLike public mailbox;
    string public lastMessage;
    uint256 public lastNonce;

    event MessageSent(uint32 indexed destinationDomain, bytes32 indexed recipient, string message);
    event MessageReceived(uint32 indexed originDomain, bytes32 indexed sender, string message);

    constructor(address _mailbox) {
        mailbox = IMailboxLike(_mailbox);
    }

    function sendHello(uint32 destinationDomain, address recipient, string calldata message)
        external
        payable
    {
        bytes32 recipientBytes = bytes32(uint256(uint160(recipient)));
        bytes memory body = abi.encode(message);

        mailbox.dispatch{value: msg.value}(destinationDomain, recipientBytes, body);

        emit MessageSent(destinationDomain, recipientBytes, message);
    }

    function handle(uint32 originDomain, bytes32 sender, bytes calldata messageBody) external override {
        require(msg.sender == address(mailbox), "only mailbox");

        string memory message = abi.decode(messageBody, (string));
        lastMessage = message;
        lastNonce += 1;

        emit MessageReceived(originDomain, sender, message);
    }
}
