// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.19;

/**
 * Gnosis Safe Enum for operation types
 */
library Enum {
    enum Operation {
        Call,
        DelegateCall
    }
}

/**
 * Minimal IGuard interface (Gnosis Safe / Zodiac)
 */
interface IGuard {
    function checkTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes calldata signatures,
        address msgSender
    ) external;

    function checkAfterExecution(bytes32 txHash, bool success) external;
}

/**
 * Minimal ERC165
 */
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

/**
 * Minimal Azorius interface used by the guard.
 * - getProposal: to fetch proposal data including tx hashes
 * - getTxHash: to recompute txHash during execution check
 */
interface IAzorius {
    function getProposal(uint32 proposalId)
        external
        view
        returns (
            address strategy,
            bytes32[] memory txHashes,
            uint32 timelockPeriod,
            uint32 executionPeriod,
            uint32 executionCounter
        );

    function getTxHash(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) external view returns (bytes32);
}

/**
 * SecurityCouncilGuard
 *
 * - Acts as a Guard (IGuard) that blocks execution if txHash is vetoed.
 * - Allows vetoing by Azorius proposalId by fetching txHashes on-demand and marking them vetoed.
 * - Only a designated multisig ("council") can veto/unveto.
 * - Includes multicall for batching council ops.
 */
contract SecurityCouncilGuard is IGuard, IERC165 {
    // --- config ---
    address public immutable council; // multisig that can veto/unveto
    address public immutable azorius; // Azorius module address (used to fetch + recompute tx hashes)

    // --- veto storage ---
    mapping(bytes32 => bool) public vetoedTxHash; // txHash => vetoed?

    // --- events ---
    event ProposalVetoed(uint32 indexed proposalId, uint256 txCount);
    event ProposalUnvetoed(uint32 indexed proposalId, uint256 txCount);
    event TxHashVetoed(bytes32 indexed txHash);
    event TxHashUnvetoed(bytes32 indexed txHash);

    error NotCouncil();
    error AlreadyVetoed(bytes32 txHash);
    error NotVetoed(bytes32 txHash);
    error TransactionVetoed(bytes32 txHash);

    modifier onlyCouncil() {
        if (msg.sender != council) revert NotCouncil();
        _;
    }

    constructor(address _council, address _azorius) {
        require(_council != address(0), "council=0");
        require(_azorius != address(0), "azorius=0");
        council = _council;
        azorius = _azorius;
    }

    // -------------------------
    // Council operations
    // -------------------------

    /**
     * Veto a proposal by id: fetches Azorius txHashes onchain and marks them vetoed.
     * Blocks any execution attempt of those exact txs via this Guard.
     */
    function vetoProposal(uint32 proposalId) external onlyCouncil {
        bytes32[] memory txs = _getProposalTxHashes(proposalId);
        uint256 n = txs.length;

        for (uint256 i = 0; i < n; i++) {
            bytes32 h = txs[i];
            vetoedTxHash[h] = true; // set true even if already true (idempotent)
            emit TxHashVetoed(h);
        }

        emit ProposalVetoed(proposalId, n);
    }

    /**
     * Remove veto for all txHashes in this proposal.
     * Fetches txHashes from Azorius and clears their veto status.
     */
    function unvetoProposal(uint32 proposalId) external onlyCouncil {
        bytes32[] memory txs = _getProposalTxHashes(proposalId);
        uint256 n = txs.length;

        for (uint256 i = 0; i < n; i++) {
            bytes32 h = txs[i];
            vetoedTxHash[h] = false; // set false even if already false (idempotent)
            emit TxHashUnvetoed(h);
        }

        emit ProposalUnvetoed(proposalId, n);
    }

    /**
     * Fine-grained controls (optional but useful).
     */
    function vetoTx(bytes32 txHash) external onlyCouncil {
        if (vetoedTxHash[txHash]) revert AlreadyVetoed(txHash);
        vetoedTxHash[txHash] = true;
        emit TxHashVetoed(txHash);
    }

    function unvetoTx(bytes32 txHash) external onlyCouncil {
        if (!vetoedTxHash[txHash]) revert NotVetoed(txHash);
        vetoedTxHash[txHash] = false;
        emit TxHashUnvetoed(txHash);
    }

    /**
     * Multicall for batching council actions.
     * Uses delegatecall so msg.sender remains the council for internal calls.
     */
    function multicall(bytes[] calldata calls) external onlyCouncil returns (bytes[] memory results) {
        results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool ok, bytes memory ret) = address(this).delegatecall(calls[i]);
            require(ok, "multicall failed");
            results[i] = ret;
        }
    }

    // -------------------------
    // Guard interface
    // -------------------------

    /**
     * Block execution if the txHash (computed exactly as Azorius computes) is vetoed.
     *
     * Note: we intentionally ignore Safe-multisig-only fields because module exec() zeroes them anyway.
     */
    function checkTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256,
        uint256,
        uint256,
        address,
        address payable,
        bytes calldata,
        address
    ) external override {
        bytes32 h = IAzorius(azorius).getTxHash(to, value, data, operation);
        if (vetoedTxHash[h]) revert TransactionVetoed(h);
    }

    function checkAfterExecution(bytes32, bool) external override {
        // no-op (could log / add metrics if desired)
    }

    // ERC165
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IGuard).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    // -------------------------
    // View helpers
    // -------------------------

    /**
     * Check if all transactions in a proposal are vetoed.
     * Returns false if proposal has no transactions or any tx is not vetoed.
     */
    function isProposalVetoed(uint32 proposalId) external view returns (bool) {
        bytes32[] memory txs = _getProposalTxHashes(proposalId);
        uint256 n = txs.length;
        if (n == 0) return false;

        for (uint256 i = 0; i < n; i++) {
            if (!vetoedTxHash[txs[i]]) return false;
        }
        return true;
    }

    // -------------------------
    // Internal helpers
    // -------------------------

    /**
     * Fetches txHashes for a proposal from Azorius.
     */
    function _getProposalTxHashes(uint32 proposalId) internal view returns (bytes32[] memory txHashes) {
        (, txHashes, , , ) = IAzorius(azorius).getProposal(proposalId);
    }
}
