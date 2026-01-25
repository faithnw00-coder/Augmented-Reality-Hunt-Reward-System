(define-trait device-proof-trait
  (
    (verify-location (uint uint int int) (response bool uint))
  )
)

(define-fungible-token hunt-token)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_HUNT_NOT_FOUND (err u101))
(define-constant ERR_HUNT_EXPIRED (err u102))
(define-constant ERR_HUNT_NOT_ACTIVE (err u103))
(define-constant ERR_INVALID_COORDINATES (err u104))
(define-constant ERR_ALREADY_CLAIMED (err u105))
(define-constant ERR_INSUFFICIENT_REWARDS (err u106))
(define-constant ERR_INVALID_PROOF (err u107))
(define-constant ERR_OUT_OF_GEOFENCE (err u108))
(define-constant ERR_HUNT_FULL (err u109))
(define-constant ERR_INVALID_HUNT_ID (err u110))
(define-constant ERR_HUNT_NOT_EXPIRED (err u113))
(define-constant ERR_INVALID_DIFFICULTY (err u114))
(define-constant ERR_SELF_REFERRAL (err u115))
(define-constant ERR_ALREADY_REFERRED (err u116))
(define-constant REFERRAL_BONUS_PERCENT u10)
(define-constant DIFFICULTY_BASE_MULTIPLIER u100)
(define-constant MAX_DIFFICULTY_MULTIPLIER u300)
(define-constant MIN_DIFFICULTY_MULTIPLIER u50)

(define-data-var next-hunt-id uint u1)
(define-data-var total-hunts-created uint u0)
(define-data-var total-rewards-distributed uint u0)
(define-data-var global-completion-rate uint u0)
(define-data-var total-referral-bonuses uint u0)

(define-map hunts
  { hunt-id: uint }
  {
    creator: principal,
    title: (string-ascii 64),
    description: (string-ascii 256),
    center-lat: int,
    center-lng: int,
    radius: uint,
    reward-amount: uint,
    max-participants: uint,
    current-participants: uint,
    start-block: uint,
    end-block: uint,
    is-active: bool,
    difficulty-score: uint,
    base-reward: uint,
    final-reward: uint
  }
)

(define-map hunt-participants
  { hunt-id: uint, participant: principal }
  {
    claimed-at: uint,
    device-proof-hash: (buff 32),
    location-lat: int,
    location-lng: int
  }
)

(define-map user-stats
  { user: principal }
  {
    hunts-completed: uint,
    total-rewards-earned: uint,
    last-hunt-block: uint
  }
)

(define-map hunt-leaderboard
  { hunt-id: uint, rank: uint }
  {
    participant: principal,
    completion-time: uint,
    reward-earned: uint
  }
)

(define-map hunt-leaderboard-meta
  { hunt-id: uint }
  {
    next-rank: uint
  }
)

(define-map hunt-difficulty-metrics
  { hunt-id: uint }
  {
    time-pressure-factor: uint,
    location-remoteness: uint,
    completion-rate: uint,
    multiplier-applied: uint
  }
)

(define-map referrals
  { referee: principal }
  {
    referrer: principal,
    hunt-id: uint,
    bonus-paid: uint,
    referred-at: uint
  }
)

(define-map referrer-stats
  { referrer: principal }
  {
    total-referrals: uint,
    total-bonus-earned: uint
  }
)

(define-public (create-hunt 
  (title (string-ascii 64))
  (description (string-ascii 256))
  (center-lat int)
  (center-lng int)
  (radius uint)
  (reward-amount uint)
  (max-participants uint)
  (duration-blocks uint)
)
  (let 
    (
      (hunt-id (var-get next-hunt-id))
      (start-block (+ stacks-block-height u1))
      (end-block (+ start-block duration-blocks))
      (difficulty-score (calculate-hunt-difficulty duration-blocks radius))
      (multiplier (calculate-reward-multiplier difficulty-score))
      (final-reward (/ (* reward-amount multiplier) DIFFICULTY_BASE_MULTIPLIER))
    )
    (asserts! (> radius u0) ERR_INVALID_COORDINATES)
    (asserts! (> reward-amount u0) ERR_INSUFFICIENT_REWARDS)
    (asserts! (> max-participants u0) (err u111))
    (asserts! (> duration-blocks u0) (err u112))
    (asserts! (and (>= multiplier MIN_DIFFICULTY_MULTIPLIER) (<= multiplier MAX_DIFFICULTY_MULTIPLIER)) ERR_INVALID_DIFFICULTY)
    
    (try! (ft-mint? hunt-token (* final-reward max-participants) (as-contract tx-sender)))
    
    (map-set hunts
      { hunt-id: hunt-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        center-lat: center-lat,
        center-lng: center-lng,
        radius: radius,
        reward-amount: reward-amount,
        max-participants: max-participants,
        current-participants: u0,
        start-block: start-block,
        end-block: end-block,
        is-active: true,
        difficulty-score: difficulty-score,
        base-reward: reward-amount,
        final-reward: final-reward
      }
    )
    
    (map-set hunt-difficulty-metrics
      { hunt-id: hunt-id }
      {
        time-pressure-factor: (calculate-time-pressure duration-blocks),
        location-remoteness: (calculate-location-remoteness radius),
        completion-rate: u0,
        multiplier-applied: multiplier
      }
    )
    
    (var-set next-hunt-id (+ hunt-id u1))
    (var-set total-hunts-created (+ (var-get total-hunts-created) u1))
    
    (ok hunt-id)
  )
)

