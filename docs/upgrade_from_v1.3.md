
# &#30446;&#24405;

1.  [目标](#orgbc927bf)
2.  [状态分析](#orge9ea243)
    1.  [状态说明](#org926fd06)
    2.  [数据迁移方案](#org78351f9)
        1.  [PNS](#org50bea42)
        2.  [Controller](#orgaeffbbc)
3.  [测试方案测试](#orgd6d6667)
4.  [部署步骤](#org6c39a62)

本文档对已部署v1.3版本合约升级到v1.5版本（fuzzing分支）进行说明。


<a id="orgbc927bf"></a>

# 目标

-   对外接口保持不变（PNS合约）
-   注册记录（状态）包括不变


<a id="orge9ea243"></a>

# 状态分析


<a id="org926fd06"></a>

## 状态说明

可以通过 `slither . --print variable-order` 来获取变量列表。

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">v1.3合约</th>
<th scope="col" class="org-left">v1.3对应基类</th>
<th scope="col" class="org-left">v1.3状态</th>
<th scope="col" class="org-left">v1.5合约</th>
<th scope="col" class="org-left">v1.5对应基类</th>
<th scope="col" class="org-left">v1.5状态</th>
<th scope="col" class="org-left">关系</th>
</tr>
</thead>

<tbody>
<tr>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">FLAGS</td>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">FLAGS</td>
<td class="org-left">等价</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">_keys</td>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">_keys</td>
<td class="org-left">等价</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">_records</td>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">_records</td>
<td class="org-left">等价</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">_names</td>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">_names</td>
<td class="org-left">等价</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">_nft_names</td>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">_nft_names</td>
<td class="org-left">等价</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">ManagerOwnableUpgradeable</td>
<td class="org-left">_root</td>
<td class="org-left">PNS</td>
<td class="org-left">ManagerOwnableUpgradeable</td>
<td class="org-left">_root</td>
<td class="org-left">等价</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">ManagerOwnableUpgradeable</td>
<td class="org-left">_managers</td>
<td class="org-left">PNS</td>
<td class="org-left">ManagerOwnableUpgradeable</td>
<td class="org-left">_managers</td>
<td class="org-left">等价</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_name</td>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_name</td>
<td class="org-left">等价</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_symbol</td>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_symbol</td>
<td class="org-left">等价</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_owners</td>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_owners</td>
<td class="org-left">等价</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_balances</td>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_balances</td>
<td class="org-left">等价</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_tokenApprovals</td>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_tokenApprovals</td>
<td class="org-left">等价</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_operatorApprovals</td>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_operatorApprovals</td>
<td class="org-left">等价</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">priceFeed</td>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">priceFeed</td>
<td class="org-left">等价</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">_pns</td>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">_pns</td>
<td class="org-left">等价</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">records</td>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">records</td>
<td class="org-left">需要转换</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">BASE_NODE</td>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">BASE_NODE</td>
<td class="org-left">等价</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">DEFAULT_DOMAIN_CAPACITY</td>
<td class="org-left">-</td>
<td class="org-left">-</td>
<td class="org-left">-</td>
<td class="org-left">-</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">MIN_REGISTRATION_DURATION</td>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">MIN_REGISTRATION_DURATION</td>
<td class="org-left">等价</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">MIN_REGISTRATION_LENGTH</td>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">MIN_REGISTRATION_LENGTH</td>
<td class="org-left">等价</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">GRACE_PERIOD</td>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">GRACE_PERIOD</td>
<td class="org-left">等价</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">FLAGS</td>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">FLAGS</td>
<td class="org-left">等价</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">basePrices</td>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">basePrices</td>
<td class="org-left">等价</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">rentPrices</td>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">rentPrices</td>
<td class="org-left">等价</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">capacityPrice</td>
<td class="org-left">-</td>
<td class="org-left">-</td>
<td class="org-left">-</td>
<td class="org-left">-</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">RootOwnable</td>
<td class="org-left">_root</td>
<td class="org-left">Controller</td>
<td class="org-left">RootOwnable</td>
<td class="org-left">_root</td>
<td class="org-left">等价</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">ManagerOwnable</td>
<td class="org-left">_managers</td>
<td class="org-left">Controller</td>
<td class="org-left">ManagerOwnable</td>
<td class="org-left">_managers</td>
<td class="org-left">等价</td>
</tr>
</tbody>
</table>

部分状态，例如 `PNS.FLAGS` ，在过程中可能会变化，最终应该和迁移前保持一致。

对于 `Controller.records` 到 `PNS.records` 的迁移，类型由 `Controller.Record` 变为 `PNS.Record` ，其中 `origin` 和 `expire` 域保持不变，抛弃原 `children` 和 `capacity` ，需要新增 `parent` 域。

下面是v1.5的一些新状态

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">v1.5合约</th>
<th scope="col" class="org-left">v1.5基类</th>
<th scope="col" class="org-left">v1.5新状态</th>
<th scope="col" class="org-left">说明</th>
</tr>
</thead>

<tbody>
<tr>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">_links</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">_bounds</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">_trustedForarder</td>
<td class="org-left">&#xa0;</td>
</tr>
</tbody>
</table>


<a id="org78351f9"></a>

## 数据迁移方案


<a id="org50bea42"></a>

### PNS

-   `PNS` 采取openzepplin的可升级合约的方案升级，保留原有状态；
-   新增的 `_links` 和 `_bounds` 状态使用默认值（空）；
-   新增的 `records` 需要从 Controller 迁移；
-   新增的 `GRACE_PERIOD` 使用 `Controller` 原来的值（假设所有 `Controller` 的值相同）；
-   保留的 `_managers` 状态需要在更新 `Controller` 后更新，去除原来的 `Controller` 地址，加入新的 `Controller` 地址；


<a id="orgaeffbbc"></a>

### Controller

-   `Controller` 重新部署，数量和状态和旧版一一对应；
-   状态来自旧版本的 `Controller` ；
-   `_trustedForarder` 在部署合约时设置；


<a id="orgd6d6667"></a>

# 测试方案测试


<a id="org6c39a62"></a>

# 部署步骤

若未特别说明，下面的 `Controller` 根据实际情况，指所有的 `Controller` 合约或者每个 `Controller` 合约：

-   准备工作
    -   记录当前 `PNS.FLAGS` 和 `Controller.FLAGS` 的值；
    -   将 `PNS.FLAGS` 和 `Controller.FLAGS` 清零；
    -   移除 `PNS._managers` 中所有的 ~Controller~；
-   数据导出
    -   导出 `Controller.records` ；
    -   导出所有的 `PNS.NewSubdomain` 事件，配合上一步的 `records` ，用于填充新的 `records` 的 `parent` 域；
    -   导出 `Controller` 的配置，用于新版本的部署；
        -   `BASE_NODE`
        -   `MIN_REGISTRATION_DURATION`
        -   `MIN_REGISTRATION_LENGTH`
        -   `GRACE_PERIOD`
        -   `basePrices`
        -   `rentPrices`
        -   `priceFeed`
        -   `_root`
    -   导出所有 `Controller.ManagerChanged` 事件，用于重建 `_managers` 状态；
-   部署
    -   部署元事务的中继合约；
    -   升级 `PNS` 合约；
    -   一一部署新版 `Controller` 合约，构建函数的参数来自上一步的导出旧版的值；
    -   将新部署的 `Controller` 地址添加进 `PNS._mangers` ；
-   数据导入及收尾
    -   一一设置 `Controller` 的 `_managers` 状态；
    -   根据所有旧版 `Controller` 导出的 `records` ，以及 `PNS` 的 `NewSubdomain` 事件，通过函数 `PNS.setMetadataBatch` 批量设置 `PNS.records` ；
    -   恢复 `PNS.FLAGS` 和 `Controller.FLAGS`
    -   将新版的 `Controller._root` 恢复为旧版的值；

