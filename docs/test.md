
# &#30446;&#24405;

1.  [单元测试](#org01a0a10)
2.  [模糊测试](#orga8fba6b)
    1.  [合约分析](#org6b180bd)
        1.  [常数](#org041844b)
        2.  [状态](#org886ba3d)
        3.  [辅助状态和辅助合约](#orga5948ff)
        4.  [操作与断言](#org75ad00d)
        5.  [辅助操作与状态断言](#org4615681)
    2.  [初始化](#orgf2c1dda)



<a id="org01a0a10"></a>

# 单元测试

PNS和Controller合约以下内容通过单元测试进行验证：

1.  部署和升级
2.  外部函数的典型使用场景
3.  事件触发
4.  元交易

对于下列功能，假定功能正确，不做测试：

1.  ERC721、ERC2771等通过外部库提供的功能；
2.  supportsInterface函数；
3.  multicall函数；


<a id="orga8fba6b"></a>

# 模糊测试


<a id="org6b180bd"></a>

## 合约分析

实际使用时，一般是1个PNS合约和1个对应的Controller合约。考虑到Controller的升级，以及一些权限控制的测试，测试环境将部署1个PNS合约和2个Controller合约。因此，对于常数以及状态，需要区分不同的合约。下面描述的时候，在可能混淆的情况下，常数和变量的名称相对solidity源代码可能会增加前缀。


<a id="org041844b"></a>

### 常数

合约PNS包含以下常数：

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">名称</th>
<th scope="col" class="org-left">类型</th>
<th scope="col" class="org-left">说明</th>
</tr>
</thead>

<tbody>
<tr>
<td class="org-left">PNS_GRACE_PERIOD</td>
<td class="org-left">合约定义</td>
<td class="org-left">宽限期，360天</td>
</tr>
</tbody>
</table>

合约Controller包含以下常数：

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">名称</th>
<th scope="col" class="org-left">类型</th>
<th scope="col" class="org-left">说明</th>
</tr>
</thead>

<tbody>
<tr>
<td class="org-left">PNS</td>
<td class="org-left">构建时设置</td>
<td class="org-left">相应的PNS合约</td>
</tr>


<tr>
<td class="org-left">C*_BASE_NODE</td>
<td class="org-left">构建时设置</td>
<td class="org-left">基节点，相当于顶级域名</td>
</tr>
</tbody>
</table>

需要注意的是，不同的合约实例，“构建时设置”类型的常数对每个实例会有所不同。考虑到Controller相关联的PNS合约是同一个，因此没有加前缀，而BASE\_NODE可能不同，因此加C\*前缀，具体的可能是C0或C1。

测试涉及的合约，也是常数，PNS已经在上面提及了：

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">名称</th>
<th scope="col" class="org-left">类型</th>
<th scope="col" class="org-left">说明</th>
</tr>
</thead>

<tbody>
<tr>
<td class="org-left">C0</td>
<td class="org-left">构建时设置</td>
<td class="org-left">第一个Controller</td>
</tr>


<tr>
<td class="org-left">C1</td>
<td class="org-left">构建时设置</td>
<td class="org-left">第二个Controller</td>
</tr>
</tbody>
</table>

测试过程中，涉及到以下常数：

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">名称</th>
<th scope="col" class="org-left">说明</th>
</tr>
</thead>

<tbody>
<tr>
<td class="org-left">SENDER_POOL</td>
<td class="org-left">所有可能的调用者地址</td>
</tr>


<tr>
<td class="org-left">WORD_SET</td>
<td class="org-left">少量的词汇表，包括"dot", "org", "com", "net", "www", "hello", "pns"</td>
</tr>
</tbody>
</table>


<a id="org886ba3d"></a>

### 状态

PNS合约包括如下状态，其中“预置”表示合约在部署的时候会设定一个预置值：

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">名称</th>
<th scope="col" class="org-left">类型</th>
<th scope="col" class="org-left">初值</th>
<th scope="col" class="org-left">说明</th>
</tr>
</thead>

<tbody>
<tr>
<td class="org-left">_pns_mutable</td>
<td class="org-left">bool</td>
<td class="org-left">true</td>
<td class="org-left">PNS域名系统是否可变更</td>
</tr>
</tbody>

<tbody>
<tr>
<td class="org-left">_pns_root</td>
<td class="org-left">address</td>
<td class="org-left">预置</td>
<td class="org-left">PNS合约的超级用户</td>
</tr>


<tr>
<td class="org-left">_pns_manager_set</td>
<td class="org-left">ES(address)</td>
<td class="org-left">预置</td>
<td class="org-left">PNS合约的管理员表</td>
</tr>
</tbody>

<tbody>
<tr>
<td class="org-left">_pns_owner_tbl</td>
<td class="org-left">EM(uint256, address)</td>
<td class="org-left">预置</td>
<td class="org-left">ERC721的所有者表</td>
</tr>


<tr>
<td class="org-left">_pns_approve_tbl</td>
<td class="org-left">M(uint256, address)</td>
<td class="org-left">空</td>
<td class="org-left">ERC721授权表</td>
</tr>
</tbody>

<tbody>
<tr>
<td class="org-left">_pns_sld_expire_tbl</td>
<td class="org-left">EM(uint256, uint256)</td>
<td class="org-left">空</td>
<td class="org-left">二级域名有效期表</td>
</tr>


<tr>
<td class="org-left">_pns_sd_origin_tbl</td>
<td class="org-left">EM(uint256, uint256)</td>
<td class="org-left">空</td>
<td class="org-left">子域名（三级或以上）源域名表</td>
</tr>


<tr>
<td class="org-left">_pns_sd_parent_tbl</td>
<td class="org-left">M(uint256, uint256)</td>
<td class="org-left">空</td>
<td class="org-left">父域名表</td>
</tr>


<tr>
<td class="org-left">_pns_bound_set</td>
<td class="org-left">ES(uint256)</td>
<td class="org-left">空</td>
<td class="org-left">域名冻结集合</td>
</tr>
</tbody>

<tbody>
<tr>
<td class="org-left">_pns_info_link_tbl</td>
<td class="org-left">M(uint256, M(uint256, uint256))</td>
<td class="org-left">空</td>
<td class="org-left">域名链接表</td>
</tr>


<tr>
<td class="org-left">_pns_info_record_tbl</td>
<td class="org-left">M(uint256, M(uint256, string))</td>
<td class="org-left">空</td>
<td class="org-left">域名记录表</td>
</tr>


<tr>
<td class="org-left">_pns_info_name_tbl</td>
<td class="org-left">M(address, uint256)</td>
<td class="org-left">空</td>
<td class="org-left">地址（钱包、合约）解析</td>
</tr>


<tr>
<td class="org-left">_pns_info_nft_name_tbl</td>
<td class="org-left">M(address, M(uint256, uint256))</td>
<td class="org-left">空</td>
<td class="org-left">NFT代币解析</td>
</tr>
</tbody>

<tbody>
<tr>
<td class="org-left">_pns_key_tbl</td>
<td class="org-left">M(uint256, string)</td>
<td class="org-left">空</td>
<td class="org-left">辅助函数，用来反查哈希和字符串</td>
</tr>
</tbody>
</table>

合约状态分成几组，按上表顺序，依次如下：

-   可修改状态，用于控制PNS合约内部状态是否允许修改
-   合约权限管理
-   ERC721代币管理
-   域名元数据
-   单条域名关联数据，下面“己方域名”表示持有的或者有授权的域名代币
    -   link（链接），某条域名到其他域名的关系，数据关系是：己方域名 → 他方域名 → 值
    -   record（记录），某条域名关联的字符串到字符串的映射，数据关系是：己方域名 → 记录名称的哈希 → 记录值
    -   name（地址），将某个地址（钱包或合约）解析到域名，数据关系是：地址 → 己方域名
    -   nft\_name（NFT代币），将某个NFT代币解析到域名，数据关系是：NFT合约地址 → NFT编号 → 己方域名
-   字符串哈希表，用于通过哈希反查字符串

Controller合约包括如下状态：

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">名称</th>
<th scope="col" class="org-left">类型</th>
<th scope="col" class="org-left">初值</th>
<th scope="col" class="org-left">说明</th>
</tr>
</thead>

<tbody>
<tr>
<td class="org-left">_c*_root</td>
<td class="org-left">address</td>
<td class="org-left">预置</td>
<td class="org-left">Controller合约超级用户</td>
</tr>


<tr>
<td class="org-left">_c*_manager_set</td>
<td class="org-left">ES(address)</td>
<td class="org-left">预置</td>
<td class="org-left">Controller合约管理员</td>
</tr>
</tbody>

<tbody>
<tr>
<td class="org-left">_c*_min_reg_dur</td>
<td class="org-left">uint256</td>
<td class="org-left">28天</td>
<td class="org-left">最小的注册时间</td>
</tr>


<tr>
<td class="org-left">_c*_min_reg_len</td>
<td class="org-left">uint256</td>
<td class="org-left">10</td>
<td class="org-left">最短的可注册长度</td>
</tr>


<tr>
<td class="org-left">_c*_grace_period</td>
<td class="org-left">uint256</td>
<td class="org-left">360天</td>
<td class="org-left">宽限期</td>
</tr>


<tr>
<td class="org-left">_c*_price_feed</td>
<td class="org-left">AggregatorV3Interface</td>
<td class="org-left">预置</td>
<td class="org-left">价格查询合约</td>
</tr>
</tbody>

<tbody>
<tr>
<td class="org-left">_c*_is_live</td>
<td class="org-left">bool</td>
<td class="org-left">true</td>
<td class="org-left">Controller是否活跃</td>
</tr>


<tr>
<td class="org-left">_c*_is_open</td>
<td class="org-left">bool</td>
<td class="org-left">true</td>
<td class="org-left">Controller是否开放注册</td>
</tr>


<tr>
<td class="org-left">_c*_can_redeem</td>
<td class="org-left">bool</td>
<td class="org-left">true</td>
<td class="org-left">Controller是否允许兑换码</td>
</tr>
</tbody>

<tbody>
<tr>
<td class="org-left">_c*_base_prices</td>
<td class="org-left">uint256[]</td>
<td class="org-left">预置</td>
<td class="org-left">基础价格，只和域名长度有关</td>
</tr>


<tr>
<td class="org-left">_c*_rent_prices</td>
<td class="org-left">uint256[]</td>
<td class="org-left">预置</td>
<td class="org-left">一年的租赁时间的价格，和域名长度有关</td>
</tr>
</tbody>
</table>


<a id="orga5948ff"></a>

### 辅助状态和辅助合约

为了便于测试，还需要以下辅助状态：

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">名称</th>
<th scope="col" class="org-left">类型</th>
<th scope="col" class="org-left">初值</th>
<th scope="col" class="org-left">说明</th>
</tr>
</thead>

<tbody>
<tr>
<td class="org-left">_pns_token_set</td>
<td class="org-left">ES(uint256)</td>
<td class="org-left">预置</td>
<td class="org-left">曾经出现过的域名</td>
</tr>
</tbody>
</table>

此外，还需要以下额外的辅助合约配合测试，辅助合约也可以认为是一种辅助状态：

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">合约（实例名）</th>
<th scope="col" class="org-left">功能</th>
<th scope="col" class="org-left">测试说明</th>
</tr>
</thead>

<tbody>
<tr>
<td class="org-left">PriceOracle(PRICE0/PRICE1)</td>
<td class="org-left">供Controller询价用</td>
<td class="org-left">价格慢速随机变化</td>
</tr>


<tr>
<td class="org-left">MacroNFT(NFT0/NFT1)</td>
<td class="org-left">配合测试PNS.setName</td>
<td class="org-left">慢速随机切换owner（SENDER_POOL）</td>
</tr>


<tr>
<td class="org-left">MacroNFT(NFT0/NFT1)</td>
<td class="org-left">配合测试PNS.setNftName</td>
<td class="org-left">慢速随机调整token的owner（SENDER_POOL）</td>
</tr>
</tbody>
</table>

具体可参见下面的辅助操作与状态断言小节的内容。


<a id="org75ad00d"></a>

### 操作与断言

从调用者来看，PNS与Controller合约的操作可分为受限和开放两种。受限操作需要管理员或超级用户权限，供维护人员或信任的合约（Controller）使用，可以认为操作是无恶意的；开放操作则供普通用户使用的。下表是各操作的具体分类（不包含Controller.multicall）：

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">函数</th>
<th scope="col" class="org-left">类型</th>
<th scope="col" class="org-left">调用者</th>
</tr>
</thead>

<tbody>
<tr>
<td class="org-left">PNS.transferRootOwnership</td>
<td class="org-left">受限</td>
<td class="org-left">维护人员</td>
</tr>


<tr>
<td class="org-left">PNS.setManager</td>
<td class="org-left">受限</td>
<td class="org-left">维护人员</td>
</tr>


<tr>
<td class="org-left">PNS.setContractConfig</td>
<td class="org-left">受限</td>
<td class="org-left">维护人员</td>
</tr>


<tr>
<td class="org-left">PNS.mint</td>
<td class="org-left">受限</td>
<td class="org-left">维护人员</td>
</tr>


<tr>
<td class="org-left">PNS.mintSubdomain</td>
<td class="org-left">开放</td>
<td class="org-left">用户</td>
</tr>


<tr>
<td class="org-left">PNS.burn</td>
<td class="org-left">开放</td>
<td class="org-left">用户</td>
</tr>


<tr>
<td class="org-left">PNS.setName</td>
<td class="org-left">开放</td>
<td class="org-left">用户</td>
</tr>


<tr>
<td class="org-left">PNS.setNftName</td>
<td class="org-left">开放</td>
<td class="org-left">用户</td>
</tr>


<tr>
<td class="org-left">PNS.addKeys</td>
<td class="org-left">开放</td>
<td class="org-left">用户</td>
</tr>


<tr>
<td class="org-left">PNS.setByHash</td>
<td class="org-left">开放</td>
<td class="org-left">用户</td>
</tr>


<tr>
<td class="org-left">PNS.setManyByHash</td>
<td class="org-left">开放</td>
<td class="org-left">用户</td>
</tr>


<tr>
<td class="org-left">PNS.setlink</td>
<td class="org-left">开放</td>
<td class="org-left">用户</td>
</tr>


<tr>
<td class="org-left">PNS.setlinks</td>
<td class="org-left">开放</td>
<td class="org-left">用户</td>
</tr>


<tr>
<td class="org-left">PNS.bound</td>
<td class="org-left">开放</td>
<td class="org-left">用户</td>
</tr>


<tr>
<td class="org-left">PNS.setMetadataBatch</td>
<td class="org-left">受限</td>
<td class="org-left">维护人员</td>
</tr>


<tr>
<td class="org-left">PNS.register</td>
<td class="org-left">受限</td>
<td class="org-left">合约</td>
</tr>


<tr>
<td class="org-left">PNS.renew</td>
<td class="org-left">受限</td>
<td class="org-left">合约</td>
</tr>
</tbody>

<tbody>
<tr>
<td class="org-left">Controller.transferRootOwnership</td>
<td class="org-left">受限</td>
<td class="org-left">维护人员</td>
</tr>


<tr>
<td class="org-left">Controller.setManager</td>
<td class="org-left">受限</td>
<td class="org-left">维护人员</td>
</tr>


<tr>
<td class="org-left">Controller.setContractConfig</td>
<td class="org-left">受限</td>
<td class="org-left">维护人员</td>
</tr>


<tr>
<td class="org-left">Controller.nameRegisterByManager</td>
<td class="org-left">受限</td>
<td class="org-left">维护人员</td>
</tr>


<tr>
<td class="org-left">Controller.nameRegister</td>
<td class="org-left">开放</td>
<td class="org-left">用户</td>
</tr>


<tr>
<td class="org-left">Controller.nameRedeem</td>
<td class="org-left">开放</td>
<td class="org-left">用户</td>
</tr>


<tr>
<td class="org-left">Controller.renew</td>
<td class="org-left">开放</td>
<td class="org-left">用户</td>
</tr>


<tr>
<td class="org-left">Controller.renewByManager</td>
<td class="org-left">受限</td>
<td class="org-left">维护人员</td>
</tr>


<tr>
<td class="org-left">Controller.setPrices</td>
<td class="org-left">受限</td>
<td class="org-left">维护人员</td>
</tr>
</tbody>
</table>

不同类型的操作，测试的策略也会有所区分：

-   受限、运营者调用
    
    测试权限检查以及功能，但是随机调用参数应该是合理有效的，即假定维护人员不会恶意调用。

-   受限、信任的合约调用
    
    仅对权限检查进行测试，功能通过测试受信任合约（即Controller）的相应函数间接测试。

-   开放
    
    进行所有的测试，随机的调用参数需要包括合法和非法的情况；

从功能上说，操作可分为相对独立的四类，权限管理、合约管理、域名管理与域名修改。权限管理主要是超级用户、管理员的变更、增删；合约管理是对合约的一些设置进行修改；域名管理是域名的注册、续费、注销，以及子域名的注册，以及ERC721的相关操作；域名修改，则是对己方的域名的信息进行调整，包括添加记录，地址和代币的反向解析等，下面分类进行说明。

**权限管理**

权限管理操作包括PNS和Controller的transferRootOwnership和setManager的函数，两个合约同名的操作的功能是一样的。约束表示操作需要满足的条件（require），状态更新表示操作对状态的影响，断言则是状态更新后对状态判断，参数表示模糊测试时参数的取值，其中粗体的 **参数** 表示是该函数是受限调用的，随机参数应选取合理有效范围。

-   transferRootOwnership(r)，转移超级用户
    -   约束
        -   \_msgSender() == \_pns\_root（PNS合约）
        -   \_msgSender() == \_c\*\_root（Controller合约）
    -   状态更新
        -   \_pns\_root ← r（PNS合约）
        -   \_c\*\_root  ← r（Controller合约）
    -   断言
        -   PNS.root() == r（PNS合约）
        -   C\*.root() == r（Controller合约）
    -   **参数**
        -   r：大概率从SENDER\_POOL选取
-   setManager(m, b)，设置或取消管理权限
    -   约束
        -   \_msgSender() == \_pns\_root（PNS合约）
        -   \_msgSender() == \_c\*\_root（Controller合约）
    -   状态更新
        -   \_pns\_manager\_set.insert(m) if b, \_pns\_manager\_set.remove(m) if !b（PNS合约）
        -   \_c\*\_manager\_set.insert(m) if b, \_c\*\_manager\_set.remove(m) if !b（Controller合约）
    -   断言
        -   PNS.isManager(m) == b（PNS合约）
        -   C\*.isManager(m) == b（Controller合约）
    -   **参数**
        -   b：平均随机
        -   m：从指定范围选取
            -   对于PNS合约，选取范围为SENDER\_POOL、C0和C1
            -   对于Controller，选取范围为SENDER\_POOL

**合约管理**

-   PNS.setContractConfig(w)，设置合约可修改属性
    -   约束
        -   \_msgSender() == \_pns\_root
    -   状态更新
        -   \_pns\_mutable ← w & 1
    -   断言
        PNS.FLAGS() = w ? 1 : 0
    -   **参数**
        -   w：大概率为true，小概率为false
-   Controller.setContractConfig(fl, ml, md, gp, pf)，设置合约参数
    
    -   约束
        -   \_msgSender() == \_c\*\_root
    -   状态更新
        -   \_c\*\_is\_live ← fl & 1
        -   \_c\*\_is\_open ← fl & 2
        -   \_c\*\_can\_redeem ← fl & 4
        -   \_c\*\_min\_reg\_len ← ml
        -   \_c\*\_min\_reg\_dur ← md
        -   \_c\*\_grace\_period ← gp
        -   \_c\*\_price\_feed ← pf
    
    -   断言
        -   C\*.FLAGS() == (\_c\*\_is\_alive ? 1 : 0) | (\_c\*\_is\_open ? 2 : 0) | (\_c\*\_can\_redeem ? 4 : 0)
        -   C\*.MIN\_REGISTRATION\_LENGTH() == \_c\*\_min\_reg\_len
        -   C\*.MIN\_REGISTRATION\_DURATION() == \_c\*\_min\_reg\_dur
        -   C\*.GRACE\_PERIOD == \_c\*\_grace\_period
        -   address(C\*.priceFeed()) == address(\_c\*\_price\_feed)
    -   **参数**
        -   fl：0～7，且bit0~bit2大概率为1
        -   ml：1～20
        -   md：1小时～1年
        -   gp：1天～2年
-   Controller.setPrices(bpl, rpl)，设置价格
    -   约束
        -   \_msgSender() == \_c\*\_root
    -   状态更新
        -   \_c\*\_base\_prices ← bpl
        -   \_c\*\_rent\_prices ← rpl
    -   断言
        -   C\*.getPrices() == (bp, rpl)
    -   **参数**
        -   bpl，数组，长度从1到20，非零递减
        -   rpl，数组，和bpl等长，非零递减

**域名管理**

-   PNS.mint(to, tok)，超级用户用于铸造顶级域名（基节点）
    -   约束
        -   \_msgSender() == \_pns\_root
        -   to ≠ 0
        -   tok ∉ \_pns\_owner\_tbl
    -   状态更新
        -   \_pns\_owner\_tbl[to] = tok
        -   \_pns\_token\_set.insert(tok)
    -   断言
        -   PNS.exists(tok)
        -   PNS.ownerOf(tok) == to
    -   **参数**
        -   to：随机从SENDER\_POOL选
        -   tok：随机从WORD\_SET哈希后的值选
-   PNS.mintSubdomain(to, ptok, name)，用户铸造子域名
    -   约束
        -   \_msgSender() ∈ {\_pns\_root, \_pns\_manager\_set, \_pns\_approve\_tbl[ptok], \_pns\_owner\_tbl[ptok]}
        -   to ≠ 0
        -   stok ∉ \_pns\_owner\_tbl
    -   状态更新
        -   \_pns\_owner\_tbl[stok] = to
        -   \_pns\_sd\_parent\_tbl[stok] = ptok
        -   \_pns\_sd\_origin\_tbl[stok] = (ptok ∈ \_pns\_sld\_expire\_tbl) ? ptok : \_pns\_sd\_origin\_tbl[ptok]
        -   \_pns\_token\_set.insert(stok)
    -   断言
        -   ret == stok
        -   PNS.exists(stok)
        -   PNS.ownerOf(stok) == to
        -   PNS.nameExpired() == \_pns\_sld\_expire\_tbl[\_pns\_sd\_origin\_tbl[stok]] + GRACE\_PERIOD < block.timestamp
        -   !PNS.available(stok)
        -   PNS.origin(stok) == \_pns\_sd\_origin\_tbl[stok]
        -   PNS.parent(stok) == ptok
    -   参数
        -   to：大概率SENDER\_POOL，小概率随机
        -   ptok
            -   若\_msgSender() ∈ {\_pns\_manager\_set, \_pns\_root}，则从 {\_pns\_sld\_expire\_tbl, \_pns\_sd\_parent\_tbl} 中随机选择
            -   否则，大概率从 \_pns\_token\_set 中随机选择，小概率随机
        -   name：大概率从WORD\_SET中随机选，小概率随机
    -   说明
        -   stok为name和ptok组合后的哈希；
        -   考虑到approveForAll和approve对于测试不影响，因此仅考虑ERC721中的approve。
-   PNS.burn(tok)，销毁域名
    -   约束
        -   tok ∈ \_pns\_owner\_tbl
        -   满足以下任意一项
            -   PNS.nameExpired(tok) && tok ∉ \_pns\_bound\_set（域名过期且未冻结）
            -   \_msgSender() == \_pns\_root（超级用户可销毁）
            -   \_msgSender() ∈ { \_pns\_owner\_tbl[tok], \_pns\_approve\_tbl[tok] }（授权用户可以销毁）
            -   \_msgSender() ∈ { \_pns\_owner\_tbl[\_pns\_sd\_origin\_tbl[tok]], \_pns\_approve\_tbl[\_pns\_sd\_origin\_tbl[tok]] }（若为子域名，对应二级域名授权用户可销毁）
    -   状态更新
        -   \_pns\_owner\_tbl.remove(tok)
        -   \_pns\_sld\_expire\_tbl.remove(tok) if exists
        -   \_pns\_sd\_origin\_tbl.remove(tok) if exists
        -   \_pns\_sd\_parent\_tbl[tok] ← 0
    -   断言
        -   !PNS.exists(tok)
        -   PNS.origin(tok) == 0
        -   PNS.expire(tok) == 0
    -   参数
        -   tok：大概率从\_pns\_token\_set 随机选，小概率随机
    -   说明
        -   PNS.nameExpired需要进行状态断言测试
-   PNS.bound(tok)
    -   约束
        -   \_msgSender() ∈ { \_pns\_root, \_pns\_manager\_set, \_pns\_owner\_tbl[tok], \_pns\_approve\_tbl[tok] }
        -   以下条件任意一项
            -   tok ∈ \_pns\_sld\_expire\_tbl
            -   \_pns\_sd\_origin\_tbl[tok] ∈ \_pns\_bound\_set
    -   状态更新
        -   \_pns\_bound\_set.insert(tok)
    -   断言
        -   PNS.bounded(tok)
    -   参数
        -   tok：大概率从\_pns\_token\_set随机选，小概率随机
-   PNS.setMetadataBatch(toks, recs)
    -   约束
        -   \_msgSender() ∈ { \_pns\_root, \_pns\_manager\_set }
    -   状态更新
        对于toks和recs的每一对值(tok, rec)：
        -   若rec.origin == tok，\_pns\_sld\_expire\_tbl[tok] ← rec.expire
        -   否则，
            -   \_pns\_sd\_origin\_tbl[tok] ← rec.origin
            -   \_pns\_sd\_parent\_tbl[tok] ← rec.parent
    -   断言
        对于toks和recs的每一对值(tok, rec)：
        -   !PNS.available(tok)
        -   PNS.expire(tok) == rec.expire
        -   PNS.origin(tok) == rec.origin
        -   PNS.parent(tok) == rec.parent
    -   **参数**
        -   toks：长度随机，从 \_pns\_owner\_tbl 随机选
        -   recs：和toks等长
            -   origin：一半概率是对应的tok，一半概率从 \_pns\_owner\_tbl 随机选
            -   expire：若origin是自身，则随机1天到5年，否则是0
            -   parent：若origin是自身，则也是自身，否则随机从 \_pns\_owner\_tbl 选
-   PNS.register
    -   约束
        -   \_msgSender() ∈ { \_pns\_root, \_pns\_manager\_set }
-   PNS.renew
    -   约束
        -   \_msgSender() ∈ { \_pns\_root, \_pns\_manager\_set }
-   Controller.nameRegisterByManager(name, to, dur, set\_name, khs, vls)
    -   约束
        -   \_c\*\_is\_live
        -   \_msgSender() ∈ { \_c\*\_root, \_c\*\_manager\_set }
        -   stok ∉ \_pns\_owner\_tbl
        -   to ≠ 0
        -   \_pns\_mutable
        -   C\* ∈ { \_pns\_root, \_pns\_manager\_set }
    -   状态更新
        -   \_pns\_owner\_tbl[stok] ← to
        -   \_pns\_token\_set.insert(stok)
        -   \_pns\_sld\_expire\_tbl[stok] ← dur
        -   \_pns\_info\_name\_tbl[to] ← stok if set\_name
        -   对于khs和vls的每组值(kh, vl)，\_pns\_info\_record[stok][kh] ← vl
    -   断言
        -   ret == stok
        -   PNS.ownerOf(stok) == to
        -   PNS.getName(to) == stok if set\_name
        -   PNS.getManyByHash(khs, stok) == vls
        -   对于khs和vls的每组值(kh, vl)，PNS.getByHash(kh) == vl
        -   PNS.expire(stok) == dur
        -   PNS.origin(stok) == stok
        -   PNS.parent(stok) == stok
        -   !PNS.available(stok)
    -   **参数**
        -   name：一半概率1到20个字符随机，一般概率从WORD\_SET随机取；
        -   to：大概率从SENDER\_POOL取，小概率随机；
        -   dur：1天到5年，随机；
        -   set\_name：true或false
        -   khs：随机；
        -   vls：khs等长，值随机；
    -   说明
        -   stok：name和C\*\_BASE\_NODE组合的哈希
        -   不对dur时间长度和name的字符长度限制
-   Controller.nameRegister(name, to, dur)
    -   约束
        -   \_c\*\_is\_open
        -   msg.value >= C\*.totalRegisterPrice(name, dur)
        -   length(name) >= \_c\*\_min\_reg\_len
        -   dur >= \_c\*\_min\_reg\_dur
        -   block.timestamp + dur + \_c\*\_grace\_period > block.timestamp + \_c\*\_grace\_period
        -   stok ∉ \_pns\_owner\_tbl
        -   to ≠ 0
    -   状态更新
        -   \_pns\_owner\_tbl[stok] ← to
        -   \_pns\_token\_set.insert(stok)
        -   \_pns\_sld\_expire\_tbl[stok] ← dur
    -   断言
        -   ret == stok
        -   PNS.ownerOf(stok) == to
        -   PNS.expire(stok) == dur
        -   PNS.origin(stok) == stok
        -   PNS.parent(stok) == stok
        -   !PNS.available(stok)
        -   balanceOf(\_c\*\_root) == balanceOf~(\_c\*\_root) + C\*.totalRegisterPrice(name, dur)
        -   balanceOf(\_msgSender()) == balanceOf~(\_msgSender()) + msg.value - C\*.totalRegisterPrice(name, dur)
    -   参数
        -   name：一半概率随机，一半概率从WORD\_SET随机
        -   to：大概率随机从SENDER\_POOL选，小概率随机
        -   dur：基本等概率的小于、等于和大于\_c\*\_min\_reg\_dur
        -   msg.value：基本等概率的小于、等于和大于C\*.totalRegisterPrice(name, dur)
    -   说明
        -   totalRegisterPrice需要进行状态断言测试
        -   stok：name和C\*\_BASE\_NODE组合的哈希
        -   balanceOf~表示调用操作前的资产
-   Controller.nameRegisterWithConfig(name, to, dur, set\_name, khs, vls)
    -   约束
        -   包含Controller.nameRegister约束
        -   \_pns\_mutable
        -   C\* ∈ { \_pns\_root, \_pns\_manager\_set }
        -   length(khs) == length(vls)
    -   状态更新
        -   包含Controller.nameRegister状态更新
        -   \_pns\_info\_name\_tbl[to] ← stok if set\_name
        -   对于khs和vls的每组值(kh, vl)，\_pns\_info\_record[stok][kh] ← vl
    -   断言
        -   包含Controller.nameRegister断言
        -   PNS.getName(to) == stok if set\_name
        -   PNS.getManyByHash(khs, stok) == vls
        -   对于khs和vls的每组值(kh, vl)，PNS.getByHash(kh) == vl
    -   参数
        -   除khs，vls外参数见Controller.nameRegister
        -   khs：随机；
        -   vls：大概率和khs等长，值随机；
-   Controller.nameRedeem
    -   约束
    -   状态更新
    -   断言
    -   参数
-   Controller.renew
    -   约束
    -   状态更新
    -   断言
    -   参数
-   Controller.renewByManager
    -   约束
    -   状态更新
    -   断言
    -   **参数**

**域名修改**

-   PNS.setName
-   PNS.setNftName
-   PNS.addKeys
-   PNS.setByHash
-   PNS.setManyByHash
-   PNS.setlink
-   PNS.setlinks


<a id="org4615681"></a>

### 辅助操作与状态断言

辅助操作为了能覆盖一些仅依靠待测函数无法测试到的场景，而额外的增加的操作。辅助操作过程中不进行断言，也可能会因为不满足操作条件而revert，随机的参数也一般是合理有效的。PNS、Controller以及辅助合约需要的辅助操作如下：

-   PNS.safeTransferFrom()
    -   状态更新
    -   **参数**
-   PNS.approve()
    -   状态更新
    -   **参数**
-   aop\_nft\_set\_owner(idx, owner)
    -   状态更新
        -   NFT<idx>.transferRootOwnership(owner)
    -   **参数**
        -   idx：0或1
        -   owner：SENDER\_POOL随机选
-   aop\_set\_price(idx, price)
    -   状态更新
        -   PRICE<idx>.updateAnswer(price)
    -   **参数**
        -   idx：0或1
        -   price：非0的数

状态断言用于一些状态函数的功能测试，这些状态函数在操作断言中未覆盖或覆盖不全面（Y）。还有一些状态函数虽然未完全覆盖，或者是足够简单（S），或者是在操作函数断言测试中进行了部分间接或直接的测试（P），或者是不会用来查询无效状态并用于判断（V），因此不进行状态断言。具体如下表：

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">函数</th>
<th scope="col" class="org-left">类型</th>
</tr>
</thead>

<tbody>
<tr>
<td class="org-left">PNS.root</td>
<td class="org-left">SP</td>
</tr>


<tr>
<td class="org-left">PNS.isManager</td>
<td class="org-left">SP</td>
</tr>


<tr>
<td class="org-left">PNS.FLAGS</td>
<td class="org-left">SV</td>
</tr>


<tr>
<td class="org-left">PNS.GRACE_PERIOD</td>
<td class="org-left">SV</td>
</tr>


<tr>
<td class="org-left">PNS.supportsInterface</td>
<td class="org-left">S</td>
</tr>


<tr>
<td class="org-left">PNS.exists</td>
<td class="org-left">SP</td>
</tr>


<tr>
<td class="org-left">PNS.isApprovedOrOwner</td>
<td class="org-left">SP</td>
</tr>


<tr>
<td class="org-left">PNS.getName</td>
<td class="org-left">SP</td>
</tr>


<tr>
<td class="org-left">PNS.getNameChecked</td>
<td class="org-left">Y</td>
</tr>


<tr>
<td class="org-left">PNS.getNftName</td>
<td class="org-left">SV</td>
</tr>


<tr>
<td class="org-left">PNS.getKey</td>
<td class="org-left">SV</td>
</tr>


<tr>
<td class="org-left">PNS.get</td>
<td class="org-left">SV</td>
</tr>


<tr>
<td class="org-left">PNS.getMany</td>
<td class="org-left">V</td>
</tr>


<tr>
<td class="org-left">PNS.getByHash</td>
<td class="org-left">SV</td>
</tr>


<tr>
<td class="org-left">PNS.getManyByHash</td>
<td class="org-left">V</td>
</tr>


<tr>
<td class="org-left">PNS.getlink</td>
<td class="org-left">SV</td>
</tr>


<tr>
<td class="org-left">PNS.getlinks</td>
<td class="org-left">V</td>
</tr>


<tr>
<td class="org-left">PNS.bounded</td>
<td class="org-left">Y</td>
</tr>


<tr>
<td class="org-left">PNS.nameExpired</td>
<td class="org-left">Y</td>
</tr>


<tr>
<td class="org-left">PNS.available</td>
<td class="org-left">Y</td>
</tr>


<tr>
<td class="org-left">PNS.expire</td>
<td class="org-left">SP</td>
</tr>


<tr>
<td class="org-left">PNS.origin</td>
<td class="org-left">SP</td>
</tr>


<tr>
<td class="org-left">PNS.parent</td>
<td class="org-left">SP</td>
</tr>


<tr>
<td class="org-left">Controller.root</td>
<td class="org-left">SP</td>
</tr>


<tr>
<td class="org-left">Controller.isManager</td>
<td class="org-left">SP</td>
</tr>


<tr>
<td class="org-left">Controller.priceFeed</td>
<td class="org-left">SV</td>
</tr>


<tr>
<td class="org-left">Controller._pns</td>
<td class="org-left">SV</td>
</tr>


<tr>
<td class="org-left">Controller.BASE_NODE</td>
<td class="org-left">SV</td>
</tr>


<tr>
<td class="org-left">Controller.MIN_REGISTRATION_DURATION</td>
<td class="org-left">SV</td>
</tr>


<tr>
<td class="org-left">Controller.MIN_REGISTRATION_LENGTH</td>
<td class="org-left">SV</td>
</tr>


<tr>
<td class="org-left">Controller.GRACE_PERIOD</td>
<td class="org-left">SV</td>
</tr>


<tr>
<td class="org-left">Controller.FLAGS</td>
<td class="org-left">SV</td>
</tr>


<tr>
<td class="org-left">Controller.supportsInterface</td>
<td class="org-left">S</td>
</tr>


<tr>
<td class="org-left">Controller.getTokenPrice</td>
<td class="org-left">SV</td>
</tr>


<tr>
<td class="org-left">Controller.getPrices</td>
<td class="org-left">SV</td>
</tr>


<tr>
<td class="org-left">Controller.totalRegisterPrice</td>
<td class="org-left">Y</td>
</tr>


<tr>
<td class="org-left">Controller.renewPrice</td>
<td class="org-left">Y</td>
</tr>


<tr>
<td class="org-left">Controller.basePrice</td>
<td class="org-left">Y</td>
</tr>


<tr>
<td class="org-left">Controller.rentPrice</td>
<td class="org-left">Y</td>
</tr>
</tbody>
</table>

注意，表中的V的有效性，是建立在P的前提下的，因为操作断言中直接或间接测试均测试有效状态。下面对表中Y类型的函数进行说明：

-   PNS.getNameChecked
-   PNS.bounded
-   PNS.nameExpired
-   PNS.available
-   Controller.totalRegisterPrice
-   Controller.renewPrice
-   Controller.basePrice
-   Controller.renewPrice


<a id="orgf2c1dda"></a>

## 初始化

合约的初始化通过typescript脚本实现，初始化的过程的事务会保存在 `echidna-init.json` 文件中，预置的一些数据会更新到 `contracts/fuzzing/EchinaInit.sol` 文件，具体包括以下内容。

TODO

具体运行的方式如下，若不修改初始化的内容，以下操作只需要运行一次：

-   TODO
-   TODO

