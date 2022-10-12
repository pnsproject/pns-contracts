
# &#30446;&#24405;

1.  [目标](#org3f867e7)
2.  [状态分析](#orgcec47ff)
    1.  [状态说明](#org0bf1227)
    2.  [数据迁移方案](#org6a177b4)
        1.  [PNS](#orgd6bc9b9)
        2.  [Controller](#org8b00d78)
3.  [部署步骤](#orga4e3583)
4.  [测试方案](#orgda946e7)

本文档对已部署v1.3版本合约升级到v1.5版本（fuzzing分支）进行说明。


<a id="org3f867e7"></a>

# 目标

-   对外接口保持不变（PNS合约）
-   注册记录（状态）包括不变


<a id="orgcec47ff"></a>

# 状态分析


<a id="org0bf1227"></a>

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


<a id="org6a177b4"></a>

## 数据迁移方案


<a id="orgd6bc9b9"></a>

### PNS

-   `PNS` 采取openzepplin的可升级合约的方案升级，保留旧版状态；
-   新增的 `_links` 和 `_bounds` 状态使用默认值（空）；
-   新增的 `records` 需要从 Controller 迁移；
-   新增的 `GRACE_PERIOD` 使用旧版 `Controller.GRACE_PERIOD` 的值（假设所有 `Controller` 的值相同）；
-   保留的 `_managers` 状态需要在更新 `Controller` 后更新，去除旧版 `Controller` 地址，加入新版 `Controller` 地址；


<a id="org8b00d78"></a>

### Controller

-   `Controller` 重新部署，数量和状态和旧版一一对应；
-   状态来自旧版本的 `Controller` ；
-   `_trustedForarder` 在部署合约时设置；


<a id="orga4e3583"></a>

# 部署步骤

若未特别说明，下面的 `Controller` 根据实际情况，指所有的 `Controller` 合约或者每个 `Controller` 合约：

1.  准备工作
    1.  记录当前 `PNS.FLAGS` 和 `Controller.FLAGS` 的值；
    2.  移除 `PNS._managers` 中所有的 `Controller` ；
    3.  将 `PNS.FLAGS` 清零；
2.  数据导出，该步骤将导出 `pns_info.json` 和 `controller_info_list.json` 两个数据文件；
    1.  根据ERC721的事件，获取token的列表，然后根据列表导出 `Controller.records` ；
    2.  导出所有的 `PNS.NewSubdomain` 事件，配合上一步的 `records` ，用于填充新的 `records` 的 `parent` 域；
    3.  导出 `Controller` 的配置，用于新版本的部署；
        -   `BASE_NODE`
        -   `MIN_REGISTRATION_DURATION`
        -   `MIN_REGISTRATION_LENGTH`
        -   `GRACE_PERIOD`
        -   `basePrices`
        -   `rentPrices`
        -   `priceFeed`
        -   `_root`
    4.  导出所有 `Controller.ManagerChanged` 事件，用于重建 `_managers` 状态；
3.  部署，该步骤将导出 `address_info.json` 文件，内容包括中继合约地址，以及旧版和新版 `Controller` 对应的地址关系；
    1.  检查数据有效性：
        -   所有 `Controller.GRACE_PERIOD` 均相等；
        -   所有 `Controller.records` 均能在 `PNS.NewSubdomain` 事件中找到父节点；
    2.  部署元事务的中继合约；
    3.  升级 `PNS` 合约；
    4.  一一部署新版 `Controller` 合约，构建函数的参数来自上一步的导出旧版的值；
4.  数据导入及收尾
    1.  一一设置 `Controller` 的 `_managers` 状态；
    2.  根据旧版 `Controller` 的配置，设置新版 `Controller` 的配置（含 `FLAG` ）；
    3.  根据所有旧版 `Controller` 导出的 `records` ，以及 `PNS` 的 `NewSubdomain` 事件，通过函数 `PNS.setMetadataBatch` 批量设置 `PNS.records` ；
    4.  将新部署的 `Controller` 地址添加进 `PNS._mangers` ；
    5.  恢复 `PNS.FLAGS` ；
    6.  将新版的 `Controller._root` 恢复为旧版的值；


<a id="orgda946e7"></a>

# 测试方案

测试（以及实际迁移）需要使用 `migrate_from_v1.3_pre` 和 `migrate_from_v1.3_post` 两个分支的代码，除了测试脚本外，两个分支分别是v1.3和v1.5的合约代码，后续描述用 pre 和 post 代表两个分支的项目目录。

下面是在 `pre` 目录执行的命令：

-   启动localhost节点
    
        npx hardhat node
-   部署旧版合约
    
        hardhat test --network localhost test/deploy-test.ts
-   执行步骤1
    
        npx hardhat run --network localhost scripts/migrate_from_v1.3/1.prepare.ts
-   执行步骤2
    
        npx hardhat run --network localhost scripts/migrate_from_v1.3/2.export.ts

将以下文件复制到 `post` 目录，相对路径保持不变：

-   pns\_info.json
-   controller\_info\_list.json
-   .openzeppelin/unknown-31337.json（或其他文件）

复制完后，在 `post` 目录执行后续的步骤3和步骤4：

-   执行步骤3
    
        npx hardhat run --network localhost scripts/migrate_from_v1.3/3.deploy.ts
-   执行步骤4
    
        npx hardhat run --network localhost scripts/migrate_from_v1.3/4.import_finalize.ts

