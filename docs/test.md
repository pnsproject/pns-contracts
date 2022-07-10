
# &#30446;&#24405;

1.  [单元测试](#orgc9c9248)
2.  [模糊测试](#org741e545)
    1.  [合约分析](#orgb80207e)
        1.  [常数](#org129e4d2)
        2.  [状态](#orge024d73)
        3.  [测试辅助合约](#org49c2d53)
        4.  [操作与断言](#org4c06fbc)
    2.  [初始化](#orgbb08cf5)



<a id="orgc9c9248"></a>

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


<a id="org741e545"></a>

# 模糊测试


<a id="orgb80207e"></a>

## 合约分析

实际使用时，一般是1个PNS合约和1个对应的Controller合约。考虑到Controller的升级，以及一些权限控制的测试，测试环境将部署1个PNS合约和2个Controller合约。因此，对于常数以及状态，需要区分不同的合约。下面描述的时候，在可能混淆的情况下，常数和变量的名称相对solidity源代码可能会增加前缀。


<a id="org129e4d2"></a>

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


<a id="orge024d73"></a>

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
<td class="org-left">_pns_manager</td>
<td class="org-left">ES(address)</td>
<td class="org-left">预置</td>
<td class="org-left">PNS合约的管理员表</td>
</tr>
</tbody>

<tbody>
<tr>
<td class="org-left">_owner_tbl</td>
<td class="org-left">EM(uint256, address)</td>
<td class="org-left">预置</td>
<td class="org-left">ERC721的所有者表</td>
</tr>
</tbody>

<tbody>
<tr>
<td class="org-left">_pns_record_key</td>
<td class="org-left">ES(uint256)</td>
<td class="org-left">预置</td>
<td class="org-left">域名条目键</td>
</tr>


<tr>
<td class="org-left">_pns_record_tbl</td>
<td class="org-left">M(uint256, Record)</td>
<td class="org-left">预置</td>
<td class="org-left">域名条目表</td>
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
<td class="org-left">c*_root</td>
<td class="org-left">address</td>
<td class="org-left">预置</td>
<td class="org-left">Controller合约超级用户</td>
</tr>


<tr>
<td class="org-left">c*_manager</td>
<td class="org-left">ES(address)</td>
<td class="org-left">预置</td>
<td class="org-left">Controller合约管理员</td>
</tr>
</tbody>

<tbody>
<tr>
<td class="org-left">c*_min_reg_dur</td>
<td class="org-left">uint256</td>
<td class="org-left">28天</td>
<td class="org-left">最小的注册时间</td>
</tr>


<tr>
<td class="org-left">c*_min_reg_len</td>
<td class="org-left">uint256</td>
<td class="org-left">10</td>
<td class="org-left">最短的可注册长度</td>
</tr>


<tr>
<td class="org-left">c*_grace_period</td>
<td class="org-left">uint256</td>
<td class="org-left">360天</td>
<td class="org-left">宽限期</td>
</tr>
</tbody>

<tbody>
<tr>
<td class="org-left">c*_is_live</td>
<td class="org-left">bool</td>
<td class="org-left">true</td>
<td class="org-left">Controller是否活跃</td>
</tr>


<tr>
<td class="org-left">c*_is_open</td>
<td class="org-left">bool</td>
<td class="org-left">true</td>
<td class="org-left">Controller是否开放注册</td>
</tr>


<tr>
<td class="org-left">c*_can_redeem</td>
<td class="org-left">bool</td>
<td class="org-left">true</td>
<td class="org-left">Controller是否允许兑换码</td>
</tr>
</tbody>

<tbody>
<tr>
<td class="org-left">c*_base_price</td>
<td class="org-left">uint256[]</td>
<td class="org-left">预置</td>
<td class="org-left">基础价格，只和域名长度有关</td>
</tr>


<tr>
<td class="org-left">c*_rent_price</td>
<td class="org-left">uint256[]</td>
<td class="org-left">预置</td>
<td class="org-left">一年的租赁时间的价格，和域名长度有关</td>
</tr>
</tbody>
</table>


<a id="org49c2d53"></a>

### 测试辅助合约

PNS和Controller需要以下额外的辅助合约配合测试：

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">合约（实例）</th>
<th scope="col" class="org-left">功能</th>
<th scope="col" class="org-left">测试说明</th>
</tr>
</thead>

<tbody>
<tr>
<td class="org-left">PriceOracle(PRICE_ORACLE0/PRICE_ORACLE1)</td>
<td class="org-left">供Controller询价用</td>
<td class="org-left">价格慢速随机变化</td>
</tr>


<tr>
<td class="org-left">MacroNFT(MACRO_NFT0/MACRO_NFT1)</td>
<td class="org-left">配合测试PNS.setName</td>
<td class="org-left">慢速随机切换owner（SENDER_POOL）</td>
</tr>


<tr>
<td class="org-left">MacroNFT(MACRO_NFT0/MACRO_NFT1)</td>
<td class="org-left">配合测试PNS.setNftName</td>
<td class="org-left">慢速随机调整token的owner（SENDER_POOL）</td>
</tr>
</tbody>
</table>


<a id="org4c06fbc"></a>

### 操作与断言

从调用者来看，PNS与Controller合约的操作可分为受限和开放两种。受限操作需要管理员或超级用户权限，供维护人员或信任的合约（Controller）使用，可以认为操作是无恶意的；开放操作则供普通用户使用的。下表是各操作的具体分类：

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
    
    测试权限检查以及功能，但是随机调用参数应该是有效的，即假定维护人员不会恶意调用。

-   受限、信任的合约调用
    
    仅对权限检查进行测试，功能通过测试受信任合约（即Controller）的相应函数间接测试。

-   开放
    
    进行所有的测试，随机的调用参数需要包括合法和非法的情况；

从功能上说，操作可分为相对独立的四类，权限管理、合约管理、域名管理与域名修改。权限管理主要是超级用户、管理员的变更、增删；合约管理是对合约的一些设置进行修改；域名管理是域名的注册、续费、注销，以及子域名的注册，以及ERC721的相关操作；域名修改，则是对己方的域名的信息进行调整，包括添加记录，地址和代币的反向解析等，下面分类进行说明。

**权限管理**

权限管理操作包括PNS和Controller的transferRootOwnership和setManager的函数，两个合约同名的操作的功能是一样的。

-   transferRootOwnership(r)，转移超级用户
    -   约束
        -   \_msgSender() == \_pns\_root（PNS合约）
        -   \_msgSender() == \_c\*\_root（Controller合约）
    -   状态更新
        -   \_pns\_root ← r（PNS合约）
        -   \_c\*\_root  ← r（Controller合约）
    -   断言
        -   PNS.root'() == r（PNS合约）
        -   C\*.root'() == r（Controller合约）
-   setManager(m, b)，设置或取消管理权限
    -   约束
        -   \_msgSender() == \_pns\_root（PNS合约）
        -   \_msgSender() == \_c\*\_root（Controller合约）
    -   状态更新
        -   \_pns\_manager.insert(m) if b, \_pns\_manager.remove(m) if !b（PNS合约）
        -   \_c\*\_manager.insert(m) if b, \_c\*\_manager.remove(m) if !b（Controller合约）
    -   断言
        -   PNS.isManager(m) == b（PNS合约）
        -   C\*.isManager(m) == b（Controller合约）

**合约管理**

-   PNS.setContractConfig
-   Controller.setContractConfig
-   Controller.setPrices

**域名管理**

-   PNS.mint
-   PNS.mintSubdomain
-   PNS.burn
-   PNS.bound
-   PNS.setMetadataBatch
-   PNS.register
-   PNS.renew
-   Controller.nameRegisterByManager
-   Controller.nameRegister
-   Controller.nameRedeem
-   Controller.renew
-   Controller.renewByManager

**域名修改**

-   PNS.setName
-   PNS.setNftName
-   PNS.addKeys
-   PNS.setByHash
-   PNS.setManyByHash
-   PNS.setlink
-   PNS.setlinks


<a id="orgbb08cf5"></a>

## 初始化

