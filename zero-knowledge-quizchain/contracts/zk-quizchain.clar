;; Zero-Knowledge QuizChain
;; AI knowledge testing with on-chain certification using ZK proofs

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u700))
(define-constant err-not-found (err u701))
(define-constant err-not-authorized (err u702))
(define-constant err-already-attempted (err u703))
(define-constant err-invalid-score (err u704))
(define-constant err-insufficient-balance (err u705))
(define-constant err-quiz-inactive (err u706))
(define-constant err-invalid-difficulty (err u707))
(define-constant err-invalid-category (err u708))
(define-constant err-already-rated (err u709))

;; Difficulty levels
(define-constant difficulty-beginner u1)
(define-constant difficulty-intermediate u2)
(define-constant difficulty-advanced u3)
(define-constant difficulty-expert u4)

;; Data Variables
(define-data-var quiz-id-nonce uint u0)
(define-data-var attempt-id-nonce uint u0)
(define-data-var total-participants uint u0)
(define-data-var total-certifications uint u0)
(define-data-var platform-fee uint u100000) ;; 0.1 STX in microstacks

;; Data Maps
(define-map quizzes
    uint
    {
        creator: principal,
        title: (string-ascii 100),
        description: (string-ascii 300),
        quiz-hash: (buff 32),
        passing-score: uint,
        total-questions: uint,
        active: bool,
        difficulty: uint,
        category: (string-ascii 50),
        reward-pool: uint,
        total-attempts: uint,
        average-score: uint
    }
)

(define-map quiz-attempts
    uint
    {
        quiz-id: uint,
        participant: principal,
        proof-hash: (buff 32),
        score: uint,
        passed: bool,
        timestamp: uint,
        verified: bool
    }
)

(define-map participant-attempts
    {quiz-id: uint, participant: principal}
    (list 10 uint)
)

(define-map certifications
    {quiz-id: uint, participant: principal}
    {
        attempt-id: uint,
        certified: bool,
        cert-date: uint
    }
)

(define-map quiz-ratings
    {quiz-id: uint, participant: principal}
    {
        rating: uint,
        feedback: (string-ascii 200)
    }
)

(define-map participant-stats
    principal
    {
        total-attempts: uint,
        total-passed: uint,
        total-certifications: uint,
        total-rewards: uint,
        reputation-score: uint
    }
)

(define-map leaderboard
    {quiz-id: uint, rank: uint}
    {
        participant: principal,
        score: uint,
        timestamp: uint
    }
)

(define-map quiz-categories
    (string-ascii 50)
    {
        total-quizzes: uint,
        total-participants: uint,
        active: bool
    }
)

;; Read-only functions
(define-read-only (get-quiz (quiz-id uint))
    (map-get? quizzes quiz-id)
)

(define-read-only (get-attempt (attempt-id uint))
    (map-get? quiz-attempts attempt-id)
)

(define-read-only (get-certification (quiz-id uint) (participant principal))
    (map-get? certifications {quiz-id: quiz-id, participant: participant})
)

(define-read-only (get-participant-attempts (quiz-id uint) (participant principal))
    (default-to (list) (map-get? participant-attempts {quiz-id: quiz-id, participant: participant}))
)

(define-read-only (get-next-quiz-id)
    (var-get quiz-id-nonce)
)

(define-read-only (get-participant-stats (participant principal))
    (map-get? participant-stats participant)
)

(define-read-only (get-quiz-rating (quiz-id uint) (participant principal))
    (map-get? quiz-ratings {quiz-id: quiz-id, participant: participant})
)

(define-read-only (get-leaderboard-entry (quiz-id uint) (rank uint))
    (map-get? leaderboard {quiz-id: quiz-id, rank: rank})
)

(define-read-only (get-category-stats (category (string-ascii 50)))
    (map-get? quiz-categories category)
)

(define-read-only (get-platform-fee)
    (ok (var-get platform-fee))
)

(define-read-only (get-total-participants)
    (ok (var-get total-participants))
)

(define-read-only (get-total-certifications)
    (ok (var-get total-certifications))
)

(define-read-only (is-quiz-creator (quiz-id uint) (user principal))
    (match (map-get? quizzes quiz-id)
        quiz (ok (is-eq user (get creator quiz)))
        (ok false)
    )
)

(define-read-only (has-certification (quiz-id uint) (participant principal))
    (match (map-get? certifications {quiz-id: quiz-id, participant: participant})
        cert (ok (get certified cert))
        (ok false)
    )
)

