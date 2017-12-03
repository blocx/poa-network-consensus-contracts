pragma solidity ^0.4.18;
import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "./interfaces/IBallotsStorage.sol";

contract KeysManager {
  function isVotingActive(address _votingKey) public view returns(bool);
  function getMiningKeyByVoting(address _votingKey) public view returns(address);
}
contract ValidatorMetadata {
  using SafeMath for uint256;
  struct Validator {
      bytes32 firstName;
      bytes32 lastName;
      bytes32 licenseId;
      string fullAddress;
      bytes32 state;
      uint256 zipcode;
      uint256 expirationDate;
      uint256 createdDate;
      uint256 updatedDate;
      uint256 minThreshold;
  }
  KeysManager public keysManager;
  IBallotsStorage public ballotsStorage;
  event MetadataCreated(address indexed miningKey);
  event ChangeRequestInitiated(address indexed miningKey);
  event CancelledRequest(address indexed miningKey);
  event Confirmed(address indexed miningKey, address votingSender);
  event FinalizedChange(address indexed miningKey);
  mapping(address => Validator) public validators;
  mapping(address => Validator) public pendingChanges;
  mapping(address => uint256) public confirmations;

  modifier onlyValidVotingKey(address _votingKey) {
      require(keysManager.isVotingActive(_votingKey));
      _;
  }

  modifier onlyFirstTime(address _votingKey) {
      address miningKey = getMiningByVotingKey(msg.sender);
      Validator storage validator = validators[miningKey];
      require(validator.createdDate == 0);
      _;
  }

  function ValidatorMetadata(address _keysContract, address _ballotsStorage) public {
      keysManager = KeysManager(_keysContract);
      ballotsStorage = IBallotsStorage(_ballotsStorage);
  }

  function createMetadata(
      bytes32 _firstName,
      bytes32 _lastName,
      bytes32 _licenseId,
      string _fullAddress,
      bytes32 _state,
      uint256 _zipcode,
      uint256 _expirationDate
  ) public onlyValidVotingKey(msg.sender) onlyFirstTime(msg.sender)
  {
    Validator memory validator = Validator({
      firstName: _firstName,
      lastName: _lastName,
      licenseId: _licenseId,
      fullAddress: _fullAddress,
      zipcode: _zipcode,
      state: _state,
      expirationDate: _expirationDate,
      createdDate: getTime(),
      updatedDate: 0,
      minThreshold: getMinThreshold()
    });
    address miningKey = getMiningByVotingKey(msg.sender);
    validators[miningKey] = validator;
    MetadataCreated(miningKey);
  }

  function changeRequest(
      bytes32 _firstName,
      bytes32 _lastName,
      bytes32 _licenseId,
      string _fullAddress,
      bytes32 _state,
      uint256 _zipcode,
      uint256 _expirationDate
  ) public onlyValidVotingKey(msg.sender) returns(bool) {
    address miningKey = getMiningByVotingKey(msg.sender);
    Validator memory pendingChange = Validator({
      firstName: _firstName,
      lastName: _lastName,
      licenseId: _licenseId,
      fullAddress:_fullAddress,
      state: _state,
      zipcode: _zipcode,
      expirationDate: _expirationDate,
      createdDate: validators[miningKey].createdDate,
      updatedDate: getTime(),
      minThreshold: validators[miningKey].minThreshold
    });
    pendingChanges[miningKey] = pendingChange;
    ChangeRequestInitiated(miningKey);
    return true;
  }

  function cancelPendingChange() public onlyValidVotingKey(msg.sender) returns(bool) {
    address miningKey = getMiningByVotingKey(msg.sender);
    delete pendingChanges[miningKey];
    CancelledRequest(miningKey);
    return true;
  }

  function confirmPendingChange(address _miningKey) public onlyValidVotingKey(msg.sender) {
    address miningKey = getMiningByVotingKey(msg.sender);
    require(miningKey != _miningKey);
    confirmations[_miningKey] = confirmations[_miningKey].add(1);
    Confirmed(_miningKey, msg.sender);
  }

  function finalize(address _miningKey) public onlyValidVotingKey(msg.sender) {
    require(confirmations[_miningKey] >= pendingChanges[_miningKey].minThreshold);
    validators[_miningKey] = pendingChanges[_miningKey];
    delete pendingChanges[_miningKey];
    FinalizedChange(_miningKey);
  }

  function getMiningByVotingKey(address _votingKey) public view returns(address) {
    return keysManager.getMiningKeyByVoting(_votingKey);
  }

  function getTime() public view returns(uint256) {
    return now;
  }

  function getMinThreshold() public view returns(uint256) {
    uint8 thresholdType = 2;
    return ballotsStorage.getBallotThreshold(thresholdType);
  }

}