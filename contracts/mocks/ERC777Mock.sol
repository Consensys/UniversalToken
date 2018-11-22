pragma solidity ^0.4.24;
import "../token/ERC777/ERC777Mintable.sol";
import "./CertificateControllerMock.sol";


contract ERC777Mock is ERC777Mintable, CertificateControllerMock {}
