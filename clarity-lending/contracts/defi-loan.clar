;; P2P Lending Platform

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACCESS u1)
(define-constant ERR-INVALID-LOAN-AMOUNT u2)
(define-constant ERR-INSUFFICIENT-USER-BALANCE u3)
(define-constant ERR-LOAN-RECORD-NOT-FOUND u4)
(define-constant ERR-LOAN-ALREADY-FUNDED-ERROR u5)
(define-constant ERR-LOAN-NOT-FUNDED-ERROR u6)
(define-constant ERR-LOAN-IN-DEFAULT-STATE u7)
(define-constant ERR-INVALID-LOAN-PARAMETERS u8)
(define-constant ERR-LOAN-REPAYMENT-NOT-DUE u9)
(define-constant ERR-INSUFFICIENT-COLLATERAL u10)
(define-constant ERR-INVALID-INTEREST-RATE u11)
(define-constant ERR-REFINANCE-NOT-ALLOWED u12)
(define-constant ERR-INVALID-REPAYMENT-AMOUNT u13)
(define-constant ERR-OVERFLOW u14)

;; Data structures
(define-map loan-registry
  { loan-identifier: uint }
  {
    borrower-address: principal,
    lender-address: (optional principal),
    principal-amount: uint,
    collateral-stx-amount: uint,
    yearly-interest-rate-percentage: uint,
    loan-term-blocks: uint,
    loan-start-block: (optional uint),
    loan-current-status: (string-ascii 20),
    cumulative-repaid-amount: uint
  }
)

(define-map user-stx-account-balances principal uint)
(define-map creditworthiness-interest-rates (string-ascii 20) uint)

(define-data-var loan-counter uint u1)

;; Initialize interest rates
(map-set creditworthiness-interest-rates "LOW" u5)
(map-set creditworthiness-interest-rates "MEDIUM" u10)
(map-set creditworthiness-interest-rates "HIGH" u15)

;; Read-only functions
(define-read-only (get-loan-information (loan-identifier uint))
  (map-get? loan-registry { loan-identifier: loan-identifier })
)

(define-read-only (get-user-stx-balance (user-wallet-address principal))
  (default-to u0 (map-get? user-stx-account-balances user-wallet-address))
)

(define-read-only (get-interest-rate-by-risk (creditworthiness-level (string-ascii 20)))
  (default-to u0 (map-get? creditworthiness-interest-rates creditworthiness-level))
)

(define-read-only (calculate-total-repayment-amount (loan-identifier uint))
  (let (
    (loan-details (unwrap! (get-loan-information loan-identifier) (err ERR-LOAN-RECORD-NOT-FOUND)))
    (loan-principal (get principal-amount loan-details))
    (interest-rate (get yearly-interest-rate-percentage loan-details))
    (loan-duration (get loan-term-blocks loan-details))
  )
  (ok (+ loan-principal (/ (* loan-principal interest-rate loan-duration) (* u100 u144 u365))))
  )
)

;; Public functions
(define-public (request-loan (loan-amount uint) (collateral-stx uint) (creditworthiness-level (string-ascii 20)) (term-length-blocks uint))
  (let (
    (loan-identifier (var-get loan-counter))
    (risk-based-interest-rate (unwrap! (map-get? creditworthiness-interest-rates creditworthiness-level) (err ERR-INVALID-INTEREST-RATE)))
  )
    ;; Input validation
    (asserts! (> loan-amount u0) (err ERR-INVALID-LOAN-AMOUNT))
    (asserts! (>= collateral-stx loan-amount) (err ERR-INSUFFICIENT-COLLATERAL))
    (asserts! (> term-length-blocks u0) (err ERR-INVALID-LOAN-PARAMETERS))
    (asserts! (and (>= risk-based-interest-rate u1) (<= risk-based-interest-rate u100)) (err ERR-INVALID-INTEREST-RATE))
    
    ;; Transfer collateral to contract
    (try! (stx-transfer? collateral-stx tx-sender (as-contract tx-sender)))
    
    ;; Create loan record
    (map-set loan-registry
      { loan-identifier: loan-identifier }
      {
        borrower-address: tx-sender,
        lender-address: none,
        principal-amount: loan-amount,
        collateral-stx-amount: collateral-stx,
        yearly-interest-rate-percentage: risk-based-interest-rate,
        loan-term-blocks: term-length-blocks,
        loan-start-block: none,
        loan-current-status: "OPEN",
        cumulative-repaid-amount: u0
      }
    )
    
    ;; Increment loan counter
    (var-set loan-counter (+ loan-identifier u1))
    (ok loan-identifier)
  )
)

(define-public (fund-loan (loan-identifier uint))
  (let (
    (loan-details (unwrap! (get-loan-information loan-identifier) (err ERR-LOAN-RECORD-NOT-FOUND)))
    (principal-amount (get principal-amount loan-details))
  )
    ;; Validate loan status
    (asserts! (is-eq (get loan-current-status loan-details) "OPEN") (err ERR-LOAN-ALREADY-FUNDED-ERROR))
    
    ;; Transfer funds to borrower
    (try! (stx-transfer? principal-amount tx-sender (get borrower-address loan-details)))
    
    ;; Update loan record
    (map-set loan-registry
      { loan-identifier: loan-identifier }
      (merge loan-details {
        lender-address: (some tx-sender),
        loan-start-block: (some block-height),
        loan-current-status: "ACTIVE"
      })
    )
    (ok true)
  )
)

