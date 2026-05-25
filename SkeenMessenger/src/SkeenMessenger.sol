// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMessageRecipient} from "@hyperlane-xyz/core/contracts/interfaces/IMessageRecipient.sol";
import {IMailbox} from "@hyperlane-xyz/core/contracts/interfaces/IMailbox.sol";

contract SkeenMessenger is IMessageRecipient {
    IMailbox public mailbox;
    address public owner;

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
        bytes memory encodedMessage = abi.encode(_message);
        bytes32 recipient = bytes32(uint256(uint160(_recipient)));

        mailbox.dispatch{value: msg.value}(
            _destinationDomain,
            recipient,
            encodedMessage
        );

        emit MessageSent(_destinationDomain, recipient, _message);
    }

    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _messageBody
    ) external {
        require(msg.sender == address(mailbox), "Only mailbox can call handle");

        string memory message = abi.decode(_messageBody, (string));
        emit MessageReceived(_origin, _sender, message);
    }
}
