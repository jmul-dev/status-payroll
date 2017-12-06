pragma solidity ^0.4.18;

import './SafeMath.sol';
import './AdvancedTokenERC20.sol';
import './DateTime.sol';
import './PayrollInterface.sol';

contract Payroll is PayrollInterface, tokenRecipient {
	using SafeMath for uint;

	address public owner;
	address public oracle;
	bool public paused;
	uint256 private totalEmployees;
	uint256 private lastEmployeeId;
	uint256 private totalYearlyEURSalary;
	uint256 private lastAllowedTokenId;
	DateTime internal datetime;

	struct Employee {
		address accountAddress;
		address[] allowedTokens;
		uint256[] distribution;
		uint256 yearlyEURSalary;
		uint256 lastUpdatedTokenDistributionTimestamp;
		uint256 lastPaydayTimestamp;
	}

	struct PayrollAllowedToken {
		address tokenAddress;
		uint256 EURExchangeRate;
	}

	mapping (uint256 => Employee) private allEmployees;
	mapping (address => uint256) private employeeIdLookup;
	mapping (uint256 => PayrollAllowedToken) private allPayrollAllowedTokens;
	mapping (address => uint256) private allowedTokenIdLookup;

	event ReceivedFund(uint256 value);
	event ReceivedToken(address from, uint256 value, address token, bytes extraData);

	/**
	 * @dev Checks only owner address is calling
	 */
	modifier onlyOwner {
		require (msg.sender == owner);
		_;
	}

	/**
	 * @dev Checks only oracle address is calling
	 */
	modifier onlyOracle {
		require (msg.sender == oracle);
		_;
	}

	/**
	 * @dev Checks only employee address is calling
	 */
	modifier onlyEmployee {
		require (employeeIdLookup[msg.sender] > 0);
		_;
	}

	/**
	 * @dev Checks is contract is active
	 */
	modifier contractIsActive {
		require (paused == false);
		_;
	}

	/**
	 * Constructor
	 * @param _oracle The oracle address to be set
	 */
	function Payroll(address _oracle) public {
		owner = msg.sender;
		oracle = _oracle;
		datetime = DateTime(address(0x1a6184CD4C5Bea62B0116de7962EE7315B7bcBce));
	}

	//////////// Owner Only Methods ////////////

	/**
	 * @dev Adds new employee to payroll
	 * @param accountAddress The address of the new employee
	 * @param allowedTokens The list of tokens that the employee wishes to accept as payments
	 * @param distribution The percentage of each tokens the employee wishes to accept
	 * @param initialYearlyEURSalary The starting yearly salary in EUR 
	 * @return The newly added employee ID
	 */
	function addEmployee(address accountAddress, address[] allowedTokens, uint256[] distribution, uint256 initialYearlyEURSalary) public 
		onlyOwner
		contractIsActive 
		returns (uint256) {
			// Make sure we don't add the same account twice
			require (employeeIdLookup[accountAddress] == 0);
			require (initialYearlyEURSalary > 0);
			require (allowedTokens.length == distribution.length);

			uint256 totalDistribution = 0;

			// Check if allowed tokens are in payroll allowed tokens list
			for (uint256 i = 0; i < allowedTokens.length; i++) {
				require (allowedTokenIdLookup[allowedTokens[i]] > 0);
				totalDistribution = totalDistribution.add(distribution[i]);
			}

			// Check if total distribution of allowed tokens is 100%
			require (totalDistribution == 100);

			totalEmployees++;
			lastEmployeeId++;
			employeeIdLookup[accountAddress] = lastEmployeeId;
			allEmployees[lastEmployeeId].accountAddress = accountAddress;
			allEmployees[lastEmployeeId].allowedTokens = allowedTokens;
			allEmployees[lastEmployeeId].yearlyEURSalary = initialYearlyEURSalary;
			totalYearlyEURSalary = totalYearlyEURSalary.add(initialYearlyEURSalary);
			return lastEmployeeId;
		}

	/**
	 * @dev Sets employee new salary
	 * @param employeeId The employee ID to be updated
	 * @param yearlyEURSalary The new salary to be set
	 */
	function setEmployeeSalary(uint256 employeeId, uint256 yearlyEURSalary) public onlyOwner contractIsActive {
		// Check if employee exists
		require (allEmployees[employeeId].accountAddress != address(0));
		require (yearlyEURSalary > 0);

		// Adjust total yearly EUR salary
		uint256 currentEmployeeSalary = allEmployees[employeeId].yearlyEURSalary;
		totalYearlyEURSalary = totalYearlyEURSalary.sub(currentEmployeeSalary).add(yearlyEURSalary);

		// Set the new salary
		allEmployees[employeeId].yearlyEURSalary = yearlyEURSalary;
	}

	/**
	 * @dev Removes employee from payroll
	 * @param employeeId The employee ID to be removed
	 */
	function removeEmployee(uint256 employeeId) public onlyOwner contractIsActive {
		// Check if employee exists
		require (allEmployees[employeeId].accountAddress != address(0));
		totalEmployees--;

		// Adjust total yearly EUR salary
		uint256 currentEmployeeSalary = allEmployees[employeeId].yearlyEURSalary;
		totalYearlyEURSalary = totalYearlyEURSalary.sub(currentEmployeeSalary);

		// Remove from list
		delete employeeIdLookup[allEmployees[employeeId].accountAddress];
		delete allEmployees[employeeId];
	}

	/**
	 * @dev Allows owner to transfer ETH to this contract
	 */
	function addFunds() public payable onlyOwner contractIsActive {
		ReceivedFund(msg.value);
	} 

	/**
	 * @dev Will pause contract and transfer all remaining funds / token funds to owner.
	 */
	function scapeHatch() public onlyOwner { 
		paused = true;

		// Transfer all tokens in this contract to owner
		for (uint256 i = 1; i <= lastAllowedTokenId; i++) {
			AdvancedTokenERC20 _token = AdvancedTokenERC20(allPayrollAllowedTokens[i].tokenAddress);
			_token.transfer(owner, _token.balanceOf(this));
		}

		// Transfer ether to owner
		if (this.balance > 0) {
			owner.transfer(this.balance);
		}
	}

	/**
	 * @dev Returns total employees that are in payroll
	 */
	function getEmployeeCount() public onlyOwner constant returns (uint256) {
		return totalEmployees;
	}

	/**
	 * @dev Returns employee information based on given ID
	 * @return employeeAddress The address of the employee
	 * @return allowedTokens List of token addresses that this emloyee will accept as payments
	 * @return distribution The percentage of each tokens the employee wishes to accept
	 * @return yearlyEURSalary Employee's yearly salary in EUR
	 * @return lastUpdatedTokenDistributionTimestamp Employee's last updated token distribution timestamp
	 * @return lastPaydayTimestamp Employee's last payday timestamp
	 */
	function getEmployee(uint256 employeeId) public onlyOwner constant returns (address employeeAddress, address[] allowedTokens, uint256[] distribution, uint256 yearlyEURSalary, uint256 lastUpdatedTokenDistributionTimestamp, uint256 lastPaydayTimestamp) {
		Employee storage _employee = allEmployees[employeeId];

		// Check if employee exists
		require (_employee.accountAddress != address(0));
		return (_employee.accountAddress,
				_employee.allowedTokens,
				_employee.distribution,
				_employee.yearlyEURSalary,
				_employee.lastUpdatedTokenDistributionTimestamp,
				_employee.lastPaydayTimestamp
			   );
	}

	/**
	 * @dev Calculates monthly EUR amount spent in salaries
	 * @return Monthly EUR amount spent in salaries
	 */
	function calculatePayrollBurnrate() public onlyOwner constant returns (uint256) {
		return totalYearlyEURSalary.div(12);
	}

	/**
	 * @dev Calculates days until the contract can run out of funds
	 * @return Number of days until the contract can run out of funds
	 */
	function calculatePayrollRunway() public onlyOwner constant returns (uint256) {
		require (lastAllowedTokenId > 0);
		// tokenEURBalances to store EUR balance of each allowed token of this contract
		uint256[] memory tokenEURBalances = new uint256[](lastAllowedTokenId);

		// tokenEURNeededToPayEmployees to store the EUR amount needed for each allowed token to pay all employees
		uint256[] memory tokenEURNeededToPayEmployees = new uint256[](lastAllowedTokenId);

		// Get EUR balance of each payroll allowed tokens
		for (uint256 i = 1; i <= lastAllowedTokenId; i++) {
			AdvancedTokenERC20 _token = AdvancedTokenERC20(allPayrollAllowedTokens[i].tokenAddress);

			// Need -1 since array index starts at 0
			tokenEURBalances[i-1] = _token.balanceOf(this).mul(allPayrollAllowedTokens[i].EURExchangeRate);
		}

		// Calculate the EUR amount required for each token to pay all employees
		for (uint256 j = 1; j <= lastEmployeeId; j++) {
			Employee memory _employee = allEmployees[j];

			if (_employee.accountAddress != 0x0) {
				for (uint256 k = 0; k < _employee.allowedTokens.length; k++) {
					uint256 tokenId = allowedTokenIdLookup[_employee.allowedTokens[k]];

					// Need -1 since array index starts at 0
					tokenEURNeededToPayEmployees[tokenId-1] = tokenEURNeededToPayEmployees[tokenId-1].add(_employee.yearlyEURSalary.mul(_employee.distribution[k]).div(100));
				}
			}
		}

		// Use the first index to calculate payroll runway
		uint256 payrollRunway = tokenEURBalances[0].div(tokenEURNeededToPayEmployees[0]).div(365);

		if (tokenEURBalances.length > 1) {
			// Loop through the remaining allowed tokens and find the one with lowest runway
			for (uint256 l = 1; l < tokenEURBalances.length; l++) {
				uint256 tokenPayrollRunway = tokenEURBalances[l].div(tokenEURNeededToPayEmployees[l]).div(365);
				if (tokenPayrollRunway < payrollRunway) {
					payrollRunway = tokenPayrollRunway;
				}
			}
		}
		return payrollRunway;
	}

	/**
	 * @dev Allows user to transfer token funds to this contract address
	 * @param _from The address that authorizes this contract to spend
	 * @param _value The max amount this contract can spend
	 * @param _token The address of the authorized token
	 * @param _extraData Some extra information to send to this contract
	 */
	function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) public contractIsActive {
		require (allowedTokenIdLookup[_token] > 0);
		ReceivedToken(_from, _value, _token, _extraData);
	}

	//////////// Additional Owner Only Methods ////////////

	/**
	 * @dev Whitelists token contract address that payroll can use to pay employees
	 * @param tokenAddress The token contract address to be whitelisted
	 * @param EURExchangeRate The EUR exchange rate for this token
	 */
	function addPayrollAllowedToken(address tokenAddress, uint256 EURExchangeRate) public onlyOwner contractIsActive {
		// Make sure we don't add the same token twice
		require (allowedTokenIdLookup[tokenAddress] == 0);
		require (EURExchangeRate > 0);
		lastAllowedTokenId++;

		AdvancedTokenERC20 _token = AdvancedTokenERC20(tokenAddress);

		allowedTokenIdLookup[tokenAddress] = lastAllowedTokenId;
		allPayrollAllowedTokens[lastAllowedTokenId].tokenAddress = tokenAddress;
		allPayrollAllowedTokens[lastAllowedTokenId].EURExchangeRate = EURExchangeRate.mul(_token.decimals());
	}

	/**
	 * @dev Allows owner to pause contract
	 * @param _paused The boolean value to be set
	 */
	function pauseContract(bool _paused) public onlyOwner {
		paused = _paused;
	}

	/**
	 * @dev Allows owner to switch owner address
	 * @param _owner The new owner address to be set
	 */
	function changeOwner(address _owner) public onlyOwner {
		owner = _owner;
	}

	/**
	 * @dev Allows owner to switch oracle address
	 * @param _oracle The new oracle address to be set
	 */
	function changeOracle(address _oracle) public onlyOwner {
		oracle = _oracle;
	}

	//////////// Employee Only Methods ////////////
	/**
	 * @dev Sets which tokens an employee wishes to accept as payments and the distribution of each token as well. Can only be set every 6 months
	 * @param tokens List of tokens the employee wishes to accept as payments
	 * @param distribution The percentage of each tokens the employee wishes to accept 
	 */
	function determineAllocation(address[] tokens, uint256[] distribution) public onlyEmployee contractIsActive {
		Employee storage _employee = allEmployees[employeeIdLookup[msg.sender]];
		require (now > _addMonths(6, _employee.lastUpdatedTokenDistributionTimestamp));
		require (tokens.length == distribution.length);

		uint256 totalDistribution = 0;

		// Check if allowed tokens are in payroll allowed tokens list
		for (uint256 i = 0; i < tokens.length; i++) {
			require (allowedTokenIdLookup[tokens[i]] > 0);
			totalDistribution = totalDistribution.add(distribution[i]);
		}

		// Check if total distribution of allowed tokens is 100%
		require (totalDistribution == 100);

		_employee.lastUpdatedTokenDistributionTimestamp = now;
		_employee.allowedTokens = tokens;
		_employee.distribution = distribution;
	}

	/**
	 * @dev Employee claims monthly paycheck. Can only be called once a month.
	 */
	function payday() public onlyEmployee contractIsActive {
		Employee storage _employee = allEmployees[employeeIdLookup[msg.sender]];
		require (now > _addMonths(1, _employee.lastPaydayTimestamp));

		uint256[] memory tokenNeededToPayEmployee = new uint256[](_employee.allowedTokens.length);

		// Check if contract has enough balance to pay this employee
		for (uint256 i = 0; i < _employee.allowedTokens.length; i++) {
			PayrollAllowedToken storage _payrollAllowedToken = allPayrollAllowedTokens[allowedTokenIdLookup[_employee.allowedTokens[i]]]; 

			// Calculate the amount of EUR that we need to pay based on this token distribution
			uint256 tokenEUR = _employee.yearlyEURSalary.div(12).mul(_employee.distribution[i]).div(100); 

			// Calculate the amount of token based on the rate
			uint256 tokenAmount = tokenEUR.div(_payrollAllowedToken.EURExchangeRate);

			AdvancedTokenERC20 _token = AdvancedTokenERC20(_payrollAllowedToken.tokenAddress);
			require (_token.balanceOf(this) >= tokenAmount);

			tokenNeededToPayEmployee[i] = tokenAmount;
		}

		// Update last payday timestamp to prevent re-entrancy
		_employee.lastPaydayTimestamp = now;

		for (uint256 j = 0; j < _employee.allowedTokens.length; j++) {
			_token = AdvancedTokenERC20(_employee.allowedTokens[j]);
			_token.transfer(_employee.accountAddress, tokenNeededToPayEmployee[j]);
		}
	}

	//////////// Oracle Only Methods ////////////
	/**
	 * @dev Allows oracle to set token's exchange rate. Will use decimals from the token
	 * @param token The token contract address to be updated
	 * @param EURExchangeRate The EUR exchange rate for that token
	 */
	function setExchangeRate(address token, uint256 EURExchangeRate) public onlyOracle {
		// Check if token exists
		require (allowedTokenIdLookup[token] > 0);
		require (EURExchangeRate > 0);

		AdvancedTokenERC20 _token = AdvancedTokenERC20(token);
		allPayrollAllowedTokens[allowedTokenIdLookup[token]].EURExchangeRate = EURExchangeRate.mul(_token.decimals());
	}

	//////////// Helper Methods ////////////
	/**
	 * @dev Takes a timestamp and add it by a number of months
	 * @param months Number of months to add to the timestamp
	 * @param timestamp Timestamp to add by a number of months
	 * @return Timestamp after added by a number of months
	 */
	function _addMonths(uint8 months, uint256 timestamp) private constant returns (uint256) {
		uint8 timestampMonth = datetime.getMonth(timestamp);
		uint16 timestampYear = datetime.getYear(timestamp);

		timestampMonth += months;
		while(timestampMonth > 12) {
			timestampMonth -= 12;
			timestampYear++;
		}
		return datetime.toTimestamp(timestampYear, timestampMonth, datetime.getDay(timestamp), datetime.getHour(timestamp), datetime.getMinute(timestamp), datetime.getSecond(timestamp));
	}
}