(define-public (submit-loan-payment (loan-identifier uint) (payment-amount uint))
  (let (
    (loan-details (unwrap! (get-loan-information loan-identifier) (err ERR-LOAN-RECORD-NOT-FOUND)))
    (total-debt-amount (unwrap! (calculate-total-repayment-amount loan-identifier) (err ERR-INVALID-LOAN-AMOUNT)))
    (previous-payments (get cumulative-repaid-amount loan-details))
  )
    ;; Validate loan status and payment amount
    (asserts! (is-eq (get loan-current-status loan-details) "ACTIVE") (err ERR-LOAN-NOT-FUNDED-ERROR))
    (asserts! (is-eq tx-sender (get borrower-address loan-details)) (err ERR-UNAUTHORIZED-ACCESS))
    (asserts! (<= (+ previous-payments payment-amount) total-debt-amount) (err ERR-INVALID-REPAYMENT-AMOUNT))
    
    ;; Transfer payment to lender
    (try! (stx-transfer? payment-amount tx-sender (unwrap! (get lender-address loan-details) (err ERR-LOAN-NOT-FUNDED-ERROR))))
    
    ;; Update loan record
    (map-set loan-registry
      { loan-identifier: loan-identifier }
      (merge loan-details {
        cumulative-repaid-amount: (+ previous-payments payment-amount),
        loan-current-status: (if (>= (+ previous-payments payment-amount) total-debt-amount) "REPAID" "ACTIVE")
      })
    )
    
    ;; Return collateral if loan is fully repaid
    (if (>= (+ previous-payments payment-amount) total-debt-amount)
      (try! (as-contract (stx-transfer? (get collateral-stx-amount loan-details) tx-sender (get borrower-address loan-details))))
      true
    )
    
    (ok true)
  )
)

(define-public (liquidate-defaulted-loan (loan-identifier uint))
  (let (
    (loan-details (unwrap! (get-loan-information loan-identifier) (err ERR-LOAN-RECORD-NOT-FOUND)))
    (loan-origination-block (unwrap! (get loan-start-block loan-details) (err ERR-LOAN-NOT-FUNDED-ERROR)))
    (loan-maturity-block (+ loan-origination-block (get loan-term-blocks loan-details)))
  )
    ;; Validate loan status and conditions
    (asserts! (is-eq (get loan-current-status loan-details) "ACTIVE") (err ERR-LOAN-NOT-FUNDED-ERROR))
    (asserts! (>= block-height loan-maturity-block) (err ERR-LOAN-REPAYMENT-NOT-DUE))
    (asserts! (is-eq tx-sender (unwrap! (get lender-address loan-details) (err ERR-UNAUTHORIZED-ACCESS))) (err ERR-UNAUTHORIZED-ACCESS))
    
    ;; Transfer collateral to lender
    (try! (as-contract (stx-transfer? (get collateral-stx-amount loan-details) tx-sender (unwrap! (get lender-address loan-details) (err ERR-LOAN-NOT-FUNDED-ERROR)))))
    
    ;; Update loan status
    (map-set loan-registry
      { loan-identifier: loan-identifier }
      (merge loan-details { loan-current-status: "DEFAULTED" })
    )
    (ok true)
  )
)

(define-public (update-loan-terms (loan-identifier uint) (new-creditworthiness-level (string-ascii 20)) (additional-term-blocks uint))
  (let (
    (loan-details (unwrap! (get-loan-information loan-identifier) (err ERR-LOAN-RECORD-NOT-FOUND)))
    (new-interest-rate (unwrap! (map-get? creditworthiness-interest-rates new-creditworthiness-level) (err ERR-INVALID-INTEREST-RATE)))
  )
    ;; Validate loan status and conditions
    (asserts! (is-eq (get loan-current-status loan-details) "ACTIVE") (err ERR-LOAN-NOT-FUNDED-ERROR))
    (asserts! (is-eq tx-sender (get borrower-address loan-details)) (err ERR-UNAUTHORIZED-ACCESS))
    (asserts! (< new-interest-rate (get yearly-interest-rate-percentage loan-details)) (err ERR-REFINANCE-NOT-ALLOWED))
    (asserts! (and (>= new-interest-rate u1) (<= new-interest-rate u100)) (err ERR-INVALID-INTEREST-RATE))
    
    ;; Update loan record
    (map-set loan-registry
      { loan-identifier: loan-identifier }
      (merge loan-details {
        yearly-interest-rate-percentage: new-interest-rate,
        loan-term-blocks: (+ additional-term-blocks (- (get loan-term-blocks loan-details) (- block-height (unwrap! (get loan-start-block loan-details) (err ERR-LOAN-NOT-FUNDED-ERROR)))))
      })
    )
    (ok true)
  )
)

;; Utility functions
(define-public (deposit-stx (deposit-amount uint))
  (let (
    (current-stx-balance (get-user-stx-balance tx-sender))
  )
    (try! (stx-transfer? deposit-amount tx-sender (as-contract tx-sender)))
    ;; Check for potential overflow before updating the balance
    (asserts! (< (+ current-stx-balance deposit-amount) u340282366920938463463374607431768211455) (err ERR-OVERFLOW))
    (ok (map-set user-stx-account-balances tx-sender (+ current-stx-balance deposit-amount)))
  )
)

(define-public (withdraw-stx (withdrawal-amount uint))
  (let (
    (current-stx-balance (get-user-stx-balance tx-sender))
  )
    (asserts! (<= withdrawal-amount current-stx-balance) (err ERR-INSUFFICIENT-USER-BALANCE))
    
    (try! (as-contract (stx-transfer? withdrawal-amount tx-sender tx-sender)))
    (ok (map-set user-stx-account-balances tx-sender (- current-stx-balance withdrawal-amount)))
  )
)