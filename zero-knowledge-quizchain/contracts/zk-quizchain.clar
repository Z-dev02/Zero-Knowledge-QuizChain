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