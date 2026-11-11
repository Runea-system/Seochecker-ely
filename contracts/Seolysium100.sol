// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title SEOLYSIUM 100 — 100 engraved-gold NFT editions from SEOLysium (HyperEVM)
/// @notice Flat public mint: exactly 0.1 HYPE per token, sequential IDs 1..100.
///         Metadata: baseURI + tokenId + ".json" (https://seocheckr.xyz/nft/metadata/)
contract Seolysium100 {
    string public constant name = "SEOLYSIUM 100";
    string public constant symbol = "SEO100";
    uint256 public constant MAX_SUPPLY = 100;
    uint256 public constant PRICE = 0.1 ether; // 0.1 HYPE, immutable by design
    uint256 public constant MAX_PER_TX = 20;

    address public owner;
    string public baseURI;
    bool public mintOpen;
    uint256 public totalMinted;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed tokenOwner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed tokenOwner, address indexed operator, bool approved);
    event MintOpenChanged(bool open);
    event BaseURIChanged(string newBaseURI);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(string memory baseURI_) {
        owner = msg.sender;
        baseURI = baseURI_;
    }

    // ---------- ERC-165 ----------
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC165
            || interfaceId == 0x80ac58cd // ERC721
            || interfaceId == 0x5b5e139f; // ERC721Metadata
    }

    // ---------- Views ----------
    function balanceOf(address account) public view returns (uint256) {
        require(account != address(0), "Zero address");
        return _balances[account];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address a = _owners[tokenId];
        require(a != address(0), "Nonexistent token");
        return a;
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        require(_owners[tokenId] != address(0), "Nonexistent token");
        return string(abi.encodePacked(baseURI, _toString(tokenId), ".json"));
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        require(_owners[tokenId] != address(0), "Nonexistent token");
        return _tokenApprovals[tokenId];
    }

    function isApprovedForAll(address account, address operator) public view returns (bool) {
        return _operatorApprovals[account][operator];
    }

    // ---------- Mint ----------
    function mint(uint256 qty) external payable {
        require(mintOpen, "Mint closed");
        require(qty >= 1 && qty <= MAX_PER_TX, "Qty 1-20");
        require(totalMinted + qty <= MAX_SUPPLY, "Sold out");
        require(msg.value == PRICE * qty, "Pay exact 0.1 HYPE each");
        for (uint256 i = 0; i < qty; i++) {
            totalMinted++;
            uint256 tokenId = totalMinted;
            _owners[tokenId] = msg.sender;
            _balances[msg.sender]++;
            emit Transfer(address(0), msg.sender, tokenId);
        }
    }

    // ---------- Transfers ----------
    function approve(address approved, uint256 tokenId) external {
        address tokenOwner = ownerOf(tokenId);
        require(msg.sender == tokenOwner || _operatorApprovals[tokenOwner][msg.sender], "Not authorized");
        _tokenApprovals[tokenId] = approved;
        emit Approval(tokenOwner, approved, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not authorized");
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        transferFrom(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, ""), "Receiver rejected");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) external {
        transferFrom(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "Receiver rejected");
    }

    // ---------- Owner ----------
    function setMintOpen(bool open_) external onlyOwner {
        mintOpen = open_;
        emit MintOpenChanged(open_);
    }

    function setBaseURI(string memory newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
        emit BaseURIChanged(newBaseURI);
    }

    function withdraw() external onlyOwner {
        uint256 amount = address(this).balance;
        require(amount > 0, "Nothing to withdraw");
        (bool ok, ) = payable(owner).call{value: amount}("");
        require(ok, "Withdraw failed");
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        owner = newOwner;
    }

    // ---------- Internals ----------
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address tokenOwner = ownerOf(tokenId);
        return spender == tokenOwner
            || _tokenApprovals[tokenId] == spender
            || _operatorApprovals[tokenOwner][spender];
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "From not owner");
        require(to != address(0), "Zero address");
        delete _tokenApprovals[tokenId];
        _balances[from]--;
        _balances[to]++;
        _owners[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) private returns (bool) {
        if (to.code.length == 0) return true;
        try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
            return retval == IERC721Receiver.onERC721Received.selector;
        } catch {
            return false;
        }
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) { digits++; temp /= 10; }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}
