// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract HelloRelayer {
    address public mailbox;
    string public lastMessage;

    event MessageReceived(uint32 indexed origin, bytes32 indexed sender, string message);

    constructor(address _mailbox) {
        mailbox = _mailbox;
    }

    function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external {
        require(msg.sender == mailbox, "only mailbox");

        string memory message = abi.decode(_message, (string));
        lastMessage = message;

        emit MessageReceived(_origin, _sender, message);
    }
}
