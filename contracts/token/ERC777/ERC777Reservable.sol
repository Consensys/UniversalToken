/*
* This code has not been reviewed.
* Do not use or deploy this code before reviewing it personally first.
*/
pragma solidity ^0.4.24;

import { Ownable as ozs_Ownable } from "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/access/roles/MinterRole.sol";

import "contract-certificate-controller/contracts/Controllable.sol";

import "./ERC777.sol";


contract ERC777Reservable is ozs_Ownable, MinterRole, Controllable, ERC777 {
    uint256 public _minShares;
    uint256 public _burnLeftOver;

    enum Status { Created, Validated, Cancelled }

    struct Reservation {
        Status status;
        uint256 amount;
        uint256 validUntil;
    }

    mapping(address => Reservation[]) public reservations;

    struct ReservationCoordinates { address owner; uint256 index; }
    ReservationCoordinates[] validatedReservations;

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
        uint256 burnLeftOver
    )
    public
    ERC777(name, symbol, granularity, defaultOperators)
    {
        _minShares = minShares;
        _burnLeftOver = burnLeftOver;
        _balances[this] = maxShares;
        _totalSupply = maxShares;
    }

    function _reserve(uint256 amount, uint256 validUntil)
    internal
    returns (uint256 index)
    {
        require(amount != 0, "0xA0: Amount should not be 0");

        index = reservations[msg.sender].push(Reservation(Status.Created, amount, validUntil));

        emit TokensReserved(msg.sender, index, amount);
    }

    function validateReservation(address owner, uint8 index)
    public
    onlyOwner
    {
        require(reservations[owner].length > 0 || reservations[owner][index].status == Status.Created, "0x20: Invalid reservation");

        Reservation storage reservation = reservations[owner][index];
        require(reservation.validUntil != 0 && reservation.validUntil < block.number, "0x05: Reservation has expired");

        reservation.status = Status.Validated;
        validatedReservations.push(ReservationCoordinates(owner, index));

        emit ReservationValidated(owner, index);
    }

    function endSale() public {
        for (uint256 i = 0; i < validatedReservations.length; i++) {
            Reservation storage reservation = reservations[validatedReservations[i].owner][validatedReservations[i].index];
            ERC777._send(this, this, validatedReservations[i].owner, reservation.amount, "", "", true);
        }
        emit SaleEnded();
    }

    function()
    public
    isValid()
    {
        _reserve(1, 0);
    }
}