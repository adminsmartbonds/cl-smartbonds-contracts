// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { ReflectiveERC20 } from "./ReflectiveERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

//import "hardhat/console.sol";

contract SBDefiContract is ReflectiveERC20, Ownable, ReentrancyGuard {
    struct ContractProperties {
        bool canBurn;
        bool canMint;
        bool hasMaxTotalSupply;
        bool hasTaxFee;
        bool hasBurnFee;
        bool hasRewardFee;
        bool changeOwner;
        bool hasDocument;
        bool hasTokenLimit;
    }

    struct ContractParams {
        uint256 initialSupply;
        uint8 decimals;
        uint256 maxTotalSupply;
        address taxRecipient;
        uint256 taxFeeBPS;
        uint256 burnFeeBPS;
        uint256 rewardsFeeBPS;
        address tokenOwner;
        string document;
        uint256 tokenLimit;
    }

    /* -------------- Constants ------------ */
    uint256 private constant MAX_ALLOWED_BPS = 2_000;

    /* -------------- Errors ------------ */
    error InvalidTotalBPS(uint256 totalBPS);
    error InvalidMaxSupplyConfig(uint256 maxSupply);
    error InvalidTokenLimit(uint256 amount);
    error InvalidReflectiveConfig();
    error DestBalanceExceedsMaxAllowed(address to, uint256 balance);
    error TotalSupplyExceedsMax();

    /* -------------- Events ------------ */
    event TokenLimitPerAccountSet(uint256 newLimit);
    event MaxTotalSupplyChanged(uint256 newSupply);
    event TaxConfigChanged(address newTaxReciptient, uint256 newTaxFee);
    event BurnFeeSet(uint256 newBurnFee);

    ContractProperties public properties;
    uint256 public maxTotalSupply;
    address public taxRecipient;
    uint256 public taxFeeBPS;

    uint256 public burnFeeBPS;
    string public document;
    uint256 public tokenLimit;

    constructor (
        string memory _name,
        string memory _symbol,
        ContractProperties memory _properties,
        ContractParams memory _params
    ) ReflectiveERC20(
        _name, _symbol,
        msg.sender,
        _params.initialSupply,
        _params.decimals,
        _params.rewardsFeeBPS,
        _properties.hasRewardFee
      )
      Ownable(msg.sender)
    {
        properties = _properties;

        // Perform necessary assignments.
        if (properties.hasMaxTotalSupply) {
            maxTotalSupply = _params.maxTotalSupply;
        }
        if (properties.hasTaxFee) {
            taxRecipient = _params.taxRecipient;
            taxFeeBPS = _params.taxFeeBPS;
        }
        if (properties.hasBurnFee) {
            burnFeeBPS = _params.burnFeeBPS;
        }
        if (properties.hasDocument) {
            document = _params.document;
        }
        if (properties.hasTokenLimit) {
            tokenLimit = _params.tokenLimit;
        }
        if (properties.changeOwner) {
            require(_params.tokenOwner != msg.sender, "If setting a new owner, it has to be different than the sender");

            super.transferOwnership(_params.tokenOwner);
        } else {
            // We add this on consturction which allows change of ownership
            // without needing the changeOwner property.
            if (_params.tokenOwner != ZERO_ADDRESS && _params.tokenOwner != msg.sender) {
                super.transferOwnership(_params.tokenOwner);
            }
        }

        // Perform various checks to make sure the data is
        // consistent and abides by certain rules.
        // Check that the token limit is set to a value higher than 0 if it is set.
        if (properties.hasTokenLimit) {
            if (tokenLimit == 0) {
                revert InvalidTokenLimit(tokenLimit);
            }
        }
        if (properties.hasMaxTotalSupply && !properties.canMint && (_params.maxTotalSupply > _params.initialSupply)) {
            revert InvalidMaxSupplyConfig(_params.maxTotalSupply);
        }
        // reflection feature can't be used in combination with burning/minting/deflation
        // or reflection config is invalid if no reflection BPS amount is provided
        if (properties.hasRewardFee &&
            (properties.canBurn || properties.canMint || properties.hasBurnFee ||(_params.rewardsFeeBPS == 0) || (_params.initialSupply == 0))
        ) {
            revert InvalidReflectiveConfig();
        }
        // Check if we do not exceed maximum amount of BPS
        // in various fees.
        uint256    totalBPS = 0;

        if (properties.hasBurnFee) {
            totalBPS += burnFeeBPS;
        }
        if (properties.hasRewardFee) {
            totalBPS += rewardsFeeBPS;
        }
        if (properties.hasTaxFee) {
            totalBPS += taxFeeBPS;
        }
        if (totalBPS > MAX_ALLOWED_BPS) {
            revert InvalidTotalBPS(totalBPS);
        }
    }

    /* ----------------------- Getter Methods ------------------------- */

    /// @return All of the token's propert flags
    function getProperties() public view returns (ContractProperties memory) {
        return properties;
    }

    /// @notice Checks if the token is mintable
    /// @return True if the token can be minted
    function isMintable() public view returns (bool) {
        return properties.canMint;
    }

    /// @notice Checks if the token is burnable
    /// @return True if the token can be burned
    function isBurnable() public view returns (bool) {
        return properties.canBurn;
    }

    /// @notice Checks if the maximum amount of tokens per address is set
    /// @return True if there is a maximum limit for token amount per address
    function isTokenLimitSet() public view returns (bool) {
        return properties.hasTokenLimit;
    }

    /// @notice Checks if the maximum amount of token supply is set
    /// @return True if there is a maximum limit for token supply
    function isMaxSupplySet() public view returns (bool) {
        return properties.hasMaxTotalSupply;
    }

    /// @notice Checks if setting a document URI is allowed
    /// @return True if setting a document URI is allowed
    function isDocumentAllowed() public view returns (bool) {
        return properties.hasDocument;
    }

    /// @notice Checks if the token is taxable
    /// @return True if the token has tax applied on transfers
    function isTaxable() public view returns (bool) {
        return properties.hasTaxFee;
    }

    /// @notice Checks if the token is deflationary
    /// @return True if the token has deflation applied on transfers
    function isDeflationary() public view returns (bool) {
        return properties.hasBurnFee;
    }

    /// @notice Checks if the token is reflective
    /// @return True if the token has reflection (ie. holder rewards) applied on transfers
    function isReflective() public view returns (bool) {
        return properties.hasRewardFee;
    }

    /* ----------------------- Setter Methods ------------------------- */

    function setDocument(string memory _document) external onlyOwner {
        require (properties.hasDocument, "The contract doesn't offer the ability to set or change a document");
        require (bytes(_document).length > 0, "The document string must have content");

        document = _document;
    }

    function setRewardsFee(uint256 _rewardsFeeBPS) external onlyOwner {
        require(properties.hasRewardFee, "The contract doesn't offer the ability to set a reward fee");

        uint256 totalBPS = burnFeeBPS + _rewardsFeeBPS + taxFeeBPS;
        if (totalBPS > MAX_ALLOWED_BPS) {
            revert InvalidTotalBPS(totalBPS);
        }
        _setRewardsFee(_rewardsFeeBPS);
    }

    function setTokenLimit(uint256 _newTokenLimit) external onlyOwner {
        require(properties.hasTokenLimit, "The contract doesn't offer the ability to set a token limit");
        require(_newTokenLimit <= tokenLimit, "New token limit must be same or higher than previous limit");

        tokenLimit = _newTokenLimit;
        emit TokenLimitPerAccountSet(_newTokenLimit);
    }

    function setMaxTotalSupply(uint256 _newMaxSupply) external onlyOwner {
        require(properties.hasMaxTotalSupply, "This contract does not have a total supply definition capability");
        require(_newMaxSupply > maxTotalSupply, "The new supply must be larger than the old one");

        maxTotalSupply = _newMaxSupply;
        emit MaxTotalSupplyChanged(_newMaxSupply);
    }

    /// @notice Sets a new tax configuration
    /// @dev Can only be called by the contract owner
    /// @param _taxRecipient The address where tax will be sent
    /// @param _taxFeeBPS The tax rate in basis points
    function setTaxConfig(address _taxRecipient, uint256 _taxFeeBPS) external onlyOwner {
        require(properties.hasTaxFee, "This contract does not have a tax fee capability");
        require(_taxRecipient != ZERO_ADDRESS, "The recipient address can't be zero");

        uint256 totalBPS = burnFeeBPS + rewardsFeeBPS + taxFeeBPS;
        if (totalBPS > MAX_ALLOWED_BPS) {
            revert InvalidTotalBPS(totalBPS);
        }
        taxRecipient = _taxRecipient;
        taxFeeBPS = _taxFeeBPS;
        emit TaxConfigChanged(_taxRecipient, _taxFeeBPS);
    }

    /// @notice Sets a new deflation configuration
    /// @dev Can only be called by the contract owner
    /// @param _newBurnFeeBPS The deflation rate in basis points
    function setBurnFee(uint256 _newBurnFeeBPS) external onlyOwner {
        require(properties.hasBurnFee, "This contract does not have a burn fee capabilty");

        uint256 totalBPS = _newBurnFeeBPS + taxFeeBPS + rewardsFeeBPS;
        if (totalBPS > MAX_ALLOWED_BPS) {
            revert InvalidTotalBPS(totalBPS);
        }
        burnFeeBPS = _newBurnFeeBPS;
        emit BurnFeeSet(_newBurnFeeBPS);
    }

    /// @notice Transfers tokens to a specified address
    /// @dev Overrides the ERC20 transfer function with added tax and deflation logic
    /// @param _to The address to transfer tokens to
    /// @param _amount The amount of tokens to be transferred
    /// @return True if the transfer was successful
    function transfer(address _to, uint256 _amount) public virtual override returns (bool) {
        uint256 taxAmount = _taxAmount(msg.sender, _amount);
        uint256 deflationAmount = _deflationAmount(_amount);
        uint256 amountToTransfer = _amount - taxAmount - deflationAmount;

        if (isTokenLimitSet()) {
            uint256 balance = balanceOf(_to);

            if (balance + amountToTransfer > tokenLimit) {
                revert DestBalanceExceedsMaxAllowed(_to, balance);
            }
        }

        if (taxAmount != 0) {
            super._transferNonReflectedTax(msg.sender, taxRecipient, taxAmount);
        }
        if (deflationAmount != 0) {
            super._reflectiveBurn(msg.sender, deflationAmount);
        }
        return super.transfer(_to, amountToTransfer);
    }

    /// @notice Transfers tokens from one address to another
    /// @dev Overrides the ERC20 transferFrom function with added tax and deflation logic
    /// @param _from The address which you want to send tokens from
    /// @param _to The address which you want to transfer to
    /// @param _amount The amount of tokens to be transferred
    /// @return True if the transfer was successful
    function transferFrom(address _from, address _to, uint256 _amount) public virtual override returns (bool) {
        uint256 taxAmount = _taxAmount(_from, _amount);
        uint256 deflationAmount = _deflationAmount(_amount);
        uint256 amountToTransfer = _amount - taxAmount - deflationAmount;

        if (isTokenLimitSet()) {
            uint256 balance = balanceOf(_to);

            if (balance + amountToTransfer > tokenLimit) {
                revert DestBalanceExceedsMaxAllowed(_to, balance);
            }
        }

        if (taxAmount != 0) {
            super._transferNonReflectedTax(_from, taxRecipient, taxAmount);
        }
        if (deflationAmount != 0) {
            super._reflectiveBurn(_from, deflationAmount);
        }

        return super.transferFrom(_from, _to, amountToTransfer);
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public override virtual onlyOwner {
        require(properties.changeOwner, "This contract doesn't have the capability to change owners");

        super.renounceOwnership();
    }

    /**
     * This function really just checks if we enabled the capability to transfer ownership on the contract.
     */
    function transferOwnership(address _newOwner) public virtual override onlyOwner {
        require(properties.changeOwner, "This contract doesn't have the capability to change owners");

        super.transferOwnership(_newOwner);
    }

    /// @notice Mints new tokens to a specified address
    /// @dev Can only be called by the contract owner and if minting is enabled
    /// @param _to The address to mint tokens to
    /// @param _amount The amount of tokens to mint
    function mint(address _to, uint256 _amount) external onlyOwner {
        if (!isMintable()) {
            revert MintingNotEnabled();
        }
        if (isTokenLimitSet()) {
            uint256 balance = balanceOf(_to);
            if (balance + _amount > tokenLimit) {
                revert DestBalanceExceedsMaxAllowed(_to, balance);
            }
        }
        if (isMaxSupplySet()) {
            if (totalSupply() + _amount > maxTotalSupply) {
                revert TotalSupplyExceedsMax();
            }
        }

        super._reflectiveMint(_to, _amount);
    }

    /// @notice Burns a specific amount of tokens
    /// @dev Can only be called by the contract owner and if burning is enabled
    /// @param _amount The amount of tokens to be burned
    function burn(uint256 _amount) external onlyOwner {
        if (!isBurnable()) {
            revert BurningNotEnabled();
        }
        super._reflectiveBurn(msg.sender, _amount);
    }

    /// @notice Calculates the tax amount for a transfer
    /// @param _sender The address initiating the transfer
    /// @param _amount The amount of tokens being transferred
    /// @return taxAmount The calculated tax amount
    function _taxAmount(address _sender, uint256 _amount) internal view returns (uint256 taxAmount) {
        taxAmount = 0;
        if (taxFeeBPS != 0 && _sender != taxRecipient) {
            taxAmount = (_amount * taxFeeBPS) / BPS_DIVISOR;
        }
    }

    /// @notice Calculates the deflation amount for a transfer
    /// @param _amount The amount of tokens being transferred
    /// @return deflationAmount The calculated deflation amount
    function _deflationAmount(uint256 _amount) internal view returns (uint256 deflationAmount) {
        deflationAmount = 0;
        if (rewardsFeeBPS != 0) {
            deflationAmount = (_amount * rewardsFeeBPS) / BPS_DIVISOR;
        }
    }
}