;; Public functions
;; #[allow(unchecked_data)]
(define-public (create-quiz 
    (title (string-ascii 100))
    (description (string-ascii 300))
    (quiz-hash (buff 32))
    (passing-score uint)
    (total-questions uint)
    (difficulty uint)
    (category (string-ascii 50)))
    (let
        ((new-id (var-get quiz-id-nonce)))
        (asserts! (<= passing-score u100) err-invalid-score)
        (asserts! (and (>= difficulty difficulty-beginner) (<= difficulty difficulty-expert)) err-invalid-difficulty)
        (map-set quizzes new-id
            {
                creator: tx-sender,
                title: title,
                description: description,
                quiz-hash: quiz-hash,
                passing-score: passing-score,
                total-questions: total-questions,
                active: true,
                difficulty: difficulty,
                category: category,
                reward-pool: u0,
                total-attempts: u0,
                average-score: u0
            }
        )
        ;; Update category stats
        (match (map-get? quiz-categories category)
            cat-stats (map-set quiz-categories category 
                (merge cat-stats {total-quizzes: (+ (get total-quizzes cat-stats) u1)}))
            (map-set quiz-categories category {total-quizzes: u1, total-participants: u0, active: true})
        )
        (var-set quiz-id-nonce (+ new-id u1))
        (ok new-id)
    )
)

;; #[allow(unchecked_data)]
(define-public (submit-quiz-attempt (quiz-id uint) (proof-hash (buff 32)) (score uint))
    (let
        ((quiz (unwrap! (map-get? quizzes quiz-id) err-not-found))
         (new-attempt-id (var-get attempt-id-nonce))
         (attempts (get-participant-attempts quiz-id tx-sender))
         (passed (>= score (get passing-score quiz)))
         (current-stats (default-to {total-attempts: u0, total-passed: u0, total-certifications: u0, total-rewards: u0, reputation-score: u0}
                                    (map-get? participant-stats tx-sender)))
         (total-att (get total-attempts quiz))
         (avg-score (get average-score quiz))
         (new-avg (/ (+ (* avg-score total-att) score) (+ total-att u1))))
        (asserts! (get active quiz) err-quiz-inactive)
        (asserts! (<= score u100) err-invalid-score)
        
        ;; Record attempt
        (map-set quiz-attempts new-attempt-id
            {
                quiz-id: quiz-id,
                participant: tx-sender,
                proof-hash: proof-hash,
                score: score,
                passed: passed,
                timestamp: stacks-block-height,
                verified: false
            }
        )
        
        ;; Update participant attempts
        (map-set participant-attempts 
            {quiz-id: quiz-id, participant: tx-sender}
            (unwrap-panic (as-max-len? (append attempts new-attempt-id) u10))
        )
        
        ;; Update quiz stats
        (map-set quizzes quiz-id (merge quiz {
            total-attempts: (+ total-att u1),
            average-score: new-avg
        }))
        
        ;; Update participant stats
        (map-set participant-stats tx-sender (merge current-stats {
            total-attempts: (+ (get total-attempts current-stats) u1),
            total-passed: (if passed (+ (get total-passed current-stats) u1) (get total-passed current-stats))
        }))
        
        (var-set attempt-id-nonce (+ new-attempt-id u1))
        (ok new-attempt-id)
    )
)

