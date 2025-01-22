# P2P Lending Smart Contract

A decentralized peer-to-peer lending platform built on Stacks blockchain that enables users to request loans, provide collateral, fund loans, and manage loan repayments.

## Features

- Loan request and funding system
- Risk-based interest rates
- Collateral management
- Loan repayment tracking
- Loan term modifications
- Default handling and liquidation
- STX deposit and withdrawal functionality

## Contract Overview

### Core Functionality

1. **Loan Creation**
   - Borrowers can request loans by providing collateral
   - Risk-based interest rates (LOW: 5%, MEDIUM: 10%, HIGH: 15%)
   - Customizable loan duration

2. **Loan Funding**
   - Lenders can fund open loan requests
   - Automatic transfer of funds to borrower
   - Loan status tracking

3. **Repayment System**
   - Flexible repayment amounts
   - Automatic collateral return upon full repayment
   - Interest calculation based on duration and risk level

4. **Loan Management**
   - Loan term modifications
   - Risk level adjustments
   - Default handling and liquidation

### Error Codes

```clarity
ERR-UNAUTHORIZED-ACCESS (u1): User is not authorized to perform the action
ERR-INVALID-LOAN-AMOUNT (u2): Loan amount is invalid
ERR-INSUFFICIENT-USER-BALANCE (u3): User has insufficient balance
ERR-LOAN-RECORD-NOT-FOUND (u4): Loan record does not exist
ERR-LOAN-ALREADY-FUNDED-ERROR (u5): Loan is already funded
ERR-LOAN-NOT-FUNDED-ERROR (u6): Loan is not in funded state
ERR-LOAN-IN-DEFAULT-STATE (u7): Loan is in default state
ERR-INVALID-LOAN-PARAMETERS (u8): Invalid loan parameters provided
ERR-LOAN-REPAYMENT-NOT-DUE (u9): Loan repayment is not due yet
ERR-INSUFFICIENT-COLLATERAL (u10): Insufficient collateral provided
ERR-INVALID-INTEREST-RATE (u11): Invalid interest rate
ERR-REFINANCE-NOT-ALLOWED (u12): Refinancing not allowed
ERR-INVALID-REPAYMENT-AMOUNT (u13): Invalid repayment amount
ERR-OVERFLOW (u14): Numeric overflow error
```

## Usage Guide

### For Borrowers

1. **Requesting a Loan**
```clarity
(request-loan loan-amount collateral-stx creditworthiness-level term-length-blocks)
```
- `loan-amount`: Amount of STX requested
- `collateral-stx`: Amount of STX provided as collateral
- `creditworthiness-level`: "LOW", "MEDIUM", or "HIGH"
- `term-length-blocks`: Loan duration in blocks

2. **Making Repayments**
```clarity
(submit-loan-payment loan-identifier payment-amount)
```

3. **Updating Loan Terms**
```clarity
(update-loan-terms loan-identifier new-creditworthiness-level additional-term-blocks)
```

### For Lenders

1. **Funding a Loan**
```clarity
(fund-loan loan-identifier)
```

2. **Liquidating Defaulted Loans**
```clarity
(liquidate-defaulted-loan loan-identifier)
```

### General Functions

1. **Depositing STX**
```clarity
(deposit-stx deposit-amount)
```

2. **Withdrawing STX**
```clarity
(withdraw-stx withdrawal-amount)
```

3. **Viewing Loan Information**
```clarity
(get-loan-information loan-identifier)
```

## Loan States

- `OPEN`: Initial state when loan is created
- `ACTIVE`: Loan has been funded and is currently active
- `REPAID`: Loan has been fully repaid
- `DEFAULTED`: Loan has defaulted and been liquidated

## Security Considerations

1. **Collateral Requirements**
   - Collateral must be greater than or equal to loan amount
   - Collateral is locked in contract until loan is repaid or liquidated

2. **Access Control**
   - Only borrower can make repayments
   - Only lender can liquidate defaulted loans
   - Only borrower can modify loan terms

3. **Validation Checks**
   - Interest rate bounds (1% to 100%)
   - Overflow protection for balances
   - Valid loan parameters verification

## Best Practices

1. **For Borrowers**
   - Ensure sufficient collateral is provided
   - Make repayments before loan maturity
   - Monitor loan status regularly

2. **For Lenders**
   - Verify loan terms and collateral before funding
   - Monitor loan repayment status
   - Act promptly on defaulted loans

## Technical Details

- Built for Stacks blockchain
- Uses STX as the primary currency
- Interest calculations account for yearly rates and block times
- Implements proper error handling and status tracking