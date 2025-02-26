// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigWalletViaConfirmation {
    // 多签持有者列表
    address[] public owners;
    // 签名门槛
    uint256 public required;
    // 提案结构体
    struct Proposal {
        address to;           // 目标地址
        uint256 value;        // 发送的 ETH 数量（wei）
        bytes data;           // 调用数据（如函数调用）
        bool executed;        // 是否已执行
        uint256 confirmations; // 当前确认数
    }
    // 提案列表
    Proposal[] public proposals;
    // 记录每个提案的确认情况：proposalId => owner => 是否已确认
    mapping(uint256 => mapping(address => bool)) public confirmations;

    // 事件
    event ProposalSubmitted(uint256 indexed proposalId, address indexed proposer, address to, uint256 value, bytes data);
    event ProposalConfirmed(uint256 indexed proposalId, address indexed owner);
    event ProposalExecuted(uint256 indexed proposalId);

    // 修饰符：仅限多签持有者
    modifier onlyOwner() {
        require(isOwner(msg.sender), "Not an owner");
        _;
    }

    // 修饰符：提案是否存在且未执行
    modifier proposalExists(uint256 proposalId) {
        require(proposalId < proposals.length, "Proposal does not exist");
        require(!proposals[proposalId].executed, "Proposal already executed");
        _;
    }

    // 构造函数：初始化多签钱包
    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(_required > 0 && _required <= _owners.length, "Invalid required number");

        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Invalid owner address");
            for (uint256 j = 0; j < i; j++) {
                require(_owners[i] != _owners[j], "Duplicate owner");
            }
            owners.push(_owners[i]);
        }
        required = _required;
    }

    // 接收 ETH 的函数
    receive() external payable {}

    // 检查是否为多签持有者
    function isOwner(address account) private view returns (bool) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == account) {
                return true;
            }
        }
        return false;
    }

    // 提交提案
    function submitProposal(address _to, uint256 _value, bytes memory _data) external onlyOwner returns (uint256) {
        uint256 proposalId = proposals.length;
        proposals.push(Proposal({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmations: 0
        }));
        emit ProposalSubmitted(proposalId, msg.sender, _to, _value, _data);
        return proposalId;
    }

    // 确认提案
    function confirmProposal(uint256 proposalId) external onlyOwner proposalExists(proposalId) {
        require(!confirmations[proposalId][msg.sender], "Already confirmed");

        confirmations[proposalId][msg.sender] = true;
        proposals[proposalId].confirmations++;

        emit ProposalConfirmed(proposalId, msg.sender);
    }

    // 执行提案
    function executeProposal(uint256 proposalId) external proposalExists(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.confirmations >= required, "Not enough confirmations");

        proposal.executed = true;
        (bool success, ) = proposal.to.call{value: proposal.value}(proposal.data);
        require(success, "Transaction execution failed");

        emit ProposalExecuted(proposalId);
    }

    // 查询提案详情（辅助函数）
    function getProposal(uint256 proposalId) external view returns (address to_, uint256 value_, bytes memory data_, bool executed_, uint256 confirmations_) {
        require(proposalId < proposals.length, "Proposal does not exist");
        Proposal memory proposal = proposals[proposalId];
        return (proposal.to, proposal.value, proposal.data, proposal.executed, proposal.confirmations);
    }

    // 查询多签持有者（辅助函数）
    function getOwners() external view returns (address[] memory) {
        return owners;
    }
}