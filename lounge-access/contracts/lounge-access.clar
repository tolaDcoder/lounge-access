;; Airport Lounge Access Smart Contract
;; Manages lounge entry tokens, day passes, upgrade auctions, and frequent flyer miles

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-expired (err u103))
(define-constant err-invalid-bid (err u104))
(define-constant err-auction-ended (err u105))
(define-constant err-unauthorized (err u106))
(define-constant err-already-exists (err u107))

;; Data Variables
(define-data-var pass-counter uint u0)
(define-data-var auction-counter uint u0)
(define-data-var base-pass-price uint u1000000) ;; 1 STX in microSTX

;; Day Pass Structure
(define-map day-passes
    uint
    {
        owner: principal,
        lounge-id: (string-ascii 50),
        valid-until: uint,
        tier: (string-ascii 20),
        transferable: bool
    }
)

;; Frequent Flyer Miles
(define-map flyer-miles
    principal
    {
        miles: uint,
        tier: (string-ascii 20),
        total-visits: uint
    }
)

;; Upgrade Auctions
(define-map upgrade-auctions
    uint
    {
        pass-id: uint,
        from-tier: (string-ascii 20),
        to-tier: (string-ascii 20),
        highest-bidder: (optional principal),
        highest-bid: uint,
        end-block: uint,
        active: bool
    }
)

;; Lounge Registry
(define-map lounges
    (string-ascii 50)
    {
        name: (string-ascii 100),
        location: (string-ascii 100),
        capacity: uint,
        current-occupancy: uint,
        active: bool
    }
)

;; Read-only functions

(define-read-only (get-pass (pass-id uint))
    (map-get? day-passes pass-id)
)

(define-read-only (get-flyer-miles (user principal))
    (default-to 
        {miles: u0, tier: "bronze", total-visits: u0}
        (map-get? flyer-miles user)
    )
)

(define-read-only (get-auction (auction-id uint))
    (map-get? upgrade-auctions auction-id)
)

(define-read-only (get-lounge (lounge-id (string-ascii 50)))
    (map-get? lounges lounge-id)
)

(define-read-only (get-base-price)
    (var-get base-pass-price)
)

(define-read-only (calculate-tier-price (tier (string-ascii 20)))
    (if (is-eq tier "platinum")
        (* (var-get base-pass-price) u3)
        (if (is-eq tier "gold")
            (* (var-get base-pass-price) u2)
            (var-get base-pass-price)
        )
    )
)

;; Public functions

;; Register a new lounge (owner only)
(define-public (register-lounge 
    (lounge-id (string-ascii 50))
    (name (string-ascii 100))
    (location (string-ascii 100))
    (capacity uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-none (map-get? lounges lounge-id)) err-already-exists)
        (ok (map-set lounges lounge-id {
            name: name,
            location: location,
            capacity: capacity,
            current-occupancy: u0,
            active: true
        }))
    )
)

;; Purchase a day pass
(define-public (purchase-pass 
    (lounge-id (string-ascii 50))
    (tier (string-ascii 20))
    (valid-blocks uint))
    (let
        (
            (pass-id (+ (var-get pass-counter) u1))
            (price (calculate-tier-price tier))
        )
        (try! (stx-transfer? price tx-sender contract-owner))
        (map-set day-passes pass-id {
            owner: tx-sender,
            lounge-id: lounge-id,
            valid-until: (+ stacks-block-height valid-blocks),
            tier: tier,
            transferable: true
        })
        (var-set pass-counter pass-id)
        (add-flyer-miles tx-sender u100)
        (ok pass-id)
    )
)

;; Transfer a day pass
(define-public (transfer-pass (pass-id uint) (recipient principal))
    (let
        (
            (pass (unwrap! (map-get? day-passes pass-id) err-not-found))
        )
        (asserts! (is-eq (get owner pass) tx-sender) err-unauthorized)
        (asserts! (get transferable pass) err-unauthorized)
        (asserts! (> (get valid-until pass) stacks-block-height) err-expired)
        (ok (map-set day-passes pass-id 
            (merge pass {owner: recipient})
        ))
    )
)

;; Use a pass to enter lounge
(define-public (enter-lounge (pass-id uint))
    (let
        (
            (pass (unwrap! (map-get? day-passes pass-id) err-not-found))
            (lounge (unwrap! (map-get? lounges (get lounge-id pass)) err-not-found))
        )
        (asserts! (is-eq (get owner pass) tx-sender) err-unauthorized)
        (asserts! (> (get valid-until pass) stacks-block-height) err-expired)
        (asserts! (< (get current-occupancy lounge) (get capacity lounge)) err-insufficient-balance)
        
        ;; Update lounge occupancy
        (map-set lounges (get lounge-id pass) 
            (merge lounge {current-occupancy: (+ (get current-occupancy lounge) u1)})
        )
        
        ;; Add miles and visit count
        (add-flyer-miles tx-sender u50)
        (increment-visits tx-sender)
        (ok true)
    )
)