(define-public (participate-in-hunt
  (hunt-id uint)
  (device-proof-hash (buff 32))
  (location-lat int)
  (location-lng int)
)
  (let
    (
      (hunt (unwrap! (map-get? hunts { hunt-id: hunt-id }) ERR_HUNT_NOT_FOUND))
      (participant-key { hunt-id: hunt-id, participant: tx-sender })
      (leaderboard-meta (default-to { next-rank: u1 } (map-get? hunt-leaderboard-meta { hunt-id: hunt-id })))
      (rank (get next-rank leaderboard-meta))
      (completion-time (- stacks-block-height (get start-block hunt)))
    )
    (asserts! (get is-active hunt) ERR_HUNT_NOT_ACTIVE)
    (asserts! (>= stacks-block-height (get start-block hunt)) ERR_HUNT_NOT_ACTIVE)
    (asserts! (<= stacks-block-height (get end-block hunt)) ERR_HUNT_EXPIRED)
    (asserts! (is-none (map-get? hunt-participants participant-key)) ERR_ALREADY_CLAIMED)
    (asserts! (< (get current-participants hunt) (get max-participants hunt)) ERR_HUNT_FULL)
    (asserts! (is-within-geofence location-lat location-lng (get center-lat hunt) (get center-lng hunt) (get radius hunt)) ERR_OUT_OF_GEOFENCE)

    (map-set hunt-participants
      participant-key
      {
        claimed-at: stacks-block-height,
        device-proof-hash: device-proof-hash,
        location-lat: location-lat,
        location-lng: location-lng
      }
    )

    (map-set hunts
      { hunt-id: hunt-id }
      (merge hunt { current-participants: (+ (get current-participants hunt) u1) })
    )

    (map-set hunt-leaderboard
      { hunt-id: hunt-id, rank: rank }
      {
        participant: tx-sender,
        completion-time: completion-time,
        reward-earned: (get final-reward hunt)
      }
    )

    (map-set hunt-leaderboard-meta
      { hunt-id: hunt-id }
      { next-rank: (+ rank u1) }
    )

    (try! (as-contract (ft-transfer? hunt-token (get final-reward hunt) tx-sender tx-sender)))

    (update-user-stats tx-sender (get final-reward hunt))
    (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) (get final-reward hunt)))

    (ok true)
  )
)

