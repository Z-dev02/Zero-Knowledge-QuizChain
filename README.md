# Zero-Knowledge QuizChain

A decentralized system on Stacks blockchain for testing AI knowledge and skills through quizzes, with results verified and certified on-chain using zero-knowledge proofs for privacy and fairness.

## Features

- Create AI knowledge assessment quizzes
- Zero-knowledge proof submission for privacy
- Automated certification upon passing
- Attempt history tracking
- Certification verification and revocation

## Smart Contract Functions

### Public Functions

- `create-quiz` - Create quiz with passing score and question count
- `submit-quiz-attempt` - Submit attempt with ZK proof hash and score
- `verify-attempt` - Quiz creator verifies ZK proof and issues cert
- `revoke-certification` - Revoke certification if needed
- `deactivate-quiz` - Deactivate quiz to prevent new attempts

### Read-Only Functions

- `get-quiz` - Retrieve quiz details by ID
- `get-attempt` - Get attempt details including verification status
- `get-certification` - Check if participant is certified
- `get-participant-attempts` - List all attempts by participant
- `get-next-quiz-id` - Get next available quiz ID

## Usage

Organizations create AI skill assessments. Participants submit quiz attempts with zero-knowledge proofs to maintain privacy. Upon verification, passing participants receive on-chain certifications that can be verified by third parties.