
# &#30446;&#24405;

1.  [目标](#org2ab866b)
2.  [状态分析](#org185d698)
    1.  [状态说明](#org1f6efd0)
    2.  [数据迁移方案](#org9b94d01)
3.  [测试方案测试](#orgb5c0ad7)
4.  [部署步骤](#org3927898)

本文档对已部署v1.3版本合约升级到v1.5版本（fuzzing分支）进行说明。


<a id="org2ab866b"></a>

# 目标

-   对外接口保持不变（PNS合约）
-   注册记录（状态）包括不变


<a id="org185d698"></a>

# 状态分析


<a id="org1f6efd0"></a>

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
<th scope="col" class="org-left">迁移方式</th>
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
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">_keys</td>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">_keys</td>
<td class="org-left">等价</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">_records</td>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">_records</td>
<td class="org-left">等价</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">_names</td>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">_names</td>
<td class="org-left">等价</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">_nft_names</td>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">_nft_names</td>
<td class="org-left">等价</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">ManagerOwnableUpgradeable</td>
<td class="org-left">_root</td>
<td class="org-left">PNS</td>
<td class="org-left">ManagerOwnableUpgradeable</td>
<td class="org-left">_root</td>
<td class="org-left">等价</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">ManagerOwnableUpgradeable</td>
<td class="org-left">_managers</td>
<td class="org-left">PNS</td>
<td class="org-left">ManagerOwnableUpgradeable</td>
<td class="org-left">_managers</td>
<td class="org-left">等价</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_name</td>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_name</td>
<td class="org-left">等价</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_symbol</td>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_symbol</td>
<td class="org-left">等价</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_owners</td>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_owners</td>
<td class="org-left">等价</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_balances</td>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_balances</td>
<td class="org-left">等价</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_tokenApprovals</td>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_tokenApprovals</td>
<td class="org-left">等价</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_operatorApprovals</td>
<td class="org-left">PNS</td>
<td class="org-left">ERC721Upgradeable</td>
<td class="org-left">_operatorApprovals</td>
<td class="org-left">等价</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">priceFeed</td>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">priceFeed</td>
<td class="org-left">等价</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">_pns</td>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">_pns</td>
<td class="org-left">等价</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">records</td>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">records</td>
<td class="org-left">需要转换</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">BASE_NODE</td>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">BASE_NODE</td>
<td class="org-left">等价</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">DEFAULT_DOMAIN_CAPACITY</td>
<td class="org-left">-</td>
<td class="org-left">-</td>
<td class="org-left">-</td>
<td class="org-left">-</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">MIN_REGISTRATION_DURATION</td>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">MIN_REGISTRATION_DURATION</td>
<td class="org-left">等价</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">MIN_REGISTRATION_LENGTH</td>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">MIN_REGISTRATION_LENGTH</td>
<td class="org-left">等价</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">GRACE_PERIOD</td>
<td class="org-left">PNS</td>
<td class="org-left">PNS</td>
<td class="org-left">GRACE_PERIOD</td>
<td class="org-left">等价</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">FLAGS</td>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">FLAGS</td>
<td class="org-left">等价</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">basePrices</td>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">basePrices</td>
<td class="org-left">等价</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">rentPrices</td>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">rentPrices</td>
<td class="org-left">等价</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">Controller</td>
<td class="org-left">capacityPrice</td>
<td class="org-left">-</td>
<td class="org-left">-</td>
<td class="org-left">-</td>
<td class="org-left">-</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">RootOwnable</td>
<td class="org-left">_root</td>
<td class="org-left">Controller</td>
<td class="org-left">RootOwnable</td>
<td class="org-left">_root</td>
<td class="org-left">等价</td>
<td class="org-left">&#xa0;</td>
</tr>


<tr>
<td class="org-left">Controller</td>
<td class="org-left">ManagerOwnable</td>
<td class="org-left">_managers</td>
<td class="org-left">Controller</td>
<td class="org-left">ManagerOwnable</td>
<td class="org-left">_managers</td>
<td class="org-left">等价</td>
<td class="org-left">&#xa0;</td>
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


<a id="org9b94d01"></a>

## 数据迁移方案


<a id="orgb5c0ad7"></a>

# 测试方案测试


<a id="org3927898"></a>

# 部署步骤

