pragma solidity ^0.4.24;


contract EcommerceStore {
    
    //把商品添加到商店的业务分析：
    
    // 1. 定义商品结构
    // 2. 每个商品有一个唯一的id，数字，每添加一个商品，id++
    // 3. 需要有一个存储所有商品的结构， 通过id可以的到对应的商品
    // 4. 添加商品的方法
    
    uint public productIndex;  //每一个产品都有自己的id
    
    struct Product {
        //基础信息
        uint id;
        string name;
        string category;
        string imageLink;
        string descLink;

        uint startPrice;
        uint auctionStartTime;
        uint auctionEndTime;

        ProductStatus status; 
        ProductCondition condition;
        
        
        //竞标信息
        uint highestBid;   //最高出价, 50，理想价格
        address highestBidder; //最高出价人
        uint secondHighestBid; //次高价，40
        uint totalBids; //所有的竞标数量
        
        // 存储所有的竞标人对这个商品的竞标（与stroes类似）
        mapping(address => mapping(bytes32 => Bid)) bids;
        
    }

    enum ProductStatus {Open, Sold, Unsold} //竞标中，卖了，没卖出
    enum ProductCondition {Used, New} ////新的，旧的
    
    
    mapping(address => mapping(uint => Product)) stores;
    mapping(uint => address) productIdToOwner;
    
    
    function addProductToStore(string _name, string _category, string _imageLink, string _descLink, uint _startTime, uint _endTime, uint _startPrice, uint condition) public {
        productIndex++;
        
        Product memory product = Product({
            id : productIndex,
            name : _name,
            category : _category,
            imageLink : _imageLink,
            descLink : _descLink,
            
            startPrice : _startPrice,
            auctionStartTime : _startTime,
            auctionEndTime : _endTime,
    
            status : ProductStatus.Open,
            condition : ProductCondition(condition),
            
            //++++++++++++
            highestBid: 0,
            highestBidder : 0,
            secondHighestBid : 0,
            totalBids : 0
            
            });
            
        //把创建好的商品添加到我们的商店结构中
        stores[msg.sender][productIndex] = product;
        productIdToOwner[productIndex] = msg.sender;
    }
    
    
    function getProductById(uint _productId) public view returns (uint, string, string, string, string, uint, uint, uint, uint){
        
        address owner = productIdToOwner[_productId];
        Product memory product = stores[owner][_productId];
        
        return (
            product.id, product.name, product.category, product.imageLink, product.descLink,
            product.auctionStartTime, product.auctionEndTime, product.startPrice, uint(product.status)
        );
    }
    
    
    // 竞标的结构：
    // 	1. 产品ID
    // 	2. 转账（迷惑）价格，注意，不是理想价格
    // 	3. 揭标与否
    // 	4. 竞标人

    struct Bid {
        uint productId;
        uint price;
        bool isRevealed;
        address bidder;
    }

    
    // function bid(uint _productId, uint _idealPrice, string _secret) public payable {
    function bid(uint _productId, bytes32 bytesHash) public payable {
        
        // bytes memory bytesInfo = abi.encodePacked(_idealPrice, _secret);
        // bytes32 bytesHash = keccak256(bytesInfo);
        
        address owner = productIdToOwner[_productId];
        Product storage product = stores[owner][_productId];
        
        //每一个竞标必须大于等于起始价格
        require(msg.value >= product.startPrice);
        
        product.totalBids++;
        
        Bid memory bidLocal = Bid(_productId, msg.value, false, msg.sender);
        product.bids[msg.sender][bytesHash] = bidLocal; 
    }
    
    function testHash(uint256 _idealPrice, string _secret) public pure returns(bytes32) {
        bytes memory bytesInfo = abi.encodePacked(_idealPrice, _secret);
        bytes32 bytesHash = keccak256(bytesInfo);
        return bytesHash;
    }
    
    //获取指定的bid信息
    function getBidById(uint _productId, uint _idealPrice, string _secret) public view returns (uint, uint, bool, address) {
       
        //Product storage product = stores[productIdToOwner[_productId]][_productId];
        address owner = productIdToOwner[_productId];
        Product storage product = stores[owner][_productId];
        
        bytes memory bytesInfo = abi.encodePacked(_idealPrice, _secret);
        bytes32 bytesHash = keccak256(bytesInfo);

        Bid memory bidLocal = product.bids[msg.sender][bytesHash];
        return (bidLocal.productId, bidLocal.price, bidLocal.isRevealed, bidLocal.bidder);
    }
    
    function getBalance() public view returns (uint){
        return address(this).balance;
    }
    
    
    event revealEvent(uint productid, bytes32 bidId, uint idealPrice, uint price, uint refund);
    
    function revealBid(uint _productId, uint _idealPrice, string _secret) public {
       
        address owner = productIdToOwner[_productId];
        Product storage product = stores[owner][_productId];
        
        bytes memory bytesInfo = abi.encodePacked(_idealPrice, _secret);
        bytes32 bidId = keccak256(bytesInfo);
        
        //mapping(address => mapping(bytes32 => Bid)) bids;
        
        //一个人可以对同一个商品竞标多次，揭标的时候也要揭标多次, storage类型
        Bid storage currBid = product.bids[msg.sender][bidId];
        
       //require(now > product.auctionStartTime);
       //每个标只能揭标一次
        require(!currBid.isRevealed);
        
        require(currBid.bidder != address(0));  //说明找到了这个标， 找到了正确的标

        currBid.isRevealed = true;

        //bid中的是迷惑价格，真实价格揭标时传递进来
        uint confusePrice = currBid.price;

        //退款金额， 程序最后，统一退款
        uint refund = 0;
        
        uint idealPrice = _idealPrice;
        
        if (confusePrice < idealPrice) {
            //路径1：无效交易
            refund = confusePrice;
        } else {
            if (idealPrice > product.highestBid) {
                if (product.highestBidder == address(0)) {
                    //当前账户是第一个揭标人
                    //路径2：
                    product.highestBidder = msg.sender;
                    product.highestBid = idealPrice;
                    product.secondHighestBid = product.startPrice;
                    refund = confusePrice - idealPrice;
                } else {
                    //路径3：不是第一个，但是出价是目前最高的，更新最高竞标人，最高价格，次高价格
                    product.highestBidder.transfer(product.highestBid);
                    product.secondHighestBid = product.highestBid;
                    
                    product.highestBid = idealPrice; //wangwu 40
                    product.highestBidder = msg.sender; //wangwu
                    refund = confusePrice - idealPrice; //10
                }
            } else {
                //路径4：价格低于最高价，但是高于次高价
                if (idealPrice > product.secondHighestBid) {
                    //路径4：更新次高价，然后拿回自己的钱
                    product.secondHighestBid = idealPrice;
                    refund = confusePrice; //40
                
                } else {
                    //路径5：路人甲，价格低于次高价，直接退款
                    refund = confusePrice;
                }
            }
        }

        emit revealEvent(_productId, bidId, confusePrice, currBid.price, refund);

        if (refund > 0) {
            msg.sender.transfer(refund);
        }
    }
    
    
    function getHighestBidInfo(uint _productId) public view returns(address, uint, uint, uint) {
        address owner = productIdToOwner[_productId];
        Product memory product = stores[owner][_productId];
        
        return (product.highestBidder, product.highestBid, product.secondHighestBid, product.totalBids);
    }
    
    
    //key是产品id，value：是第三方合约
    //全局唯一， 用于投票时，找到这个第三方合约。
	mapping(uint => address) public productToEscrow;
    
    function finalaizeAuction(uint _productId) public {
        
        address owner = productIdToOwner[_productId];
        Product storage product = stores[owner][_productId];
        
        address buyer = product.highestBidder; //买家
        address seller = owner;//卖家
        address arbiter = msg.sender; //仲裁人
        
        //仲裁人不允许是买家或者卖家
        require(arbiter != buyer && arbiter != seller);
        
        //限定仅在揭标之后才可以进行仲裁
        //require(now > product.auctionEndTime);

        require(product.status == ProductStatus.Open); //Open, Sold, Unsold

        //如果竞标了，但是没有揭标，那么也是没有卖出去(自行拓展)
        if (product.totalBids == 0) {
            product.status = ProductStatus.Unsold;
        } else {
            product.status = ProductStatus.Sold;
        }
        
		//.value()方式进行外部调用时转钱
        //类比feed.info.value(10).gas(800)(); 
        //这是构造的时候传钱，constructor加上payable关键字
        
	    //address escrow = (new Escrow).value(25)(buyer, seller, arbiter)
        address escrow = (new Escrow).value(product.secondHighestBid)(buyer, seller, arbiter);
        
        productToEscrow[_productId] = escrow;
        
        //退还差价 30- 25 = 5 ， 30是理想出价，25是次高
        buyer.transfer(product.highestBid - product.secondHighestBid);
    }
    
    
    function getEscrowInfo(uint _productId) public view returns (address, address, address, uint, uint, uint256) {
        address escrow = productToEscrow[_productId];
        Escrow instanceContract = Escrow(escrow);
        
        return instanceContract.escrowInfo();
    }

    function giveToSeller(uint _productId) public {
        address contract1 = productToEscrow[_productId];
        Escrow(contract1).giveMoneyToSeller(msg.sender); //把调用人传给Escrow合约
    }

    function giveToBuyer(uint _productId) public {
        Escrow(productToEscrow[_productId]).giveMoneyToBuyer(msg.sender);
    }
}

