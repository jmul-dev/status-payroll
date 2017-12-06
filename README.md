# Status Payroll Contract

## PayrollInterface Changes

#### addEmployee
1. Added extra parameter uint256[] distribution to specify the percentage of each allowed tokens the employee wishes to accept as payments.
2. Added employeeId as return value for convenience.


#### getEmployee
1. In addition to employee address, I also included allowed tokens, token distribution, employee's yearly EUR salary, token distribution last updated timestamp, and last payday timestamp as return values.


## Additional Methods

#### addPayrollAllowedToken
⋅⋅⋅Owner only function to whitelist token contract address that payroll can use to pay the employees.

#### pauseContract
⋅⋅⋅Owner only function to pause contract when necessary.

#### changeOwner
⋅⋅⋅Owner only function to switch owner address.

#### changeOracle
⋅⋅⋅Owner only function to switch oracle address.

#### _addMonths
⋅⋅⋅Private function that will take a timestamp and add it by a number of months.

## Helper Libraries/Interfaces

#### SafeMath.sol
⋅⋅⋅A library to do math operations with safety checks [https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/math/SafeMath.sol](https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/math/SafeMath.sol)

#### DateTime.sol
⋅⋅⋅Contract which implements utilities for working with datetime values in ethereum [https://github.com/pipermerriam/ethereum-datetime/blob/master/contracts/DateTime.sol](https://github.com/pipermerriam/ethereum-datetime/blob/master/contracts/DateTime.sol)

#### AdvancedTokenERC20.sol, tokenRecipient.sol
⋅⋅⋅Standard ERC20 Token contract with approveAndCall() [https://www.ethereum.org/token](https://www.ethereum.org/token)
