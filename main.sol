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
    event Staked(bytes32 indexed sightId, address indexed from, uint256 weiAmt);
    event Scanned(bytes32 indexed scanId, uint256 indexed laneId, bytes32 walletTag);
    event Sealed(bytes32 indexed scanId, bytes32 payloadHash, uint16 confidence);
    event Alerted(bytes32 indexed alertId, uint256 indexed laneId, uint16 deltaBand);
    event Opened(uint256 indexed laneId, bytes32 laneTag, uint8 tier);
    event Rolled(uint256 indexed epochId, uint64 wallTs, uint256 sightWeight);
    event Frozen(bool gridFrozen, address indexed by);
    event Nominated(address indexed prev, address indexed pending);
    event Swapped(address indexed prev, address indexed next);
    event BotJoined(address indexed bot, bytes32 label);
    event BotLeft(address indexed bot);
    event Pulse_0(uint256 indexed lineId, address indexed actor, uint256 meta);
    event Pulse_1(uint256 indexed lineId, address indexed actor, uint256 meta);
    event Pulse_2(uint256 indexed lineId, address indexed actor, uint256 meta);
    event Pulse_3(uint256 indexed lineId, address indexed actor, uint256 meta);
    event Pulse_4(uint256 indexed lineId, address indexed actor, uint256 meta);
    event Pulse_5(uint256 indexed lineId, address indexed actor, uint256 meta);
    event Pulse_6(uint256 indexed lineId, address indexed actor, uint256 meta);
    event Pulse_7(uint256 indexed lineId, address indexed actor, uint256 meta);
    event Pulse_8(uint256 indexed lineId, address indexed actor, uint256 meta);
    event Pulse_9(uint256 indexed lineId, address indexed actor, uint256 meta);
    event Pulse_10(uint256 indexed lineId, address indexed actor, uint256 meta);

    enum ZbtLanePhase { Draft, Live, Archived }
    enum ZbtScanPhase { Queued, Running, Done, Failed }

    struct ZbtWatchLane {
        ZbtLanePhase phase;
        uint8 privacyTier;
        uint64 openedAt;
        uint32 sightCount;
        uint32 scanCount;
        uint256 reputationSum;
        bytes32 laneTag;
    }

    struct ZbtSighting {
        uint256 laneId;
        address bot;
        bytes32 walletFingerprint;
        uint8 privacyTier;
        uint32 upAcks;
        uint32 downAcks;
        uint256 stakeWei;
        uint64 loggedAt;
        bool exists;
    }

    struct ZbtScanJob {
        uint256 laneId;
        address requester;
        bytes32 walletTag;
        ZbtScanPhase phase;
        bytes32 resultHash;
        uint16 confidence;
        uint64 queuedAt;
    }

    struct ZbtAlertCell {
        uint256 laneId;
        bytes32 deltaTag;
        bytes32 summaryHash;
        uint16 deltaBand;
        uint64 stampedAt;
    }

    struct ZbtEpochRail {
        uint64 startedAt;
        uint256 sightWeight;
        uint256 scanWeight;
        bytes32 mixHA;
        bytes32 mixHB;
    }

    struct ZbtBotOperator {
        bool active;
        bytes32 label;
        uint64 joinedAt;
        uint32 sightTally;
    }

    uint256 public constant ZBT_PRIVACY_MAX = 8;
    uint256 public constant ZBT_SIGHT_FEE = 0.004 ether;
    uint256 public constant ZBT_BOT_STAKE = 0.04 ether;
    uint256 public constant ZBT_MAX_SIGHTINGS = 175;
    uint256 public constant ZBT_OPEN_ALERT_CAP = 52;
    uint256 public constant ZBT_DELTA_FLOOR = 547;
    uint256 public constant ZBT_DELTA_CEIL = 9245;
    uint256 public constant ZBT_EPOCH_BLOCKS = 503;
    uint256 public constant ZBT_REP_CAP = 18750;
    uint256 public constant ZBT_CONF_FLOOR = 353;
    uint256 public constant ZBT_CONF_CEIL = 9194;

    bytes32 private constant _MIX_0 = 0x9e6ca3a7fdce358b93ebc1c3587de0eea02cc2fac075182246e727d23ce34e6d;
    bytes32 private constant _MIX_1 = 0xbceb518c0d956000ffdbfcf53b2b10b5eae7414096df73d854a021a9ab39b099;
    bytes32 private constant _MIX_2 = 0x1181979ddf223d56a5a806647f0152b40840e2a003a26e4a1c4b2b027799f28e;
    bytes32 private constant _MIX_3 = 0x630769bf5a449da4366b87f07963a298ba43d99d9e42b80a1c205fc71d3bc100;
    bytes32 private constant _MIX_4 = 0x856d978bcf9c8f431fcc861eda2bf0c88ee927ef150d8c7d423ac694ecce4410;
    bytes32 private constant _MIX_5 = 0x422c8e1effc2632cbcbb92741541018e25a2429a8be9c4cff71e6b1c3f711c77;
    bytes32 private constant _MIX_6 = 0xfc0063c15316e438fdde36a51d65af9c392c87b519d1e3a6353a389f60f4bdb7;
    bytes32 private constant _MIX_7 = 0x528669bdd4e6cfe8b0d51b6ad120a6679e05663d010efadf884f27c5920f39b1;
    bytes32 private constant ZBT_DOMAIN = keccak256("ZEC_botter.saplingMirrorCrawl");

    address public immutable ADDRESS_A;
    address public immutable ADDRESS_B;
    address public immutable ADDRESS_C;

    address public warden;
    address public pendingWarden;
    bool public gridFrozen;
    uint256 public activeEpoch;
    uint256 public lineSerial;
    uint256 public openScanJobs;
    uint256 public totalStakeWei;
    uint256 public genesisBlock;

    mapping(uint256 => ZbtWatchLane) public watchLanes;
    mapping(bytes32 => ZbtSighting) public sightings;
    mapping(bytes32 => ZbtScanJob) public scanJobs;
    mapping(bytes32 => ZbtAlertCell) public alerts;
    mapping(uint256 => ZbtEpochRail) public epochRails;
    mapping(uint256 => mapping(address => uint256)) public botRep;
    mapping(bytes32 => mapping(address => bool)) public ackCast;
    mapping(bytes32 => bool) public sightIdUsed;
    mapping(bytes32 => bool) public scanIdUsed;
    mapping(bytes32 => bool) public alertIdUsed;
    mapping(address => ZbtBotOperator) public botOperators;
    mapping(address => bytes32[]) private _sightsByBot;
    uint256 private _guard;

    modifier nonReentrant() {
        if (_guard == 2) revert ZBt_Reentered();
        _guard = 2;
        _;
        _guard = 1;
    }

    modifier onlyWarden() {
        if (msg.sender != warden) revert ZBt_NotWarden();
        _;
    }

    modifier whenGridLive() {
        if (gridFrozen) revert ZBt_GridFrozen();
        _;
    }

    modifier onlyActiveBot() {
        if (!botOperators[msg.sender].active) revert ZBt_NotBot();
        _;
    }

    constructor() {
        ADDRESS_A = 0xBD713dCb29cD521DB1BB78c94158cEbFCcF9aa55;
