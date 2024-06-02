// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title A ERC20 implementation with extended reflection token functionalities
/// @notice Implements ERC20 standards with additional token holder reward feature
abstract contract ReflectiveERC20 is ERC20 {
    // Constants
    uint256 internal constant BPS_DIVISOR = 10_000;
    address internal constant ZERO_ADDRESS = address(0);

    mapping(address => uint256) private rewardOwned;

    uint256 private constant UINT_256_MAX = type(uint256).max;
    uint8 public immutable localDecimals;
    uint256 private rewardFeeTotal;
    uint256 private tokenFeeTotal;
    bool private immutable isReflective;
    uint256 public rewardsFeeBPS;

    /* -------------- Errors ------------ */
    error InvalidDecimals(uint8 decimals);
    error TokenIsNotReflective();
    error TotalReflectionTooSmall();
    error ZeroTransferError();
    error MintingNotEnabled();
    error BurningNotEnabled();

    /// @notice Constructor to initialize the ReflectionErc20 token
    /// @param _name Name of the token
    /// @param _symbol Symbol of the token
    /// @param _tokenOwner Address of the token owner
    /// @param _initialSupply Initial total supply
    /// @param _decimals Token decimal number
    /// @param _rewardsFeeBPS Token reward (rewards fee BPS value)
    /// @param _isReflective Indicates whether to enable reflective features otherewise this is an ERC20
    constructor(
        string memory _name,
        string memory _symbol,
        address _tokenOwner,
        uint256 _initialSupply,
        uint8 _decimals,
        uint256 _rewardsFeeBPS,
        bool _isReflective
    ) ERC20(_name, _symbol) {
        if (_initialSupply != 0) {
            super._mint(_tokenOwner, _initialSupply * 10 ** _decimals);
            rewardFeeTotal = (UINT_256_MAX - (UINT_256_MAX % _initialSupply));
        }

        // Check that the decimals number does not exceed 18.
        if (_decimals > 18) {
            revert InvalidDecimals(_decimals);
        }
        rewardOwned[_tokenOwner] = rewardFeeTotal;
        if (isReflective) {
            rewardsFeeBPS = _rewardsFeeBPS;
        }
        localDecimals = _decimals;
        isReflective = _isReflective;
    }

    // public standard ERC20 functions

    /// @notice Returns the number of decimals used for the token
    /// @return The number of decimals
    function decimals() public view virtual override returns (uint8) {
        return localDecimals;
    }

    /// @notice Gets balance the erc20 token for specific address
    /// @param account Account address
    /// @return Token balance
    function balanceOf(address account) public view override returns (uint256) {
        if (isReflective) {
            return tokenFromReflection(rewardOwned[account]);
        } else {
            return super.balanceOf(account);
        }
    }

    /// @notice Transfers allowed tokens between accounts
    /// @param from From account
    /// @param to To account
    /// @param value Transferred value
    /// @return Success
    function transferFrom(address from, address to, uint256 value) public virtual override returns (bool) {
        address spender = super._msgSender();

        super._spendAllowance(from, spender, value);
        _reflectiveTransfer(from, to, value);
        return true;
    }

    /// @notice Transfers tokens from owner to an account
    /// @param to To account
    /// @param value Transferred value
    /// @return Success
    function transfer(address to, uint256 value) public virtual override returns (bool) {
        address owner = super._msgSender();

        _reflectiveTransfer(owner, to, value);
        return true;
    }

    /// @notice Transfers tokens from owner to an account
    /// @param _from from account
    /// @param _to To account
    /// @param _amount Transferred amount
    function _reflectiveTransfer(address _from, address _to, uint256 _amount) internal {
        if (isReflective) {
            require(_from != ZERO_ADDRESS, "From address cannot be zero");
            require(_to != ZERO_ADDRESS, "To address cannot be zero");
            require(_amount != 0, "Transfer cannot be for a zero amount");

            _transferReflected(_from, _to, _amount);
        } else {
            super._transfer(_from, _to, _amount);
        }
    }

    /// @notice Creates specified amount of tokens, it either uses standard OZ ERC function
    ///         or in case of reflection logic, it is prohibited
    /// @param _account Account new tokens will be transferred to
    /// @param _value Created tokens value
    function _reflectiveMint(address _account, uint256 _value) internal {
        if (isReflective) {
            revert MintingNotEnabled();
        } else {
            super._mint(_account, _value);
        }
    }

    /// @notice Destroys specified amount of tokens, it either uses standard OZ ERC function
    ///         or in case of reflection logic, it is prohibited
    /// @param _account Account in which tokens will be destroyed
    /// @param _value Destroyed tokens value
    function _reflectiveBurn(address _account, uint256 _value) internal {
        if (isReflective) {
            revert BurningNotEnabled();
        } else {
            super._burn(_account, _value);
        }
    }

    // public reflection custom functions

    /// @notice Sets a new reflection fee
    /// @dev Should only be called by the contract owner
    /// @param _newRewardsFeeBPS The reflection fee in basis points
    function _setRewardsFee(uint256 _newRewardsFeeBPS) internal {
        if (!isReflective) {
            revert TokenIsNotReflective();
        }

        rewardsFeeBPS = _newRewardsFeeBPS;
    }

    /// @notice Calculates number of tokens from reflection amount
    /// @param _amount Reflection token amount
    function tokenFromReflection(uint256 _amount) public view returns (uint256) {
        if (_amount > rewardFeeTotal) {
            revert TotalReflectionTooSmall();
        }

        uint256 currentRate = _getRate();
        return _amount / currentRate;
    }

    // private reflection custom functions

    /// @notice Transfers reflected amount of tokens
    /// @param _sender Account to transfer tokens from
    /// @param _recipient Account to transfer tokens to
    /// @param _amount Total token amount
    function _transferReflected(address _sender, address _recipient, uint256 _amount) private {
        uint256 tokenFee = calculateFee(_amount);
        uint256 transferAmount = _amount - tokenFee;
        uint256 currentRate = _getRate();
        uint256 rewardAmount = _amount * currentRate;
        uint256 rewardFee = tokenFee * currentRate;
        uint256 rewardTransferAmount = transferAmount * currentRate;

        if (transferAmount != 0) {
            updateBalances(_sender, _recipient, rewardAmount, rewardTransferAmount);

            rewardFeeTotal = rewardFeeTotal - rewardFee;
            tokenFeeTotal = tokenFeeTotal + tokenFee;
            emit Transfer(_sender, _recipient, transferAmount);
        }
    }

    /// @notice Calculates the reflection fee from token amount
    /// @param _amount Amount of tokens to calculate fee from
    function calculateFee(uint256 _amount) private view returns (uint256) {
        return (_amount * rewardsFeeBPS) / BPS_DIVISOR;
    }

    /// @notice Transfers Tax related tokens and do not apply reflection fees
    /// @param _from Account to transfer tokens from
    /// @param _to Account to transfer tokens to
    /// @param _amount Total token amount
    function _transferNonReflectedTax(address _from, address _to, uint256 _amount) internal {
        if (isReflective) {
            if (_amount != 0) {
                uint256 currentRate = _getRate();
                uint256 rewardAmount = _amount * currentRate;

                updateBalances(_from, _to, rewardAmount, rewardAmount);
                emit Transfer(_from, _to, _amount);
            }
        } else {
            super._transfer(_from, _to, _amount);
        }
    }

    /// @notice Get ratio rate between reflective and token supply
    /// @return Reflective rate
    function _getRate() private view returns (uint256) {
        return rewardFeeTotal / totalSupply();
    }

    /// @notice Update reflective balances to reflect amount transfer,
    ///         with or without a fee applied. If a fee is applied,
    ///         the amount deducted from the sender will differ
    ///         from amount added to the recipient
    /// @param _sender Sender address
    /// @param _recipient Recipient address
    /// @param _senderAmount Amount to be deducted from sender
    /// @param _reciptientAmount Amount to be added to recipient
    function updateBalances(address _sender, address _recipient, uint256 _senderAmount, uint256 _reciptientAmount) private {
        uint256 fromBalance = rewardOwned[_sender];

        if (fromBalance < _senderAmount) {
            revert ERC20InsufficientBalance(_recipient, fromBalance, _senderAmount);
        }
        rewardOwned[_sender] = rewardOwned[_sender] - _senderAmount;
        rewardOwned[_recipient] = rewardOwned[_recipient] + _reciptientAmount;
    }
}