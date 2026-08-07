// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract HelloRecipient {
    string public lastMessage;
    address public lastSender;
    bytes32 public lastRecipient;
    bytes public lastBody;

    event MessageDispatched(uint32 indexed destinationDomain, bytes32 indexed recipient, bytes body);
    event MessageReceived(string message, address sender);

    function dispatch(uint32 destinationDomain, bytes32 recipient, bytes calldata messageBody)
        external
        payable
        returns (bytes32)
    {
        lastRecipient = recipient;
        lastBody = messageBody;

        emit MessageDispatched(destinationDomain, recipient, messageBody);
        return bytes32(uint256(1));
    }

    function handle(string calldata message) external {
        lastMessage = message;
        lastSender = msg.sender;

        emit MessageReceived(message, msg.sender);
    }
}
