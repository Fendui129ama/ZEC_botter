// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ZEC_botter
/// @notice codename: sapling mirror crawl
/// @dev On-chain ZEC wallet watch bot: shielded fingerprints, sight lines,
///      epoch rails, and alert deltas. Pull-only operator stakes; no sinks.

library ZbtMath {
    error ZBT_MathFault();
    uint256 internal constant RATIO_BASE = 10_000;
    function clampU16(uint256 v, uint16 lo, uint16 hi) internal pure returns (uint16) {
        if (v < lo) return lo;
        if (v > hi) return hi;
        return uint16(v);
    }
    function mulBps(uint256 amt, uint256 bps) internal pure returns (uint256) {
        unchecked { return (amt * bps) / RATIO_BASE; }
    }
    function saturatingAdd(uint256 a, uint256 b, uint256 cap) internal pure returns (uint256) {
        unchecked {
            uint256 s = a + b;
            if (s < a || s > cap) revert ZBT_MathFault();
            return s;
        }
    }
}

contract ZEC_botter {
    // ── faults ───────────────────────────────────────────────────────────
    error ZBt_NotWarden();
    error ZBt_GridFrozen();
    error ZBt_ZeroAddr();
    error ZBt_ZeroAmt();
    error ZBt_Reentered();
    error ZBt_LaneMissing();
    error ZBt_LaneRetired();
    error ZBt_SightingExists();
    error ZBt_SightingMissing();
    error ZBt_TierOutOfRange();
    error ZBt_CapHit();
    error ZBt_BadEpoch();
    error ZBt_AlertOpen();
    error ZBt_AlertMissing();
    error ZBt_AlertClosed();
    error ZBt_StaleBot();
    error ZBt_ConfLow();
    error ZBt_ConfHigh();
    error ZBt_HandoffPending();
    error ZBt_NoHandoff();
    error ZBt_BadHandoff();
    error ZBt_DigestVoid();
    error ZBt_AlreadyAck();
    error ZBt_SelfAck();
    error ZBt_StakeTooSmall();
    error ZBt_TransferFail();
    error ZBt_BatchTooWide();
    error ZBt_ArrayMismatch();
    error ZBt_NotBot();
    error ZBt_BotExists();
    error ZBt_LineFault_30();
    error ZBt_LineFault_31();
    error ZBt_LineFault_32();
    error ZBt_LineFault_33();
    error ZBt_LineFault_34();
    error ZBt_LineFault_35();
    error ZBt_LineFault_36();
    error ZBt_LineFault_37();
    error ZBt_LineFault_38();
    error ZBt_LineFault_39();
    error ZBt_LineFault_40();
    error ZBt_LineFault_41();
    error ZBt_LineFault_42();
    error ZBt_LineFault_43();

    event Watched(bytes32 indexed sightId, uint256 indexed laneId, address indexed bot, uint8 tier);
    event Acked(bytes32 indexed sightId, address indexed acker, bool up);
