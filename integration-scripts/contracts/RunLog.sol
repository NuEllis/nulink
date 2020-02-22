pragma solidity ^0.4.24;

import "@nulink/contracts/src/v0.4/NuLinked.sol";

contract RunLog is NuLinked {
  uint256 constant private ORACLE_PAYMENT = 1 * LINK; // solium-disable-line zeppelin/no-arithmetic-operations

  event Fulfillment(bytes32 data);

  constructor(address _link, address _oracle) public {
    setLinkToken(_link);
    setOracle(_oracle);
  }

  function request(bytes32 _jobId) public {
    NuLink.Request memory req = newRequest(_jobId, this, this.fulfill.selector);
    req.add("msg", "hello_nulink");
    nulinkRequest(req, ORACLE_PAYMENT);
  }

  function fulfill(bytes32 _externalId, bytes32 _data)
    public
    recordNuLinkFulfillment(_externalId)
  {
      emit Fulfillment(_data);
  }
}