;; Create upgrade auction
(define-public (create-upgrade-auction 
    (pass-id uint)
    (to-tier (string-ascii 20))
    (starting-bid uint)
    (duration-blocks uint))
    (let
        (
            (pass (unwrap! (map-get? day-passes pass-id) err-not-found))
            (auction-id (+ (var-get auction-counter) u1))
        )
        (asserts! (is-eq (get owner pass) tx-sender) err-unauthorized)
        (asserts! (> (get valid-until pass) stacks-block-height) err-expired)
        
        (map-set upgrade-auctions auction-id {
            pass-id: pass-id,
            from-tier: (get tier pass),
            to-tier: to-tier,
            highest-bidder: none,
            highest-bid: starting-bid,
            end-block: (+ stacks-block-height duration-blocks),
            active: true
        })
        (var-set auction-counter auction-id)
        (ok auction-id)
    )
)

;; Bid on upgrade auction
(define-public (bid-on-upgrade (auction-id uint) (bid-amount uint))
    (let
        (
            (auction (unwrap! (map-get? upgrade-auctions auction-id) err-not-found))
        )
        (asserts! (get active auction) err-auction-ended)
        (asserts! (< stacks-block-height (get end-block auction)) err-auction-ended)
        (asserts! (> bid-amount (get highest-bid auction)) err-invalid-bid)
        
        ;; Refund previous bidder if exists
        (match (get highest-bidder auction)
            prev-bidder (try! (as-contract (stx-transfer? (get highest-bid auction) tx-sender prev-bidder)))
            true
        )
        
        ;; Transfer new bid
        (try! (stx-transfer? bid-amount tx-sender (as-contract tx-sender)))
        
        ;; Update auction
        (ok (map-set upgrade-auctions auction-id 
            (merge auction {
                highest-bidder: (some tx-sender),
                highest-bid: bid-amount
            })
        ))
    )
)

;; Finalize upgrade auction
(define-public (finalize-upgrade (auction-id uint))
    (let
        (
            (auction (unwrap! (map-get? upgrade-auctions auction-id) err-not-found))
            (pass (unwrap! (map-get? day-passes (get pass-id auction)) err-not-found))
            (winner (unwrap! (get highest-bidder auction) err-not-found))
        )
        (asserts! (>= stacks-block-height (get end-block auction)) err-auction-ended)
        (asserts! (get active auction) err-auction-ended)
        
        ;; Transfer funds to pass owner
        (try! (as-contract (stx-transfer? (get highest-bid auction) tx-sender (get owner pass))))
        
        ;; Upgrade the pass
        (map-set day-passes (get pass-id auction)
            (merge pass {
                tier: (get to-tier auction),
                owner: winner
            })
        )
        
        ;; Mark auction as inactive
        (map-set upgrade-auctions auction-id
            (merge auction {active: false})
        )
        (ok true)
    )
)

;; Redeem miles for pass
(define-public (redeem-miles-for-pass 
    (lounge-id (string-ascii 50))
    (miles-to-redeem uint))
    (let
        (
            (flyer-data (get-flyer-miles tx-sender))
            (pass-id (+ (var-get pass-counter) u1))
        )
        (asserts! (>= (get miles flyer-data) miles-to-redeem) err-insufficient-balance)
        (asserts! (>= miles-to-redeem u500) err-invalid-bid)
        
        ;; Deduct miles
        (map-set flyer-miles tx-sender
            (merge flyer-data {miles: (- (get miles flyer-data) miles-to-redeem)})
        )
        
        ;; Create pass
        (map-set day-passes pass-id {
            owner: tx-sender,
            lounge-id: lounge-id,
            valid-until: (+ stacks-block-height u144), ;; ~1 day
            tier: "gold",
            transferable: true
        })
        (var-set pass-counter pass-id)
        (ok pass-id)
    )
)

;; Private functions

(define-private (add-flyer-miles (user principal) (miles uint))
    (let
        (
            (current-data (get-flyer-miles user))
            (new-miles (+ (get miles current-data) miles))
            (new-tier (calculate-tier new-miles))
        )
        (map-set flyer-miles user {
            miles: new-miles,
            tier: new-tier,
            total-visits: (get total-visits current-data)
        })
    )
)

(define-private (increment-visits (user principal))
    (let
        (
            (current-data (get-flyer-miles user))
        )
        (map-set flyer-miles user
            (merge current-data {total-visits: (+ (get total-visits current-data) u1)})
        )
    )
)

(define-private (calculate-tier (miles uint))
    (if (>= miles u5000)
        "platinum"
        (if (>= miles u2000)
            "gold"
            "bronze"
        )
    )
)

;; Admin function to update base price
(define-public (set-base-price (new-price uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (var-set base-pass-price new-price))
    )
)