;; #[allow(unchecked_data)]
(define-public (verify-attempt (attempt-id uint))
    (let
        ((attempt (unwrap! (map-get? quiz-attempts attempt-id) err-not-found))
         (quiz (unwrap! (map-get? quizzes (get quiz-id attempt)) err-not-found))
         (participant (get participant attempt))
         (current-stats (default-to {total-attempts: u0, total-passed: u0, total-certifications: u0, total-rewards: u0, reputation-score: u0}
                                    (map-get? participant-stats participant))))
        (asserts! (is-eq tx-sender (get creator quiz)) err-not-authorized)
        (map-set quiz-attempts attempt-id (merge attempt {verified: true}))
        (if (get passed attempt)
            (begin
                (map-set certifications 
                    {quiz-id: (get quiz-id attempt), participant: participant}
                    {
                        attempt-id: attempt-id,
                        certified: true,
                        cert-date: stacks-block-height
                    }
                )
                ;; Update participant stats
                (map-set participant-stats participant (merge current-stats {
                    total-certifications: (+ (get total-certifications current-stats) u1),
                    reputation-score: (+ (get reputation-score current-stats) u10)
                }))
                (var-set total-certifications (+ (var-get total-certifications) u1))
            )
            true
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (rate-quiz (quiz-id uint) (rating uint) (feedback (string-ascii 200)))
    (let
        ((quiz (unwrap! (map-get? quizzes quiz-id) err-not-found)))
        (asserts! (<= rating u5) err-invalid-score)
        (asserts! (is-none (map-get? quiz-ratings {quiz-id: quiz-id, participant: tx-sender})) err-already-rated)
        (map-set quiz-ratings {quiz-id: quiz-id, participant: tx-sender}
            {rating: rating, feedback: feedback})
        (ok true)
    )
)

(define-public (add-reward-to-quiz (quiz-id uint) (amount uint))
    (let
        ((quiz (unwrap! (map-get? quizzes quiz-id) err-not-found)))
        (asserts! (is-eq tx-sender (get creator quiz)) err-not-authorized)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set quizzes quiz-id (merge quiz {reward-pool: (+ (get reward-pool quiz) amount)}))
        (ok true)
    )
)

(define-public (claim-reward (quiz-id uint))
    (let
        ((quiz (unwrap! (map-get? quizzes quiz-id) err-not-found))
         (cert (unwrap! (map-get? certifications {quiz-id: quiz-id, participant: tx-sender}) err-not-found))
         (reward-amount (/ (get reward-pool quiz) u10))
         (current-stats (default-to {total-attempts: u0, total-passed: u0, total-certifications: u0, total-rewards: u0, reputation-score: u0}
                                    (map-get? participant-stats tx-sender))))
        (asserts! (get certified cert) err-not-authorized)
        (asserts! (> (get reward-pool quiz) u0) err-insufficient-balance)
        (try! (as-contract (stx-transfer? reward-amount tx-sender (get participant (unwrap-panic (map-get? quiz-attempts (get attempt-id cert)))))))
        (map-set quizzes quiz-id (merge quiz {reward-pool: (- (get reward-pool quiz) reward-amount)}))
        (map-set participant-stats tx-sender (merge current-stats {
            total-rewards: (+ (get total-rewards current-stats) reward-amount)
        }))
        (ok reward-amount)
    )
)

;; #[allow(unchecked_data)]
(define-public (update-leaderboard (quiz-id uint) (rank uint) (participant principal) (score uint))
    (let
        ((quiz (unwrap! (map-get? quizzes quiz-id) err-not-found)))
        (asserts! (is-eq tx-sender (get creator quiz)) err-not-authorized)
        (map-set leaderboard {quiz-id: quiz-id, rank: rank}
            {participant: participant, score: score, timestamp: stacks-block-height})
        (ok true)
    )
)

(define-public (activate-quiz (quiz-id uint))
    (let
        ((quiz (unwrap! (map-get? quizzes quiz-id) err-not-found)))
        (asserts! (is-eq tx-sender (get creator quiz)) err-not-authorized)
        (map-set quizzes quiz-id (merge quiz {active: true}))
        (ok true)
    )
)

(define-public (update-quiz-description (quiz-id uint) (new-description (string-ascii 300)))
    (let
        ((quiz (unwrap! (map-get? quizzes quiz-id) err-not-found)))
        (asserts! (is-eq tx-sender (get creator quiz)) err-not-authorized)
        (map-set quizzes quiz-id (merge quiz {description: new-description}))
        (ok true)
    )
)

(define-public (update-passing-score (quiz-id uint) (new-score uint))
    (let
        ((quiz (unwrap! (map-get? quizzes quiz-id) err-not-found)))
        (asserts! (is-eq tx-sender (get creator quiz)) err-not-authorized)
        (asserts! (<= new-score u100) err-invalid-score)
        (map-set quizzes quiz-id (merge quiz {passing-score: new-score}))
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (set-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set platform-fee new-fee)
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (toggle-category (category (string-ascii 50)) (active bool))
    (let
        ((cat-stats (unwrap! (map-get? quiz-categories category) err-not-found)))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set quiz-categories category (merge cat-stats {active: active}))
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (revoke-certification (quiz-id uint) (participant principal))
    (let
        ((quiz (unwrap! (map-get? quizzes quiz-id) err-not-found))
         (cert (unwrap! (map-get? certifications {quiz-id: quiz-id, participant: participant}) err-not-found)))
        (asserts! (is-eq tx-sender (get creator quiz)) err-not-authorized)
        (map-set certifications {quiz-id: quiz-id, participant: participant}
            (merge cert {certified: false}))
        (ok true)
    )
)

(define-public (deactivate-quiz (quiz-id uint))
    (let
        ((quiz (unwrap! (map-get? quizzes quiz-id) err-not-found)))
        (asserts! (is-eq tx-sender (get creator quiz)) err-not-authorized)
        (map-set quizzes quiz-id (merge quiz {active: false}))
        (ok true)
    )
)