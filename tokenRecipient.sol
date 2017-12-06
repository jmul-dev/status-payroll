pragma solidity ^0.4.18;

// https://www.ethereum.org/token

interface tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) public; }
