// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed from, address indexed to);

    constructor() {
        owner = msg.sender;
    }

    function getOwner() public view returns (address) {
        return owner;
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Function restricted to owner of contract"
        );
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0) && newOwner != owner);

        owner = newOwner;
        emit OwnershipTransferred(owner, newOwner);
    }
}

abstract contract ERC20Interface {
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public virtual;

    function balanceOf(address who) public virtual returns (uint256);

    function allowance(
        address owner,
        address spender
    ) public view virtual returns (uint256);

    function transfer(address to, uint256 value) public virtual returns (bool);

    function gasOptimizedAirdrop(
        address[] calldata _addrs,
        uint256[] calldata _values
    ) external virtual;
}

contract Multisender is Ownable {
    mapping(address => uint256) private membershipExpiryTime;

    uint256 public oneDayFee;
    uint256 public lifetimeFee;

    event MembershipAssigned(address indexed user, uint256 expiryTime);
    event MembershipRevoked(address indexed user);
    event MultisendNativeToken(
        address indexed sender,
        uint256 totalAddresses,
        uint256 totalAmount
    );
    event Withdraw(address indexed owner, uint256 amount);
    event WithdrawERC20(
        address indexed recipient,
        address indexed token,
        uint256 amount
    );

    constructor() {
        oneDayFee = 1;
        lifetimeFee = 100;
    }

    fallback() external payable {
        revert();
    }

    receive() external payable {
        revert();
    }

    function setMembershipFees(
        uint256 oneDay,
        uint256 lifetime
    ) public onlyOwner returns (bool success) {
        require(oneDay > 0 && oneDay < lifetime);

        oneDayFee = oneDay;
        lifetimeFee = lifetime;

        return true;
    }

    function isPremiumMember(
        address user
    ) public view returns (bool isPremium) {
        return membershipExpiryTime[user] > block.timestamp;
    }

    function assignMembership(
        address user,
        uint256 membershipDays
    ) internal returns (bool success) {
        require(membershipDays > 0, "Days must be greater than 0");

        if (membershipExpiryTime[user] > block.timestamp) {
            membershipExpiryTime[user] += membershipDays * 1 days;
        } else {
            membershipExpiryTime[user] =
                block.timestamp +
                membershipDays *
                1 days;
        }

        emit MembershipAssigned(user, membershipExpiryTime[user]);
        return true;
    }

    function revokeExpiredMembership(
        address user
    ) public onlyOwner returns (bool success) {
        require(
            membershipExpiryTime[user] < block.timestamp,
            "Membership is not expired yet"
        );

        delete membershipExpiryTime[user];
        return true;
    }

    function grantMembership(
        address user,
        uint256 membershipDays
    ) public onlyOwner returns (bool success) {
        return assignMembership(user, membershipDays);
    }

    function becomeMember() public payable returns (bool success) {
        require(
            msg.value >= oneDayFee && msg.value <= lifetimeFee,
            "Invalid amount sent"
        );

        uint256 membershipDays = msg.value / oneDayFee;
        if (msg.value == lifetimeFee) {
            membershipDays = 36500;
        }

        return assignMembership(msg.sender, membershipDays);
    }

    function multisendNativeToken(
        address[] memory recipients,
        uint256[] memory amounts
    ) public payable returns (bool success) {
        require(
            recipients.length == amounts.length,
            "Recipients and amounts length mismatch"
        );

        uint256 totalAmount = 0;
        for (uint i = 0; i < recipients.length; i++) {
            totalAmount += amounts[i];
            payable(recipients[i]).transfer(amounts[i]);
        }

        emit MultisendNativeToken(msg.sender, recipients.length, totalAmount);
        return true;
    }

    function withdrawFunds() public onlyOwner returns (bool success) {
        require(address(this).balance > 0, "Insufficient balance");
        payable(owner).transfer(address(this).balance);
        emit Withdraw(owner, address(this).balance);
        return true;
    }

    function withdrawERC20(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) public onlyOwner returns (bool success) {
        ERC20Interface token = ERC20Interface(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0 && amount < balance, "Insufficient balance");

        token.transfer(recipient, amount);
        emit WithdrawERC20(recipient, tokenAddress, amount);
        return true;
    }
}
