# Catering Front 租户准备与分库安全设计

> 状态：current / implemented
> 核验日期：2026-09-02
> 代码基线：`limeng_front@e3e21604`
> 适用范围：`catering-front` 交易、交易查询及中信专项业务

## 1. 最终结论

1. 交易和交易查询在原有 API、chain id、Registry 与路由方式不变的前提下，共用 LiteFlow 普通组件
   `frontTenantPack` 完成租户准备；账户域不经过该组件。
2. 中信不明来款和中信文件处理不进入 LiteFlow，统一使用非 LiteFlow 的
   `FrontSpecialTenantPack`，并取得 `FrontSpecialProcessContext`。
3. Header `tenantId` 是 Front 上述业务路径的强制权威值。Header 缺失、请求/Slot 缺失或二者不一致时，
   必须在业务发送和数据访问前失败，不能只依赖 `catering-common-feign` 的传输层拦截器。
4. `dataSourceId`（2026-09-02 起）与物理分库**同源同值**：`TenantBankConfigLoader.loadTenantBaseInfo`
   经 `TenantDataSourceMappingCache.resolve(tenantId)` 取得（`sys_tenant.resourceConfig`，形如
   `ds_N`），不再读取 `tenant_base_config` 的 `data_source_id`；配置残留值与缓存不一致仅 WARN 观测，
   以缓存为准。请求为空时回填；请求非空但与该值不一致时抛出 `TENANT_BANK_CONFIG_MISMATCH`。
   该字段用于持久化、审计和实例标识，不是物理分库键。映射不可用时 `loadTenantBaseInfo` 抛
   `FrontException`（与"租户基础配置不存在"区分，不吞成 null）。
5. 物理分库链路固定为 `tenant_id → sys_tenant.resourceConfig → ds_N`。映射缺失、格式非法或目标数据源
   不存在时直接失败，不允许落到默认库。`data_source_id` 列值与该链路取值同源，消除双配置源漂移。

## 2. 普通交易与交易查询路径

```text
Transaction API
→ FrontTransApplicationService
→ THEN(frontTenantPack, frontTransExecute)
→ FrontTenantPackNode
→ FrontTransExecuteNode
→ BankTransCapabilityRegistry
→ BankTransCapability

Query API
→ FrontQueryApplicationService
→ THEN(frontTenantPack, frontQueryExecute)
→ FrontTenantPackNode
→ FrontQueryExecuteNode
→ BankQueryCapabilityRegistry
→ BankQueryCapability
```

`FrontTenantPackNode` 的职责边界：

1. 校验 Header `tenantId` 与 Slot `tenantId` 一致；Slot 值由 Application Service 从 `baseData.tenantId` 写入；
2. 通过 `TenantBankConfigLoader` 加载 `TenantBaseInfo` 并写回 Slot；`dataSourceId` 由加载器取自
   分片映射缓存（与物理路由同源），格式为 `ds_N`；
3. 校验 `dataSourceId` 非空（缓存 fail-fast 语义下正常必非空）；
4. 将请求 `dataSourceId` 按该权威值回填或校验一致性；
5. 不做银行路由、不组银行报文、不访问钱包、不替代 Capability。

账户域的 10 条链仍为 `THEN(frontAccountExecute)`。账户状态、余额和账户维护保持 Account 域现有配置加载
与路由逻辑，不能在文档中描述为已经接入 `frontTenantPack`。

## 3. 中信专项路径

```text
CiticUnidentifiedRemittanceApplicationService / CiticFrontFileProcessApplicationService
→ FrontSpecialTenantPack.pack(request, BankCode.CITIC)
→ FrontSpecialProcessContext
→ 对应中信 Channel
→ BankWalletGateway.post
→ BankWalletSender
```

`FrontSpecialTenantPack` 负责 Header/request `tenantId` 一致性、租户基础配置加载、
`clientId/platformCode/dataSourceId` 的回填或一致性校验、目标银行校验和银行账户配置加载。`dataSourceId`
权威值同样来自分片映射缓存（见 §1.4）；专项字段仅在配置值非空时执行冲突校验；配置为空时不会凭空补值，
后续业务是否必填仍由专项 Application Service/Channel 契约决定。
专项 Application Service 继续负责专项业务校验、日志、Channel 调用和响应/异常契约；不得重新复制租户准备逻辑。

## 4. 分库安全边界

- MyBatis 多租户插件向 SQL 注入 `tenant_id`，ShardingSphere 只按该列精确路由。
- `TenantDataSourceShardingAlgorithm` 从进程内 `TenantDataSourceMappingCache` 取得映射；映射源为
  `sys_tenant.resourceConfig`，规范值为 `ds_N`。
- dev/uat/prod 的 ShardingSphere 配置只声明 10 张 `!SHARDING` 业务表；不得恢复 `!SINGLE` 或 `ds_0.*`。
- 未声明的业务表、缺失租户映射、非法数据源名或不可用目标数据源都应失败，不能静默落入 `ds_0`。
- 范围分片仍按现有实现返回全部可用目标名。本次代码没有改变该行为；业务主路径必须通过精确
  `tenant_id` 条件执行，禁止把范围分片描述为已收口。

## 5. 开发约束

- 新增交易或交易查询能力复用现有 `frontTenantPack`，不得在银行 Capability 重复租户准备。
- 新增同类专项能力可复用 `FrontSpecialTenantPack`；只有确认属于专项路径时才能使用，不能借此绕开三域 Registry。
- 不修改 `catering-common-feign` 将 Header 缺失变成全局阻断；严格校验只在 Front 自有业务入口生效。
- `dataSourceId` 不得用于替代 `tenantId` 选择物理库，也不得信任调用方值覆盖租户配置。
- Sender 保持发送前、响应后和异常三类日志；请求/响应业务 JSON 按已确认要求明文记录，调用凭证与密钥仍禁止入日志。

## 6. 代码与测试锚点

- `flow/node/FrontTenantPackNode.java`
- `application/special/FrontSpecialTenantPack.java`
- `application/special/FrontSpecialProcessContext.java`
- `config/TenantBankConfigLoader.java`（`dataSourceId` 同源改造，2026-09-02）
- `config/TenantBaseInfo.java`
- `resources/liteflow/front-flow.xml`
- `sharding/TenantDataSourceShardingAlgorithm.java`
- `sharding/TenantDataSourceMappingCache.java`
- `resources/shardingsphere-config-{dev,uat,prod}.yaml`
- `FrontTenantPackNodeTest`、`FrontSpecialTenantPackTest`、`ShardingConfigurationGuardTest`

文档审查以这些已提交实现为事实来源；如后续代码改变，必须同步更新本设计、19 号设计手册及相关接入手册。
