// SPDX-License-Identifier: GPLv3
// Funding Pool with a minimum deposit amount of $50 USD implementing Chronicle Oracle for the price feed
pragma solidity ^0.8.8;

interface ISelfKisser {
    function selfKiss(address, address) external;
    function tolled(address) external view returns (bool);
}
/**
 * @title IChronicle
 *
 * @notice Interface for Chronicle Protocol's oracle products
 */

interface IChronicle {
    /// @notice Returns the oracle's identifier.
    /// @return wat The oracle's identifier.
    function wat() external view returns (bytes32 wat);

    /// @notice Returns the oracle's current value.
    /// @dev Reverts if no value set.
    /// @return value The oracle's current value.
    function read() external view returns (uint256 value);

    /// @notice Returns the oracle's current value and its age.
    /// @dev Reverts if no value set.
    /// @return value The oracle's current value.
    /// @return age The value's age.
    function readWithAge() external view returns (uint256 value, uint256 age);

    /// @notice Returns the oracle's current value.
    /// @return isValid True if value exists, false otherwise.
    /// @return value The oracle's current value if it exists, zero otherwise.
    function tryRead() external view returns (bool isValid, uint256 value);

    /// @notice Returns the oracle's current value and its age.
    /// @return isValid True if value exists, false otherwise.
    /// @return value The oracle's current value if it exists, zero otherwise.
    /// @return age The value's age if value exists, zero otherwise.
    function tryReadWithAge() external view returns (bool isValid, uint256 value, uint256 age);
}

library PriceConverter {
    // We could make this public, but then we'd have to deploy it
    function getPrice() internal view returns (uint256) {
        // Sepolia ETH / USD Address
        IChronicle priceFeed = IChronicle(0xc8A1F9461115EF3C1E84Da6515A88Ea49CA97660);
        uint256 answer = priceFeed.read();
        // ETH/USD rate in 18 digit
        return uint256(answer * 10000000000);
        // or (Both will do the same thing)
        // return uint256(answer * 1e10); // 1* 10 ** 10 == 10000000000
    }

    // 1000000000
    function getConversionRate(uint256 ethAmount) internal view returns (uint256) {
        uint256 ethPrice = getPrice();
        uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1000000000000000000;
        // or (Both will do the same thing)
        // uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1e18; // 1 * 10 ** 18 == 1000000000000000000
        // the actual ETH/USD conversion rate, after adjusting the extra 0s.
        return ethAmountInUsd;
    }
}

error NotOwner();

contract FundingPool {
    using PriceConverter for uint256;

    mapping(address => uint256) public addressToAmountFunded;
    ISelfKisser kisser = ISelfKisser(0x0Dcc19657007713483A5cA76e6A7bbe5f56EA37d);
    IChronicle oracle = IChronicle(0xc8A1F9461115EF3C1E84Da6515A88Ea49CA97660); // ETH/USD
    address[] public funders;

    address public immutable i_owner;
    uint256 public constant MINIMUM_USD = 50 * 10 ** 18;

    constructor() {
        i_owner = msg.sender;
    }

    function whitelistOracle() public {
        kisser.selfKiss(address(oracle), address(this));
        bool success = kisser.tolled(address(this));
        require(success, "Oracle whitelist was not successful");
    }

    function fund() public payable {
        require(msg.value.getConversionRate() >= MINIMUM_USD, "You need to spend more ETH!");
        // require(PriceConverter.getConversionRate(msg.value) >= MINIMUM_USD, "You need to spend more ETH!");
        addressToAmountFunded[msg.sender] += msg.value;
        funders.push(msg.sender);
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) revert NotOwner();
        _;
    }

    function withdraw() public onlyOwner {
        for (uint256 funderIndex = 0; funderIndex < funders.length; funderIndex++) {
            address funder = funders[funderIndex];
            addressToAmountFunded[funder] = 0;
        }
        funders = new address[](0);
        // // transfer
        // payable(msg.sender).transfer(address(this).balance);
        // // send
        // bool sendSuccess = payable(msg.sender).send(address(this).balance);
        // require(sendSuccess, "Send failed");
        // call
        (bool callSuccess,) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "Call failed");
    }

    fallback() external payable {
        fund();
    }

    receive() external payable {
        fund();
    }
}
