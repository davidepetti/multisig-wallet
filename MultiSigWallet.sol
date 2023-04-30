// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint256 amount);
    event Submit(uint256 indexed txId);
    event Approve(address indexed owner, uint256 indexed txId);
    event Revoke(address indexed owner, uint256 indexed txId);
    event Execute(uint256 indexed txId);

    error OwnersRequired();
    error InvalidRequiredNumber();
    error InvalidOwner();
    error OwnerNotUnique();
    error NotOwner();
    error TxInexistent();
    error AlreadyApproved();
    error AlreadyExecuted();
    error ApprovalsNotAchieved();
    error TxFailed();
    error TxNotApproved();

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required;

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public approved;

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) {
            revert NotOwner();
        }
        _;
    }

    modifier txExists(uint256 _txId) {
        if (_txId >= transactions.length) {
            revert TxInexistent();
        }
        _;
    }

    modifier notApproved(uint256 _txId) {
        if (approved[_txId][msg.sender]) {
            revert AlreadyApproved();
        }
        _;
    }

    modifier notExecuted(uint256 _txId) {
        if (transactions[_txId].executed) {
            revert AlreadyExecuted();
        }
        _;
    }

    constructor(address[] memory _owners, uint256 _required) {
        if (_owners.length == 0) {
            revert OwnersRequired();
        }

        if (_required == 0 || _required > _owners.length) {
            revert InvalidRequiredNumber();
        }

        uint256 ownersLength = _owners.length;
        for (uint256 i; i < ownersLength; ++i) {
            address owner = _owners[i];

            if (owner == address(0)) {
                revert InvalidOwner();
            }

            if (isOwner[owner]) {
                revert OwnerNotUnique();
            }

            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }

    function submit(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external onlyOwner {
        transactions.push(
            Transaction({to: _to, value: _value, data: _data, executed: false})
        );
        emit Submit(transactions.length - 1);
    }

    function approve(
        uint256 _txId
    ) external onlyOwner txExists(_txId) notApproved(_txId) notExecuted(_txId) {
        approved[_txId][msg.sender] = true;
        emit Approve(msg.sender, _txId);
    }

    function _getApprovalCount(
        uint256 _txId
    ) private view returns (uint256 count) {
        uint256 ownersLength = owners.length;
        for (uint256 i; i < ownersLength; ++i) {
            if (approved[_txId][owners[i]]) {
                count += 1;
            }
        }
    }

    function execute(
        uint256 _txId
    ) external txExists(_txId) notExecuted(_txId) {
        if (_getApprovalCount(_txId) < required) {
            revert ApprovalsNotAchieved();
        }

        Transaction storage transaction = transactions[_txId];
        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );

        if (!success) {
            revert TxFailed();
        }

        emit Execute(_txId);
    }

    function revoke(
        uint _txId
    ) external onlyOwner txExists(_txId) notExecuted(_txId) {
        if (!approved[_txId][msg.sender]) {
            revert TxNotApproved();
        }

        approved[_txId][msg.sender] = false;
        emit Revoke(msg.sender, _txId);
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }
}
