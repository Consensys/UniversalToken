/*
* This code has not been reviewed.
* Do not use or deploy this code before reviewing it personally first.
*/
pragma solidity ^0.4.24;

import { Ownable as ozs_Ownable } from "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "contract-certificate-controller/contracts/Controllable.sol";
import "contract-certificate-controller/contracts/CertificateController.sol";

import "./ERC777.sol";


contract ERC777Reservable is ozs_Ownable, Controllable, ERC777 {
  using SafeMath for uint256;
  
  uint256 public _minShares;
  bool public _burnLeftOver;
  bool public _saleEnded;
  uint256 public _reservedTotal;
  uint256 public _validatedTotal;

  enum Status { Created, Validated, Cancelled }

  struct Reservation {
    Status status;
    uint256 amount;
    uint256 validUntil;
  }

  mapping(address => Reservation[]) public _reservations;

  struct ReservationCoordinates { address owner; uint256 index; }
  ReservationCoordinates[] _validatedReservations;

  event TokensReserved(address, uint256, uint256);
  event ReservationValidated(address, uint256);
  event SaleEnded();

  constructor(
    string name,
    string symbol,
    uint256 granularity,
    address[] defaultOperators,
    uint256 minShares,
    uint256 maxShares,
    bool burnLeftOver
  )
  public
  Controllable(CertificateController(0xe31C41f0f70C5ff39f73B4B94bcCD767b3071630))
  ERC777(name, symbol, granularity, defaultOperators)
  {
    _minShares = minShares;
    _burnLeftOver = burnLeftOver;
    _balances[this] = maxShares;
    _totalSupply = maxShares;
  }

  modifier onlySale() {
    require(!_saleEnded, "0x45: Sale no longer available");
    _;
  }

  function _reserve(uint256 amount, uint256 validUntil)
  internal
  onlySale
  returns (uint256 index)
  {
    require(amount != 0, "0xA0: Amount should not be 0");

    index = _reservations[msg.sender].push(Reservation(Status.Created, amount, validUntil));
    _reservedTotal = _reservedTotal.add(amount);

    require(_reservedTotal <= _totalSupply, "0xA0: The total reserved exceeds the total supply");

    emit TokensReserved(msg.sender, index, amount);
  }

  function validateReservation(address owner, uint8 index)
  public
  onlyOwner
  onlySale
  {
    require(_reservations[owner].length > 0 || _reservations[owner][index].status == Status.Created, "0x20: Invalid reservation");

    Reservation storage reservation = _reservations[owner][index];
    require(reservation.validUntil != 0 && reservation.validUntil < block.number, "0x05: Reservation has expired");

    reservation.status = Status.Validated;
    _validatedReservations.push(ReservationCoordinates(owner, index));

    _validatedTotal = _validatedTotal.add(reservation.amount);

    emit ReservationValidated(owner, index);
  }

  function endSale() 
  public
  onlySale
  {
    require(_minShares < _validatedTotal, "0xA0: The minimum validated has been reached");

    for (uint256 i = 0; i < _validatedReservations.length; i++) {
      Reservation storage reservation = _reservations[_validatedReservations[i].owner][_validatedReservations[i].index];
      ERC777._send(this, this, _validatedReservations[i].owner, reservation.amount, "", "", true);
    }

    if (_burnLeftOver) {
      ERC777._burn(this, this, _balances[this], "");
    }

    _saleEnded = true;

    emit SaleEnded();
  }

  function()
  public
  isValid()
  {
    _reserve(1, 0);
  }
}
