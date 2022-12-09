// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "@layerzerolabs/contracts-upgradable/lzApp/NonblockingLzAppUpgradeable.sol";

import "./StorageV2.sol";

/// @title Vault
/// @notice This contract is a vault that rewards stakers who lock their tokens with reward tokens
/// @notice It inherits the Storage contract to not have collition with vault, uses initializable to be upgradable and uses ownable for security
contract VaultV2 is StorageV2, NonblockingLzAppUpgradeable{
    /// @notice initializes contract with tokens
    /// @param _LPToken address of tokens to be staked
    /// @param _theToken address of tokens to be rewarded
    function initialize(address _LPToken, address _theToken, address _lzEndpoint, uint16 _dstChainId) public {
        require(!initialized, "contract already initialized");
        require(msg.sender == currentOwner, "not owner");
        initialized = true;
        
        LPToken = _LPToken;
        theToken = TheToken(_theToken);

        ids = 0;

        //added for V2, Omnichain capability
        dstChainId = _dstChainId;
        __NonblockingLzAppUpgradeable_init(_lzEndpoint);
    }

    /// @notice sets the variable TokensPerDuration
    /// @param _amount number of tokens given as reward per duration
    /// @param _duration duration during which user get a number of tokens as reward
    function setTokensPerDuration(uint _amount, uint _duration) public{
        require(_amount > 0, "Needs to have rewards");
        require(_duration > 0, "Duration can't be zero");
        require(msg.sender == currentOwner, "not owner");
        tokensPerDuration = (_amount/_duration)+1;
    }

    /// @notice Allows a user to deposit tokens and lock them
    /// @param _amount number of tokens to lock in vault
    /// @param _lockingPeriod amount of time t lock the tokens for (6 months = 1, 1 year = 2, 2 years = 4 and 4 years = 8)
    function deposit(uint _amount, uint _lockingPeriod) external returns(uint){
        require(_amount > 0, "Can't stake zero tokens");
        require(_lockingPeriod == 1 || _lockingPeriod == 2 || _lockingPeriod == 4 || _lockingPeriod == 8,
        "Locking Period needs to be either 6 months (1), 1 year (2), 2 years (4) or 4 years (8)");
        
        //checks if any deposits has been unlocked
        checkLocks();

        //calculates the rewards per token and the rewards
        updateRewardVars(msg.sender, ids, block.timestamp);

        //take LPTokens from user
        (bool success,) = LPToken.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender,address(this),_amount));
        require(success,"deposit: transferFrom failed");

        uint startLock = block.timestamp;
        uint endLock = calcEndLock(startLock,_lockingPeriod);
        
        //update array with the unlock times
        ToUnlock memory lock = ToUnlock(msg.sender, ids, endLock);
        locks.push(lock);

        //update info for deposit
        AmountDeposited memory amountDeposit = AmountDeposited(_amount,_lockingPeriod,startLock,endLock);
        deposits[msg.sender][ids] = amountDeposit;
        ids++;

        //Send total funds update to Omnichain
        uint updatedFunds = totalFunds + _amount * _lockingPeriod;
        bytes memory payload = abi.encode(updatedFunds);
        _lzSend(dstChainId, payload, payable(msg.sender), address(0x0), bytes(""));

        //Update total funds in contract
        totalFunds = updatedFunds;

        return ids-1;
    }

    /// @notice Allows a user to withdraw tokens if locking period over
    /// @param _id used to identify the specific deposit the user wants to withdraw
    function withdraw(uint _id) external {
        require(deposits[msg.sender][_id].endAt <= block.timestamp, "Locking Period hasn't ended for this deposit");

        //checks if any deposits has been unlocked
        checkLocks();

        //takes out the deposited amount
        uint amount = deposits[msg.sender][_id].amount;
        deposits[msg.sender][_id].amount = 0;

        //take LPTokens from contract
        (bool success,) = LPToken.call(abi.encodeWithSignature("transfer(address,uint256)", msg.sender,amount));
        require(success,"withdraw: transfer failed");
    }

    /// @notice Allows a user to get reward tokens based on their deposit
    /// @param _id used to identify the specific deposit the user wants to get the rewards
    function getRewards(uint _id) external {
        //checks if any deposits has been unlocked
        checkLocks();

        //calculates the rewards per token and the rewards
        updateRewardVars(msg.sender, _id, block.timestamp);

        //transfers rewards
        uint reward = rewards[msg.sender][_id];
        if (reward > 0) {
            rewards[msg.sender][_id] = 0;
            theToken.transfer(msg.sender, reward);
        }
    }

    /// @notice updates several variables and calculates rewards for the user
    /// @param _account address of the user to calculate rewards
    /// @param _id used to identify the specific deposit
    /// @param _updateTime when this change happened
    function updateRewardVars(address _account, uint _id, uint _updateTime) public {
        // updates reward per token and last update
        rewardPerToken = calcRewardPerToken(_updateTime);
        
        lastUpdate = _updateTime;

        //updates users rewards and user start reward per token
        rewards[_account][_id] = rewardsEarned(_account, _id, _updateTime);
        userStartRewardPerToken[_account][_id] = rewardPerToken;
    }

    /// @notice calculates the rewards per token
    /// @return the value of rewards per token
    function calcRewardPerToken(uint currentTime) public view returns(uint){
        //rewardPerToken = rewardPerToken + (rewardRate * (current time - lastupdate)) / totalFunds
        //1e18 to scale down
        if (totalFunds == 0) {
            return rewardPerToken;
        } else {
            return rewardPerToken + (tokensPerDuration * (currentTime - lastUpdate) * 1e18) / totalFunds;
        }
    }

    /// @notice calculates the rewards a user has gained
    /// @param _account address of the user to calculate rewards
    /// @param _id used to identify the specific deposit
    /// @return rewards of that user
    function rewardsEarned(address _account, uint _id, uint currentTime) public view returns(uint) {
        //amount of tokens staked * (reward per token - user start reward per token) + previous rewards earned
        // 1e18 to scale up
        // if locking period has ended it doesn't have any tokens in the pool, but might not have withdrawn yet
        uint amountStaked;
        if(deposits[_account][_id].endAt < currentTime){
            amountStaked = 0;
        } else{
            amountStaked = deposits[_account][_id].amount * deposits[_account][_id].lockingPeriod;
        }
        return (amountStaked * (calcRewardPerToken(currentTime) - userStartRewardPerToken[_account][_id])) / 1e18 + rewards[_account][_id];
    }

    /// @notice checks if any deposit has unlocked, if so calculates rewards and updates variables at the time it happened
    function checkLocks() public {
        //reset sorted array so it can be sorted again
        uint length = sorted.length;
        for(uint z=0; z<length; z++){
            sorted.pop();
        }

        //unlocking array needs to be in descending order to keep time intervals correct
        sort();

        locks = sorted;
        //checks if any deposits have unlocked, if they have take value out of totalFunds
        uint x;
        uint y = 0;
        for(x=locks.length; x>0; x--){
            if(locks[x-1].endTime <= block.timestamp){
                updateRewardVars(locks[x-1].user, locks[x-1].id, locks[x-1].endTime);

                //Send total funds update to Omnichain
                uint updatedFunds = totalFunds + deposits[locks[x-1].user][locks[x-1].id].amount * deposits[locks[x-1].user][locks[x-1].id].lockingPeriod;
                bytes memory payload = abi.encode(updatedFunds);
                _lzSend(dstChainId, payload, payable(msg.sender), address(0x0), bytes(""));
                    
                //Update total funds in contract
                totalFunds = updatedFunds;
                    
                y++;
            }
        }
        
        //delete already unlocked entries
        for(uint j=0; j<y; j++){
            locks.pop();
        }
    }

    /// @notice calculates when a deposit is going to be unlocked
    /// @param currentTime time when deposit happens 
    /// @param lockingPeriod amount of time the funds will be locked 
    /// @return time when it will be unlocked
    function calcEndLock(uint currentTime, uint lockingPeriod) private pure returns(uint) {
        if (lockingPeriod == 1) {return currentTime + 1/2 * (360*24*60*60);}
        else if (lockingPeriod == 2) {return currentTime + 1 * (360*24*60*60);}
        else if (lockingPeriod == 4) {return currentTime + 2 * (360*24*60*60);}
        else {return currentTime + 4 * (360*24*60*60);}
    }

    /// @notice used to sort the array of the moments when a deposit unlocks in descending order
    function sort() public{

        for (uint i = 0; i < locks.length; i++) {
            helper[i] = 0;

            for (uint j = 0; j < i; j++){
                if (locks[i].endTime > locks[j].endTime) {
                    if(helper[i] == 0){
                        helper[i] = helper[j];
                    }
                    helper[j] = helper[j] + 1;
                }
            }

            if(helper[i] == 0) {
                helper[i] = i + 1;
            }
        }

        uint lengthsorted = sorted.length;
        for (uint i = 0; i < locks.length; i++) {
            if (i < lengthsorted) continue;
            sorted.push(ToUnlock(msg.sender, 0, 0));
        }

        for (uint i = 0; i < locks.length; i++) {
            sorted[helper[i]-1] = locks[i];
        }
    }

    /// @notice receives updated totalFunds from other chain and replaces value
    /// @param _payload updated totalFunds
    function _nonblockingLzReceive( uint16, bytes memory, uint64, /*_nonce*/ bytes memory _payload) internal override {
        //decode the updated total funds
        uint updatedTotalFunds = abi.decode(_payload, (uint));

        //update total funds
        totalFunds = updatedTotalFunds;
    }

}