(define-public (deactivate-hunt (hunt-id uint))
  (let
    (
      (hunt (unwrap! (map-get? hunts { hunt-id: hunt-id }) ERR_HUNT_NOT_FOUND))
    )
    (asserts! (or (is-eq tx-sender (get creator hunt)) (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
    
    (map-set hunts
      { hunt-id: hunt-id }
      (merge hunt { is-active: false })
    )
    
    (ok true)
  )
)

(define-public (emergency-withdraw (hunt-id uint))
  (let
    (
      (hunt (unwrap! (map-get? hunts { hunt-id: hunt-id }) ERR_HUNT_NOT_FOUND))
      (remaining-rewards (* (get final-reward hunt) (- (get max-participants hunt) (get current-participants hunt))))
    )
    (asserts! (is-eq tx-sender (get creator hunt)) ERR_UNAUTHORIZED)
    (asserts! (> stacks-block-height (get end-block hunt)) ERR_HUNT_NOT_EXPIRED)
    
    (if (> remaining-rewards u0)
      (try! (as-contract (ft-transfer? hunt-token remaining-rewards tx-sender (get creator hunt))))
      true
    )
    
    (ok remaining-rewards)
  )
)

(define-public (participate-with-referral
  (hunt-id uint)
  (device-proof-hash (buff 32))
  (location-lat int)
  (location-lng int)
  (referrer principal)
)
  (let
    (
      (hunt (unwrap! (map-get? hunts { hunt-id: hunt-id }) ERR_HUNT_NOT_FOUND))
      (participant-key { hunt-id: hunt-id, participant: tx-sender })
      (leaderboard-meta (default-to { next-rank: u1 } (map-get? hunt-leaderboard-meta { hunt-id: hunt-id })))
      (rank (get next-rank leaderboard-meta))
      (completion-time (- stacks-block-height (get start-block hunt)))
      (referral-bonus (/ (* (get final-reward hunt) REFERRAL_BONUS_PERCENT) u100))
    )
    (asserts! (not (is-eq tx-sender referrer)) ERR_SELF_REFERRAL)
    (asserts! (is-none (map-get? referrals { referee: tx-sender })) ERR_ALREADY_REFERRED)
    (asserts! (get is-active hunt) ERR_HUNT_NOT_ACTIVE)
    (asserts! (>= stacks-block-height (get start-block hunt)) ERR_HUNT_NOT_ACTIVE)
    (asserts! (<= stacks-block-height (get end-block hunt)) ERR_HUNT_EXPIRED)
    (asserts! (is-none (map-get? hunt-participants participant-key)) ERR_ALREADY_CLAIMED)
    (asserts! (< (get current-participants hunt) (get max-participants hunt)) ERR_HUNT_FULL)
    (asserts! (is-within-geofence location-lat location-lng (get center-lat hunt) (get center-lng hunt) (get radius hunt)) ERR_OUT_OF_GEOFENCE)

    (map-set hunt-participants
      participant-key
      {
        claimed-at: stacks-block-height,
        device-proof-hash: device-proof-hash,
        location-lat: location-lat,
        location-lng: location-lng
      }
    )

    (map-set hunts
      { hunt-id: hunt-id }
      (merge hunt { current-participants: (+ (get current-participants hunt) u1) })
    )

    (map-set hunt-leaderboard
      { hunt-id: hunt-id, rank: rank }
      {
        participant: tx-sender,
        completion-time: completion-time,
        reward-earned: (get final-reward hunt)
      }
    )

    (map-set hunt-leaderboard-meta
      { hunt-id: hunt-id }
      { next-rank: (+ rank u1) }
    )

    (map-set referrals
      { referee: tx-sender }
      {
        referrer: referrer,
        hunt-id: hunt-id,
        bonus-paid: referral-bonus,
        referred-at: stacks-block-height
      }
    )

    (update-referrer-stats referrer referral-bonus)

    (try! (as-contract (ft-transfer? hunt-token (get final-reward hunt) tx-sender tx-sender)))
    (try! (ft-mint? hunt-token referral-bonus (as-contract tx-sender)))
    (try! (as-contract (ft-transfer? hunt-token referral-bonus tx-sender referrer)))

    (update-user-stats tx-sender (get final-reward hunt))
    (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) (get final-reward hunt)))
    (var-set total-referral-bonuses (+ (var-get total-referral-bonuses) referral-bonus))

    (ok true)
  )
)

(define-private (is-within-geofence (lat int) (lng int) (center-lat int) (center-lng int) (radius uint))
  (let
    (
      (lat-diff (if (>= lat center-lat) (- lat center-lat) (- center-lat lat)))
      (lng-diff (if (>= lng center-lng) (- lng center-lng) (- center-lng lng)))
      (distance-squared (+ (* lat-diff lat-diff) (* lng-diff lng-diff)))
      (radius-squared (* (to-int radius) (to-int radius)))
    )
    (<= distance-squared radius-squared)
  )
)

(define-private (calculate-hunt-difficulty (duration-blocks uint) (radius uint))
  (let
    (
      (time-factor (calculate-time-pressure duration-blocks))
      (location-factor (calculate-location-remoteness radius))
    )
    (+ time-factor location-factor)
  )
)

(define-private (calculate-time-pressure (duration-blocks uint))
  (if (<= duration-blocks u144)
    u150
    (if (<= duration-blocks u1008)
      u100
      u75
    )
  )
)

(define-private (calculate-location-remoteness (radius uint))
  (if (<= radius u100)
    u125
    (if (<= radius u500)
      u100
      u75
    )
  )
)

(define-private (calculate-reward-multiplier (difficulty-score uint))
  (let
    (
      (base-multiplier DIFFICULTY_BASE_MULTIPLIER)
      (difficulty-bonus (/ (* difficulty-score u50) u100))
    )
    (if (> (+ base-multiplier difficulty-bonus) MAX_DIFFICULTY_MULTIPLIER)
      MAX_DIFFICULTY_MULTIPLIER
      (if (< (+ base-multiplier difficulty-bonus) MIN_DIFFICULTY_MULTIPLIER)
        MIN_DIFFICULTY_MULTIPLIER
        (+ base-multiplier difficulty-bonus)
      )
    )
  )
)

(define-private (update-referrer-stats (referrer principal) (bonus uint))
  (let
    (
      (current-stats (default-to 
        { total-referrals: u0, total-bonus-earned: u0 }
        (map-get? referrer-stats { referrer: referrer })
      ))
    )
    (map-set referrer-stats
      { referrer: referrer }
      {
        total-referrals: (+ (get total-referrals current-stats) u1),
        total-bonus-earned: (+ (get total-bonus-earned current-stats) bonus)
      }
    )
  )
)

(define-private (update-user-stats (user principal) (reward uint))
  (let
    (
      (current-stats (default-to 
        { hunts-completed: u0, total-rewards-earned: u0, last-hunt-block: u0 }
        (map-get? user-stats { user: user })
      ))
    )
    (map-set user-stats
      { user: user }
      {
        hunts-completed: (+ (get hunts-completed current-stats) u1),
        total-rewards-earned: (+ (get total-rewards-earned current-stats) reward),
        last-hunt-block: stacks-block-height
      }
    )
  )
)

(define-read-only (get-hunt (hunt-id uint))
  (map-get? hunts { hunt-id: hunt-id })
)

(define-read-only (get-hunt-participation (hunt-id uint) (participant principal))
  (map-get? hunt-participants { hunt-id: hunt-id, participant: participant })
)

(define-read-only (get-user-stats (user principal))
  (map-get? user-stats { user: user })
)

(define-read-only (get-active-hunts-count)
  (var-get total-hunts-created)
)

(define-read-only (get-total-rewards-distributed)
  (var-get total-rewards-distributed)
)

(define-read-only (is-hunt-active (hunt-id uint))
  (match (map-get? hunts { hunt-id: hunt-id })
    hunt (and 
      (get is-active hunt)
      (>= stacks-block-height (get start-block hunt))
      (<= stacks-block-height (get end-block hunt))
    )
    false
  )
)

(define-read-only (get-hunt-status (hunt-id uint))
  (match (map-get? hunts { hunt-id: hunt-id })
    hunt (some {
      is-active: (get is-active hunt),
      participants: (get current-participants hunt),
      max-participants: (get max-participants hunt),
      blocks-remaining: (if (> (get end-block hunt) stacks-block-height) 
        (- (get end-block hunt) stacks-block-height) 
        u0
      ),
      has-started: (>= stacks-block-height (get start-block hunt))
    })
    none
  )
)

(define-read-only (get-hunt-difficulty (hunt-id uint))
  (map-get? hunt-difficulty-metrics { hunt-id: hunt-id })
)

(define-read-only (get-hunt-leaderboard-entry (hunt-id uint) (rank uint))
  (map-get? hunt-leaderboard { hunt-id: hunt-id, rank: rank })
)

(define-read-only (get-difficulty-multiplier (duration-blocks uint) (radius uint))
  (let
    (
      (difficulty-score (calculate-hunt-difficulty duration-blocks radius))
    )
    (calculate-reward-multiplier difficulty-score)
  )
)

(define-read-only (get-final-reward-preview (base-reward uint) (duration-blocks uint) (radius uint))
  (let
    (
      (difficulty-score (calculate-hunt-difficulty duration-blocks radius))
      (multiplier (calculate-reward-multiplier difficulty-score))
    )
    (/ (* base-reward multiplier) DIFFICULTY_BASE_MULTIPLIER)
  )
)

(define-read-only (can-participate (hunt-id uint) (user principal))
  (match (map-get? hunts { hunt-id: hunt-id })
    hunt (and
      (get is-active hunt)
      (>= stacks-block-height (get start-block hunt))
      (<= stacks-block-height (get end-block hunt))
      (< (get current-participants hunt) (get max-participants hunt))
      (is-none (map-get? hunt-participants { hunt-id: hunt-id, participant: user }))
    )
    false
  )
)

(define-read-only (get-referral-info (referee principal))
  (map-get? referrals { referee: referee })
)

(define-read-only (get-referrer-stats (referrer principal))
  (map-get? referrer-stats { referrer: referrer })
)

(define-read-only (get-total-referral-bonuses)
  (var-get total-referral-bonuses)
)

(define-read-only (calculate-referral-bonus (hunt-id uint))
  (match (map-get? hunts { hunt-id: hunt-id })
    hunt (some (/ (* (get final-reward hunt) REFERRAL_BONUS_PERCENT) u100))
    none
  )
)
