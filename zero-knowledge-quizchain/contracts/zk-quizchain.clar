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