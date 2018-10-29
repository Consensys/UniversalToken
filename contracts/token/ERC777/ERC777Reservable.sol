/*
* This code has not been reviewed.
* Do not use or deploy this code before reviewing it personally first.
*/
pragma solidity ^0.4.24;

/* import { Ownable as ozs_Ownable } from "openzeppelin-solidity/contracts/ownership/Ownable.sol"; */
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "contract-certificate-controller/contracts/CertificateController.sol";

import "./ERC777.sol";


contract ERC777Reservable is CertificateController, ERC777 {
  using SafeMath for uint256;

  enum Status { Created, Validated, Cancelled }

  struct Reservation {
    Status status;
    uint256 amount;
    uint256 validUntil;
  }

  struct ReservationCoordinates {
    address owner;
    uint256 index;
  }

  uint256 public _minShares;
  bool public _burnLeftOver;

  bool public _saleEnded;
  uint256 public _reservedTotal;
  uint256 public _validatedTotal;

  mapping(address => Reservation[]) public _reservations;

  ReservationCoordinates[] public _validatedReservations;

  event TokensReserved(address investor, uint256 index, uint256 amount);
  event ReservationValidated(address investor, uint256 index);
  event SaleEnded();

  constructor(
    string name,
    string symbol,
    uint256 granularity,
    address[] defaultOperators,
    uint256 minShares,
    uint256 maxShares,
    bool burnLeftOver,
    address certificateSigner //0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630
  )
    public
    CertificateController(certificateSigner)
    ERC777(name, symbol, granularity, defaultOperators)
  {
    _minShares = minShares;
    _burnLeftOver = burnLeftOver;
    _saleEnded = false;
    _reservedTotal = 0;
    _validatedTotal = 0;

    _mint(msg.sender, this, maxShares, "", "");
  }

  modifier onlySale() {
    require(!_saleEnded, "0x45: Sale no longer available");
    _;
  }

  function reserveTokens(uint256 amount, uint256 validUntil, bytes data)
    external
    onlySale
    isValidCertificate(data)
    returns (uint256)
  {
    require(amount != 0, "0xA0: Amount should not be 0");

    uint256 index = _reservations[msg.sender].push(
      Reservation({
        status: Status.Created,
        amount: amount,
        validUntil: validUntil
      })
    );

    _reservedTotal = _reservedTotal.add(amount);

    require(_reservedTotal <= _totalSupply, "0xA0: The total reserved exceeds the total supply");

    emit TokensReserved(msg.sender, index, amount);

    return index;
  }

  function validateReservation(address owner, uint8 index)
    external
    onlySale
    onlyOwner
  {
    require(_reservations[owner].length > 0 && _reservations[owner][index].status == Status.Created, "0x20: Invalid reservation");

    Reservation storage reservation = _reservations[owner][index];
    require(reservation.validUntil != 0 && reservation.validUntil < block.number, "0x05: Reservation has expired");

    reservation.status = Status.Validated;
    _validatedReservations.push(
      ReservationCoordinates({
        owner: owner,
        index: index
      })
    );

    _validatedTotal = _validatedTotal.add(reservation.amount);

    emit ReservationValidated(owner, index);
  }

  function endSale()
    external
    onlySale
    onlyOwner
  {
    require(_minShares < _validatedTotal, "0xA0: The minimum validated has been reached");

    for (uint256 i = 0; i < _validatedReservations.length; i++) {
      Reservation storage reservation = _reservations[_validatedReservations[i].owner][_validatedReservations[i].index];
      _sendTo(this, this, _validatedReservations[i].owner, reservation.amount, "", "", true);
    }

    if (_burnLeftOver) {
      _burn(this, this, _balances[this], "");
    }

    _saleEnded = true;

    emit SaleEnded();
  }

}
