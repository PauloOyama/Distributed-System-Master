// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMailboxLike {
    function dispatch(uint32 destinationDomain, bytes32 recipient, bytes calldata messageBody)
        external
        payable
        returns (bytes32);
}

contract SimpleHelloMessenger {
    IMailboxLike public mailbox;
    string public lastMessage;

    event MessageSent(uint32 indexed destinationDomain, bytes32 indexed recipient, string message);
    event MessageReceived(uint32 indexed originDomain, bytes32 indexed sender, string message);

    constructor(address _mailbox) {
        mailbox = IMailboxLike(_mailbox);
    }

    function sendHello(uint32 destinationDomain, address recipient) external payable {
        bytes32 recipientBytes = bytes32(uint256(uint160(recipient)));
        string memory message = "OLA DA REDE A";

        mailbox.dispatch{value: msg.value}(destinationDomain, recipientBytes, abi.encode(message));

        emit MessageSent(destinationDomain, recipientBytes, message);
    }

    function handle(uint32 originDomain, bytes32 sender, bytes calldata messageBody) external {
        require(msg.sender == address(mailbox), "only mailbox");

        string memory message = abi.decode(messageBody, (string));
        lastMessage = message;

        emit MessageReceived(originDomain, sender, message);
    }
}
