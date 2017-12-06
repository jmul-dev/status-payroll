# Status Payroll Contract

## PayrollInterface Changes

####1. addEmployee(address accountAddress, address[] allowedTokens, uint256[] distribution, uint256 initialYearlyEURSalary) public returns (uint256)
...1. Added extra parameter uint256[] distribution to specify the percentage of each allowed tokens the employee wishes to accept as payments.
...2. Added employeeId as return value for convenience.


####2. getEmployee(uint256 employeeId) public constant returns (address employeeAddress, address[] allowedTokens, uint256[] distribution, uint256 yearlyEURSalary, uint256 lastUpdatedTokenDistributionTimestamp, uint256 lastPaydayTimestamp)
...1. In addition to employee address, I also included allowed tokens, token distribution, employee's yearly EUR salary, token distribution last updated timestamp, and last payday timestamp as return values.


### Additional Methods

#### addPayrollAllowedToken(address tokenAddress, uint256 EURExchangeRate) public onlyOwner contractIsActive
Owner only function to whitelist token contract address that payroll can use to pay the employees.

#### pauseContract(bool _paused) public onlyOwner
Owner only function to pause contract when necessary.

#### changeOwner(address _owner) public onlyOwner
Owner only function to switch owner address.

#### changeOracle(address _oracle) public onlyOwner
Owner only function to switch oracle address.

### _addMonths(uint8 months, uint256 timestamp) private constant returns (uint256)
Private function that will take a timestamp and add it by a number of months.

### Helper Libraries/Interfaces

#### SafeMath.sol
A library to do math operations with safety checks [https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/math/SafeMath.sol](https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/math/SafeMath.sol)

#### DateTime.sol
Contract which implements utilities for working with datetime values in ethereum [https://github.com/pipermerriam/ethereum-datetime/blob/master/contracts/DateTime.sol](https://github.com/pipermerriam/ethereum-datetime/blob/master/contracts/DateTime.sol)

#### AdvancedTokenERC20.sol, tokenRecipient.sol
Standard ERC20 Token contract with approveAndCall() [https://www.ethereum.org/token](https://www.ethereum.org/token)


