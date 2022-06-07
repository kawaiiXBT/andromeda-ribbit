/* SPDX-License-Identifier: GPL3

Staking contract for TOADZ, FrogFrens and other Andromeda Station NFTs - Rewards issued in $RIBBIT

*/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract RibbitStaking is Ownable, ERC721Holder {
    IERC20 public rewardToken;
    IERC721 public nft;

    address ATOADZ = 0x6586d86726B55Cbc7808b50410333Da8b5949447;
    address FFRENS = 0x4C2992793C32c83d9dcFa208Ba79427403F57A59;

    uint256 public stakedTotal;
    uint256 public stakingStartTime;
    uint256 constant stakingTime = 24 hours;
    uint256 constant rewardsA = 100e18;
    uint256 constant rewardsF = 25e18;

    struct Stake {
        address nftSet; // ATOADZ or FFRENS
        uint256[] tokenIds;  // Actual token ID's being staked
        mapping(uint256 => uint256) tokenStakingCoolDown;  // block timestamp difference of now / stake time etc...
        uint256 balance;  // Current Reward tokens owed
        uint256 rewardsReleased; // Total Reward tokens earned
    }

    constructor(IERC721 _nft, IERC20 _rewardToken) {
        nft = _nft;
        rewardToken = _rewardToken;
    }

    mapping(address => Staker) public stakers; // Mapping of a staker to its wallet
    mapping(uint256 => address) public tokenOwner; // Mapping from token ID to owner address

    bool public tokensClaimable;
    bool initialised;

    event Staked(address owner, uint256 amount);
    event Unstaked(address owner, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event ClaimableStatusUpdated(bool status);
    event EmergencyUnstake(address indexed user, uint256 tokenId); 

    function initStaking() public onlyOwner {
        require(!initialised, "RibbitStaking: Already initialised");
        stakingStartTime = block.timestamp;
        initialised = true;
    }

    function setTokensClaimable(bool _enabled) public onlyOwner {
        tokensClaimable = _enabled;
        emit ClaimableStatusUpdated(_enabled);
    }

    function getStakedTokens(address _user)
        public
        view
        returns (uint256[] memory tokenIds)
    {
        return stakers[_user].tokenIds;
    }

    function stake(uint256 tokenId) public {
        _stake(msg.sender, tokenId);
    }

    function stakeBatch(uint256[] memory tokenIds) public {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _stake(msg.sender, tokenIds[i]);
        }
    }

    function _stake(address _user, uint256 _tokenId, uint256 _tokenSet) internal {
        require(initialised, "RibbitStaking: Staking has not been activated yet");
        require(nft.ownerOf(_tokenId) == _user, "RibbitStaking: User must be the owner of the NFT");
        

        Staker storage staker = stakers[_user];  // add user
        staker.tokenIds.push(_tokenId);  // add token id
        staker.tokenSert.push(_tokenSet); // add token set

        staker.tokenStakingCoolDown[_tokenId] = block.timestamp;  // timestamp for when staking begins
        
        tokenOwner[_tokenId] = _user;  // set user as token owner
        
        nft.approve(address(this), _tokenId);
        nft.safeTransferFrom(_user, address(this), _tokenId);  // transfer the NFT to the contract

        emit Staked(_user, _tokenId);
        stakedTotal++;
    }

    function unstake(uint256 _tokenId) public {
        claimReward(msg.sender);
        _unstake(msg.sender, _tokenId);
    }

    function unstakeBatch(uint256[] memory tokenIds) public {
        claimReward(msg.sender);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (tokenOwner[tokenIds[i]] == msg.sender) {
                _unstake(msg.sender, tokenIds[i]);
            }
        }
    }

    // Unstake without calling claim reward function
    function emergencyUnstake(uint256 _tokenId) public {
        _unstake(msg.sender, _tokenId);
        emit EmergencyUnstake(msg.sender, _tokenId);
    }

    function _unstake(address _user, uint256 _tokenId) internal {
        require(tokenOwner[_tokenId] == _user, "RibbitStaking: User address does not match staked NFT ID");
        
        Staker storage staker = stakers[_user];

        uint256 lastIndex = staker.tokenIds.length - 1;
        uint256 lastIndexKey = staker.tokenIds[lastIndex];
        
        if (staker.tokenIds.length > 0) {
            staker.tokenIds.pop();
        }
        staker.tokenStakingCoolDown[_tokenId] = 0;
        delete tokenOwner[_tokenId];

        nft.safeTransferFrom(address(this), _user, _tokenId);

        emit Unstaked(_user, _tokenId);
        stakedTotal--;
    }

    function updateReward(address _user) public {
        Staker storage staker = stakers[_user];
        uint256[] storage ids = staker.tokenIds;
       
        for (uint256 i = 0; i < ids.length; i++) {
            if (
                staker.tokenStakingCoolDown[ids[i]] <
                block.timestamp + stakingTime &&
                staker.tokenStakingCoolDown[ids[i]] > 0
            ) {
            
                uint256 stakedDays = ((block.timestamp - uint(staker.tokenStakingCoolDown[ids[i]]))) / stakingTime;
                uint256 partialTime = ((block.timestamp - uint(staker.tokenStakingCoolDown[ids[i]]))) % stakingTime;
                
                staker.balance +=  token * stakedDays;

                staker.tokenStakingCoolDown[ids[i]] = block.timestamp + partialTime;

                console.logUint(staker.tokenStakingCoolDown[ids[i]]);
                console.logUint(staker.balance);
            }
        }
    }

    function claimReward(address _user) public {
        updateReward(_user);
        require(tokensClaimable == true, "RibbitStaking: Tokens cannnot be claimed yet");
        require(stakers[_user].balance > 0 , "RibbitStaking: No reward tokens available to be claimed");


        stakers[_user].rewardsReleased += stakers[_user].balance;
        stakers[_user].balance = 0;
        
        safeRewardTransfer(_user, stakers[_user].balance);

        emit RewardPaid(_user, stakers[_user].balance);
    }


    /**
     * @dev Internal function to send rewards while checking for potential imbalances
     * Note: if available reward is less than calculated amount, reward will still take place
     * And pending reward calculations might 
     * @param _to — the target address of the reward
     * @param _amount — the amount of reward to transfer
     */
    function safeRewardTransfer(address _to, uint256 _amount)
        internal 
    {
        uint256 rewardBal = getAvailableRewardBalance();
        if (_amount > 0) {
            if (_amount > rewardBal) {
                rewardToken.transfer(_to, rewardBal);
            } else {
                rewardToken.transfer(_to, _amount);
            }
        }
    }

    function getAvailableRewardBalance() 
        public
        view
        returns (uint256)
    {
        require(stakers[_user].balance > 0 , "RibbitStaking: No reward tokens available to be claimed");
        return stakers[_user].balance;
    }

}
