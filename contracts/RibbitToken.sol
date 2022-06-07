/* SPDX-License-Identifier: GPL3

                    RIBBIT-TOKEN

   (`-')   _     <-.(`-') <-.(`-')   _     (`-')      
<-.(OO )  (_)     __( OO)  __( OO)  (_)    ( OO).->   
,------,) ,-(`-')'-'---.\ '-'---.\  ,-(`-')/    '._   
|   /`. ' | ( OO)| .-. (/ | .-. (/  | ( OO)|'--...__) 
|  |_.' | |  |  )| '-' `.)| '-' `.) |  |  )`--.  .--' 
|  .   .'(|  |_/ | /`'.  || /`'.  |(|  |_/    |  |    
|  |\  \  |  |'->| '--'  /| '--'  / |  |'->   |  |    
`--' '--' `--'   `------' `------'  `--'      `--'    
(`-')                <-.(`-')  (`-')  _<-. (`-')_     
( OO).->       .->    __( OO)  ( OO).-/   \( OO) )    
/    '._  (`-')----. '-'. ,--.(,------.,--./ ,--/     
|'--...__)( OO).-.  '|  .'   / |  .---'|   \ |  |     
`--.  .--'( _) | |  ||      /)(|  '--. |  . '|  |)    
   |  |    \|  |)|  ||  .   '  |  .--' |  |\    |     
   |  |     '  '-'  '|  |\   \ |  `---.|  | \   |     
   `--'      `-----' `--' '--' `------'`--'  `--'     */


pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


contract RibbitToken is IERC20, Ownable {
    using SafeMath for uint256;

    string public constant name = "Ribbit Token";
    string public constant symbol = "RIBBIT";
    uint8 public constant decimals = 18;
    uint256 public override totalSupply = 69000000000e18;

    mapping (address => mapping (address => uint256)) internal allowances;
    mapping (address => uint256) internal balances;

    address public minter;
    uint256 public mintingAllowedAfter;
    uint32 public minimumMintGap = 1 days * 365;
    uint8 public mintCap = 2;

    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    mapping (address => uint) public nonces;

    event MinterChanged(address minter, address newMinter);
    event MinimumMintGapChanged(uint32 previousMinimumGap, uint32 newMinimumGap);
    event MintCapChanged(uint8 previousCap, uint8 newCap);

    constructor(address account, address _minter, uint256 _mintingAllowedAfter) {
        balances[account] = totalSupply;
        minter = _minter;
        mintingAllowedAfter = _mintingAllowedAfter;
        
        emit Transfer(address(0), account, totalSupply);
        emit MinterChanged(address(0), minter);
    }

    /**
     * @dev Change the minter address
     * @param _minter The address of the new minter
     */
    function setMinter(address _minter) 
        external 
        onlyOwner
    {
        emit MinterChanged(minter, _minter);
        minter = _minter;
    }

    function setMintCap(uint8 _cap) 
        external 
        onlyOwner 
    {
        emit MintCapChanged(mintCap, _cap);
        mintCap = _cap;
    }

    function setMinimumMintGap(uint32 _gap) 
        external
        onlyOwner
    {
        emit MinimumMintGapChanged(minimumMintGap, _gap);
        minimumMintGap = _gap;
    }

    function mint(address _to, uint256 _amount) 
        external 
    {
        require(msg.sender == minter, "RibbitToken::mint: only the minter can mint");
        require(block.timestamp >= mintingAllowedAfter, "RibbitToken::mint: minting not allowed yet");
        require(_to != address(0), "RibbitToken::mint: cannot transfer to the zero address");
        require(_amount <= (totalSupply.mul(mintCap)).div(100), "RibbitToken::mint: exceeded mint cap");

        mintingAllowedAfter = (block.timestamp).add(minimumMintGap);
        totalSupply = totalSupply.add(_amount);
        balances[_to] = balances[_to].add(_amount);

        _moveDelegates(address(0), delegates[_to], _amount);
        emit Transfer(address(0), _to, _amount);
    }

    /**
     * @notice Get the number of tokens `spender` is approved to spend on behalf of `account`
     * @param account The address of the account holding the funds
     * @param spender The address of the account spending the funds
     * @return The number of tokens approved
     */
    function allowance(address account, address spender) 
        public
        view 
        override 
        returns (uint256) 
    {
        return allowances[account][spender];
    }

    /**
     * @notice Approve `spender` to transfer up to `amount` from `src`
     * @dev This will overwrite the approval amount for `spender`
     *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
     * @param spender The address of the account which may transfer tokens
     * @param amount The number of tokens that are approved (2^256-1 means infinite)
     * @return Whether or not the approval succeeded
     */
    function approve(address spender, uint256 amount) 
        public 
        override
        returns (bool) 
    {
        require(spender != address(0), "RibbitToken: cannot approve zero address");

        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice Get the number of tokens held by the `account`
     * @param account The address of the account to get the balance of
     * @return The number of tokens held
     */
    function balanceOf(address account) 
        external 
        view 
        override 
        returns (uint256) 
    {
        return balances[account];
    }

    /**
     * @notice Transfer `amount` tokens from `msg.sender` to `dst`
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transfer(address dst, uint256 amount) 
        external 
        override
        returns (bool) 
    {
        _transferTokens(msg.sender, dst, amount);
        return true;
    }

    /**
     * @notice Transfer `amount` tokens from `src` to `dst`
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transferFrom(address src, address dst, uint256 amount) 
        external 
        override
        returns (bool) 
    {
        address spender = msg.sender;
        uint256 spenderAllowance = allowances[src][spender];

        if (spender != src && spenderAllowance != uint256(-1)) {
            uint256 newAllowance = sub256(spenderAllowance, amount, "RibbitToken::transferFrom: transfer amount exceeds spender allowance");
            allowances[src][spender] = newAllowance;

            emit Approval(src, spender, newAllowance);
        }

        _transferTokens(src, dst, amount);
        return true;
    }

    function add256(uint256 a, uint256 b, string memory errorMessage) 
        internal 
        pure 
        returns (uint256) 
    {
        uint256 c = a + b;
        require(c >= a, errorMessage);
        return c;  
    }

    function sub256(uint256 a, uint256 b, string memory errorMessage) 
        internal 
        pure 
        returns (uint256) 
    {
        require(b <= a, errorMessage);
        return a - b;
    }

    function getChainId() 
        internal 
        pure 
        returns (uint256) 
    {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount)
        internal 
    {
        require(account != address(0), "ERC20: burn from the zero address");

        balances[account] = balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        totalSupply = totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
        
        _moveDelegates(delegates[account], address(0), amount);
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     */
    function burn(uint256 amount) 
        external 
        returns (bool)
    {
        _burn(msg.sender, amount);
        return true;
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) 
        external
        returns (bool)
    {
        address spender = msg.sender;
        uint256 spenderAllowance = allowances[account][spender];

        if (spender != account && spenderAllowance != uint256(-1)) {
            uint256 newAllowance = sub256(spenderAllowance, amount, "RibbitToken::burnFrom: burn amount exceeds spender allowance");
            allowances[account][spender] = newAllowance;

            emit Approval(account, spender, newAllowance);
        }

        _burn(account, amount);
        return true;
    }
}