//++++++++++++++++++++++++++++++++++++++++++//++++++++++++++++++++++++++++++++++++++++++


contract Escrow {

    // 属性：
    // 1. 买家
    address  buyer;
    // 2. 卖家
    address  seller;
    // 3. 仲裁人
    address  arbiter;
    
    
    // 4. 卖家获得的票数
    uint sellerVotesCount;
    // 5. 买家获得的票数
    uint buyerVotesCount;
    
    // 6. 标记某个地址是否已经投票
    mapping(address => bool) addressVotedMap;

    // 7. 是否已经完成付款了
    bool isSpent = false;
    

    constructor(address _buyer, address _seller, address _arbiter) public payable {
        buyer = _buyer;
        seller = _seller;
        arbiter = _arbiter;
    }
    
        // 方法：
    //向卖家投票方法
    function giveMoneyToSeller(address caller)  callerRestrict(caller) public {
        require(!isSpent);
        
        //记录已经投票的状态，如果投过票，就设置为true
        require(!addressVotedMap[caller]);
        addressVotedMap[caller] = true; //address => bool
        
        //sellerVotesCount++;
        if (++sellerVotesCount == 2 ) {
            isSpent = true;
            seller.transfer(address(this).balance);
        }
    }

    //向买家投票方法
    function giveMoneyToBuyer(address caller) callerRestrict(caller) public {
        require(!isSpent);
        require(!addressVotedMap[caller]);
        addressVotedMap[caller] = true;

        if (++buyerVotesCount == 2) {
            isSpent = true;
            buyer.transfer(address(this).balance);
        }
    }
    
    
    function escrowInfo() public view returns(address, address, address, uint, uint, uint256) {
        uint256 balance = getEscrowBalance();
        return (buyer, seller, arbiter, buyerVotesCount, sellerVotesCount, balance);
    }
    
    
    
    modifier callerRestrict(address caller ) {
        require(caller == seller || caller == buyer || caller == arbiter);
        _;
    }
    
    
    function getEscrowBalance() public view returns(uint256) {
        return address(this).balance;
    }
}



