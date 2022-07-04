// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

interface IOwnable {
    function transferRootOwnership(address newOwner) external;
    function root() external view returns (address);
}
interface IManagerOwnable {
    function transferRootOwnership(address newOwner) external;
    function root() external view returns (address);
    function setManager(address manager, bool role) external;
    function isManager(address addr) external view returns(bool);
}

contract RootOwnable is IOwnable, Context {

    address _root;

    event RootOwnershipTransferred(address indexed oldRoot, address indexed newRoot);

    modifier onlyRoot {
        require(_root == _msgSender(), "caller is not root");
        _;
    }

    constructor() {
        _root = msg.sender;
    }

    function transferRootOwnership(address newOwner) public override onlyRoot {
        emit RootOwnershipTransferred(_root, newOwner);
        _root = newOwner;
    }

    function root() public override view returns (address) {
        return _root;
    }
}

contract ManagerOwnable is RootOwnable {

    mapping(address => bool) _managers;

    event ManagerChanged(address indexed manager, bool indexed role);

    modifier onlyManager {
        require(isManager(_msgSender()), "caller is not root or manager");
        _;
    }

    function setManager(address manager, bool role) public onlyRoot {
        require(_managers[manager] != role, "same role granted");

        emit ManagerChanged(manager, role);
        _managers[manager] = role;
    }

    function isManager(address addr) public view returns (bool) {
        return _managers[addr] || _root == addr;
    }
}

contract ManagerOwnableUpgradeable is Initializable, ContextUpgradeable {
    address public _root;

    event RootOwnershipTransferred(address indexed oldRoot, address indexed newRoot);

    modifier onlyRoot {
        require(_root == _msgSender(), "caller is not root");
        _;
    }

    function transferRootOwnership(address newOwner) public onlyRoot {
        emit RootOwnershipTransferred(_root, newOwner);
        _root = newOwner;
    }

    function root() public view returns (address) {
        return _root;
    }

    mapping(address => bool) _managers;

    event ManagerChanged(address indexed manager, bool indexed role);

    modifier onlyManager {
        require(isManager(_msgSender()), "caller is not root or manager");
        _;
    }

    function initialize() public virtual initializer {
        __Context_init();
        _root = _msgSender();
        _managers[_msgSender()] = true;
    }

    function setManager(address manager, bool role) public onlyRoot {
        require(_managers[manager] != role, "same role granted");

        emit ManagerChanged(manager, role);
        _managers[manager] = role;
    }

    function isManager(address addr) public view returns (bool) {
        return _managers[addr] || _root == addr;
    }
}
