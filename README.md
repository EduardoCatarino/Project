Goerli (Ethereum Testnet)​
chainId: 10121
endpoint: 0xbfD2135BFfbb0B5378b56643c2Df8a87552Bfa23

ARCHITECTURE:

The main logic of the Vault contract revolves around calculating the rewards each user is intitled to. To do this we have to, each time a deposit, an unlocking of funds or a rewards withdrawl happens, to calculate the rewards per token staked that any user is intitled to in the interval between when this event happens and the previous one. We add this rewards per token to a variable that contains the rewards per token of previous intervals, this way we end up with the somation of all the intervals rewards per token. At the same time we calculate this value, we also save it to a variable specific to the user to witch the event pertains to. This way when we want to calculate the rewards a user has, we subtract the somation of all rewards per token to the one saved with the user, resulting in only the rewards per token relevant to the user. After, we simple multiply this value by the number of tokens that the user staked and we have the rewards for that user.

deposit()
In this function we first check to see if any deposits have unlocked since this can happen without anione triggering the smart contract. We then calculate the rewards per token and the rewards. After we receive the tokens for the deposit and add the deposits information into the storage.

whithdraw()
In this function we check if any deposits have unlocked and return the tokens the user wants to withdraw.

getReward()
In this function we check if any deposits have unlocked, we calculate the rewards per token and the rewards and send back whatever rewards the user may have.

updateRewardVars()
This function first calculates the rewards per token at a given time (so that we can calculate at unlocking periods) and then calculates the rewards the user has gained up to that point.

calcRewardPerToken()
This function calculates the rewards per token using the formula "rewardPerToken = rewardPerToken + (rewardRate * (current time - lastupdate)) / totalFunds"

rewardsEarned()
This function calculates the rewards of a user using the formula "rewards = amount of tokens staked * (reward per token - user start reward per token) + previous rewards earned"

checklocks()
This function checks if any deposits have unlocked, verifies that this information is sorted so that they are handled in the order they happened and then calculates the rewards per token and the rewards that the deposit in question has earned.

calcEndLock()
This auxilary function helps calculate the time when the deposits will unlock.

sort()
This function sorts the unloking information.

NOTES:
This contract assumes it has enought tokens to pay out rewards
In the vault we add one to the tokensPerDuration in order to resolve the issue with rewards being rounded down