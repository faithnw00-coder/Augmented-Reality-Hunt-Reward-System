# 🎯 Augmented Reality Hunt Reward System

A blockchain-powered AR treasure hunting platform that enables geofenced location-based challenges with on-chain reward distribution! 🏆

## 📖 Overview

The AR Hunt Reward System allows creators to set up location-based augmented reality treasure hunts with cryptographic proof verification and automatic reward distribution via Stacks blockchain smart contracts.

### ✨ Key Features

- 🌍 **Geofenced Hunts**: Create location-based challenges with precise coordinate boundaries
- 🔐 **Device Proof Verification**: Cryptographic proof system to verify authentic location claims
- 💰 **Automated Rewards**: Instant on-chain token distribution upon successful completion
- 📊 **User Statistics**: Track completion history and earnings across all participants
- ⏰ **Time-bound Events**: Configurable start/end blocks for hunt duration
- 🏁 **Participant Limits**: Control maximum number of hunters per event

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://docs.hiro.so/clarinet) installed
- Stacks wallet for testing
- Node.js for running tests

### Installation

```bash
git clone https://github.com/your-username/Augmented-Reality-Hunt-Reward-System.git
cd Augmented-Reality-Hunt-Reward-System
clarinet check
```

## 📋 Contract Functions

### Public Functions

#### `create-hunt`
Create a new AR treasure hunt with specified parameters.

**Parameters:**
- `title` - Hunt name (max 64 characters)
- `description` - Hunt details (max 256 characters)  
- `center-lat` - Latitude coordinate of hunt center
- `center-lng` - Longitude coordinate of hunt center
- `radius` - Geofence radius in coordinate units
- `reward-amount` - Tokens awarded per successful completion
- `max-participants` - Maximum number of hunters allowed
- `duration-blocks` - Hunt duration in Stacks blocks

#### `participate-in-hunt`
Join an active hunt and claim rewards upon location verification.

**Parameters:**
- `hunt-id` - Unique hunt identifier
- `device-proof-hash` - Cryptographic proof of device authenticity
- `location-lat` - Hunter's current latitude
- `location-lng` - Hunter's current longitude

#### `deactivate-hunt`
Deactivate a hunt (creator or contract owner only).

#### `emergency-withdraw`
Withdraw unclaimed rewards after hunt expiration (creator only).

### Read-Only Functions

#### `get-hunt`
Retrieve complete hunt information by ID.

#### `get-hunt-participation` 
Check if a user has participated in a specific hunt.

#### `get-user-stats`
View user's hunting statistics and total earnings.

#### `is-hunt-active`
Check if a hunt is currently active and accepting participants.

#### `get-hunt-status`
Get detailed status information including participant count and time remaining.

#### `can-participate`
Verify if a user is eligible to join a specific hunt.

## 🎮 Usage Examples

### Creating a Hunt

```clarity
(contract-call? .augmented-reality-hunt-reward-system create-hunt 
  "Downtown Treasure Quest"
  "Find the hidden AR markers around the city center!"
  40748817  ;; NYC coordinates
  -73985428
  u1000     ;; 1000 unit radius
  u100      ;; 100 token reward
  u50       ;; max 50 participants
  u1440     ;; 1440 blocks (~10 hours)
)
```

### Participating in a Hunt

```clarity
(contract-call? .augmented-reality-hunt-reward-system participate-in-hunt
  u1  ;; hunt ID
  0x1234567890abcdef... ;; device proof hash
  40748900  ;; current lat
  -73985500 ;; current lng
)
```

### Checking Hunt Status

```clarity
(contract-call? .augmented-reality-hunt-reward-system get-hunt-status u1)
```

## 🔒 Security Features

- **Geofence Validation**: Mathematical verification of location within hunt boundaries
- **Double-Claim Prevention**: Each user can only participate once per hunt
- **Time-bound Execution**: Hunts automatically expire based on block height
- **Access Control**: Hunt creators maintain control over their events
- **Emergency Procedures**: Failsafe mechanisms for fund recovery

## 📊 Token Economics

The system uses a fungible token (`hunt-token`) for rewards:
- Tokens are minted when hunts are created
- Automatic distribution upon successful completion
- Creators can withdraw unclaimed tokens after expiration
- Built-in statistics tracking for transparency

## 🧪 Testing

Run the test suite:

```bash
npm install
npm test
```

Check contract validity:

```bash
clarinet check
```

## 📝 Error Codes

- `u100` - ERR_UNAUTHORIZED: Insufficient permissions
- `u101` - ERR_HUNT_NOT_FOUND: Hunt ID doesn't exist
- `u102` - ERR_HUNT_EXPIRED: Hunt has ended
- `u103` - ERR_HUNT_NOT_ACTIVE: Hunt is not currently active
- `u104` - ERR_INVALID_COORDINATES: Invalid location data
- `u105` - ERR_ALREADY_CLAIMED: User already participated
- `u106` - ERR_INSUFFICIENT_REWARDS: Not enough tokens available
- `u107` - ERR_INVALID_PROOF: Device proof validation failed
- `u108` - ERR_OUT_OF_GEOFENCE: Location outside hunt boundaries
- `u109` - ERR_HUNT_FULL: Maximum participants reached
- `u110` - ERR_INVALID_HUNT_ID: Hunt ID format invalid
- `u113` - ERR_HUNT_NOT_EXPIRED: Hunt still active (for withdrawals)

## 🤝 Contributing

We welcome contributions! Please read our contributing guidelines and submit pull requests for any improvements.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Built with [Clarity](https://clarity-lang.org/) smart contract language
- Powered by [Stacks](https://stacks.co/) blockchain
- Inspired by the growing AR and blockchain gaming communities

---

**Happy Hunting!** 🎯✨

# Augmented Reality Hunt Reward System

