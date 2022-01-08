/* SPDX-License-Identifier: UNLICENSED */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OrderbookDEX is Ownable {
    using SafeMath for uint256;

    // Buy and sell actions
    enum Action {
        BUY,
        SELL
    }

    // The basic information of a trading order
    struct Order {
        uint256 id;
        address owner;
        Action action;
        address currency;
        uint256 amount;
        uint256 filled;
        uint256 price;
        uint256 timestamp;
    }

    // We use USDT, which is a stable coin, as an intermediary currency to trade other currencies
    address public USDT;

    // The IDs of orders are count up by 1 per order
    uint256 public nextOrderId;

    // Only supported currencies (except for USDT) are allowed to trade
    address[] public supportedCurrencies;

    // Mapping from the currency to its current price which is calculated based on Orderbook Algorithm
    mapping(address => uint256) public currentPriceOf;

    // Mapping from the trader address to the balance of his specific currency
    mapping(address => mapping(address => uint256)) private _balanceOf;

    // Mapping from the currency to its orders which are currently available in the orderbook
    mapping(address => mapping(uint8 => Order[])) private _orderbook;

    // Mapping from the currency to its states (supported or not)
    mapping(address => bool) private _isCurrencySupported;

    // Only operators are allowed to setup the supported currencies
    mapping(address => bool) private _operators;

    /**
     * @dev Emitted when an order whose ID is `orderId` is partially or fully matched.
     */
    event OrderMatched(
        uint256 orderId,
        address indexed currency,
        address indexed buyer,
        address indexed seller,
        uint256 amount,
        uint256 price,
        uint256 timestamp
    );

    /**
     * @dev Initializes the contract by setting a USDT address and some initial states.
     */
    constructor(address usdtToken) Ownable() {
        USDT = usdtToken;
        _isCurrencySupported[usdtToken] = true;
        _operators[msg.sender] = true;
        nextOrderId = 0;
    }

    /**
     * @dev Only operators are allowed to do something.
     */
    modifier onlyOperator() {
        require(_operators[msg.sender], "Caller is not operator");
        _;
    }

    /**
     * @dev Only supported currencies (except for USDT) are allowed to trade.
     */
    modifier tradable(address currency) {
        require(_isCurrencySupported[currency], "Currency not supported");
        require(currency != USDT, "USDT cannot be traded");
        _;
    }

    /**
     * @dev Trader can only deposit and withdraw supported currencies.
     */
    modifier isSupported(address currency) {
        require(_isCurrencySupported[currency], "Currency not supported");
        _;
    }

    /**
     * @dev Returns the available orders of a specific `currency`
     * corresponding to a specific `action` (buy or sell).
     */
    function getOrders(address currency, Action action)
        external
        view
        returns (Order[] memory)
    {
        return _orderbook[currency][uint8(action)];
    }

    /**
     * @dev Returns the number of supported currencies.
     */
    function getNumSupportedCurrencies() external view returns (uint256) {
        return supportedCurrencies.length;
    }

    /**
     * @dev Returns the `currency` balance of a `trader`.
     */
    function getBalance(address trader, address currency)
        external
        view
        returns (uint256)
    {
        return _balanceOf[trader][currency];
    }

    /**
     * @dev The owner of this contract can decide who will be operators.
     *
     * Requirements:
     *
     * - Only the owner of this contract can do this.
     */
    function setOperator(address operator, bool isOperator) external onlyOwner {
        _operators[operator] = isOperator;
    }

    /**
     * @dev Set a currency status as supported
     */
    function setCurrency(address currency) external onlyOperator {
        supportedCurrencies.push(currency);
        _isCurrencySupported[currency] = true;
    }

    /**
     * @dev Allows traders to deposit their tokens to this contract.
     *
     * Requirements:
     *
     * - `currency` must be supported
     *
     * Emits a {Transfer} event.
     */
    function deposit(address currency, uint256 amount)
        external
        isSupported(currency)
    {
        IERC20(currency).transferFrom(msg.sender, address(this), amount);
        _balanceOf[msg.sender][currency] = _balanceOf[msg.sender][currency].add(
            amount
        );
    }

    /**
     * @dev Allows the traders to withdraw their tokens from this contract.
     *
     * Requirements:
     *
     * - `currency` must be supported.
     * - `amount` must be enough to withdraw.
     *
     * Emits a {Transfer} event.
     */
    function withdraw(address currency, uint256 amount)
        external
        isSupported(currency)
    {
        require(
            _balanceOf[msg.sender][currency] >= amount,
            "Not enough balance to withdraw"
        );
        _balanceOf[msg.sender][currency] = _balanceOf[msg.sender][currency].sub(
            amount
        );
        IERC20(currency).transfer(msg.sender, amount);
    }

    /**
     * @dev Allows the traders to place a buy order, which will be matched
     * immediately when there is a suitable sell order. The information of
     * the buy order he places must include `currency`, `amount` he wants to
     * buy and the `price` he desires.
     *
     * Requirements:
     *
     * - `currency` must be supported and tradable.
     * - The USDT balance of this trader must be enough to buy tokens.
     *
     * Emits an {OrderMatched} event.
     */
    function placeBuyOrder(
        address currency,
        uint256 amount,
        uint256 price
    ) external tradable(currency) {
        // Check if this trader has enough amount to place this buy order
        require(
            _balanceOf[msg.sender][USDT] >= amount.mul(price),
            "Not enough USDT to buy"
        );

        // Check sell orders and match if possible
        Order[] storage sellOrders = _orderbook[currency][uint8(Action.SELL)];
        uint256 remaining = amount;
        uint256 i = 0;
        for (i = 0; i < sellOrders.length; i++) {
            if (sellOrders[i].price > price) break;
            uint256 available = sellOrders[i].amount.sub(sellOrders[i].filled);
            uint256 matched = (remaining > available) ? available : remaining;
            remaining = remaining.sub(matched);
            sellOrders[i].filled = sellOrders[i].filled.add(matched);
            emit OrderMatched(
                sellOrders[i].id,
                currency,
                msg.sender,
                sellOrders[i].owner,
                matched,
                price,
                block.timestamp
            );

            // Update the balances of a buyer and a seller
            _balanceOf[msg.sender][currency] = _balanceOf[msg.sender][currency]
                .add(matched);
            _balanceOf[msg.sender][USDT] = _balanceOf[msg.sender][USDT].sub(
                matched.mul(price)
            );
            _balanceOf[sellOrders[i].owner][currency] = _balanceOf[
                sellOrders[i].owner
            ][currency].sub(matched);
            _balanceOf[sellOrders[i].owner][USDT] = _balanceOf[
                sellOrders[i].owner
            ][USDT].add(matched.mul(price));
            if (remaining == 0) break;
        }

        // Check whether the current sell order is fully filled or not
        if (
            i < sellOrders.length &&
            sellOrders[i].filled == sellOrders[i].amount
        ) i++;

        // Remove all fully filled sell orders
        if (i > 0)
            for (uint256 j = i; j < sellOrders.length; j++)
                sellOrders[j - i] = sellOrders[j];
        for (uint256 j = 0; j < i; j++) sellOrders.pop();

        // If there is still some remaining, create a new buy order for future match
        if (remaining > 0) {
            Order[] storage buyOrders = _orderbook[currency][uint8(Action.BUY)];

            // Append the new order at the end of buy order list
            buyOrders.push(
                Order(
                    nextOrderId,
                    msg.sender,
                    Action.BUY,
                    currency,
                    amount,
                    amount.sub(remaining),
                    price,
                    block.timestamp
                )
            );

            // Use insertion sort to sort buy order list price-decreasingly
            for (uint256 k = buyOrders.length - 1; k > 0; k--) {
                if (buyOrders[k - 1].price > buyOrders[k].price) break;
                Order memory order = buyOrders[k - 1];
                buyOrders[k - 1] = buyOrders[k];
                buyOrders[k] = order;
            }
            nextOrderId++;
        }

        // Update the current price of this token
        currentPriceOf[currency] = price;
    }

    /**
     * @dev Allows the traders to place a sell order, which will be matched
     * immediately when there is a suitable buy order. The information of
     * the sell order he places must include `currency`, `amount` he wants to
     * sell and the `price` he desires.
     *
     * Requirements:
     *
     * - `currency` must be supported and tradable.
     * - His `currency` balance must be enough to sell tokens.
     *
     * Emits an {OrderMatched} event.
     */
    function placeSellOrder(
        address currency,
        uint256 amount,
        uint256 price
    ) external tradable(currency) {
        // Check if this trader has enough amount to place this sell order
        require(
            _balanceOf[msg.sender][currency] >= amount,
            "Not enough amount to sell"
        );

        // Check buy orders and match if possible
        Order[] storage buyOrders = _orderbook[currency][uint8(Action.BUY)];
        uint256 remaining = amount;
        uint256 i = 0;
        for (i = 0; i < buyOrders.length; i++) {
            if (buyOrders[i].price < price) break;
            uint256 available = buyOrders[i].amount.sub(buyOrders[i].filled);
            uint256 matched = (remaining > available) ? available : remaining;
            remaining = remaining.sub(matched);
            buyOrders[i].filled = buyOrders[i].filled.add(matched);
            emit OrderMatched(
                buyOrders[i].id,
                currency,
                buyOrders[i].owner,
                msg.sender,
                matched,
                price,
                block.timestamp
            );

            // Update the balances of a buyer and a seller
            _balanceOf[msg.sender][currency] = _balanceOf[msg.sender][currency]
                .sub(matched);
            _balanceOf[msg.sender][USDT] = _balanceOf[msg.sender][USDT].add(
                matched.mul(price)
            );
            _balanceOf[buyOrders[i].owner][currency] = _balanceOf[
                buyOrders[i].owner
            ][currency].add(matched);
            _balanceOf[buyOrders[i].owner][USDT] = _balanceOf[
                buyOrders[i].owner
            ][USDT].sub(matched.mul(price));
            if (remaining == 0) break;
        }

        // Check whether the current buy order is fully filled or not
        if (i < buyOrders.length && buyOrders[i].filled == buyOrders[i].amount)
            i++;

        // Remove all fully filled buy orders
        if (i > 0)
            for (uint256 j = i; j < buyOrders.length; j++)
                buyOrders[j - i] = buyOrders[j];
        for (uint256 j = 0; j < i; j++) buyOrders.pop();

        // If there is still some remaining, create a new sell order for future match
        if (remaining > 0) {
            Order[] storage sellOrders = _orderbook[currency][
                uint8(Action.SELL)
            ];

            // Append the new order at the end of sell order list
            sellOrders.push(
                Order(
                    nextOrderId,
                    msg.sender,
                    Action.SELL,
                    currency,
                    amount,
                    amount.sub(remaining),
                    price,
                    block.timestamp
                )
            );

            // Use insertion sort to sort sell order list price-increasingly
            for (uint256 k = sellOrders.length - 1; k > 0; k--) {
                if (sellOrders[k - 1].price < sellOrders[k].price) break;
                Order memory order = sellOrders[k - 1];
                sellOrders[k - 1] = sellOrders[k];
                sellOrders[k] = order;
            }
            nextOrderId++;
        }

        // Update the current price of this token
        currentPriceOf[currency] = price;
    }

    /**
     * @dev Allows the owner of this contract to withdraw
     * all supported ERC20 tokens in case of emergency.
     *
     * Requirements:
     * - `recipient` mustnot be the zero address.
     *
     * Emits a {Transfer} event for each supported currency.
     */
    function emergencyWithdraw(address recipient) external onlyOwner {
        for (uint256 i = 0; i < supportedCurrencies.length; i++) {
            IERC20 tokenContract = IERC20(supportedCurrencies[i]);
            uint256 availableAmount = tokenContract.balanceOf(address(this));
            tokenContract.transfer(recipient, availableAmount);
        }
    }
}
