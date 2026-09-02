# Front 后续待办

本文只记录已明确延后、需要后续人工确认或逐项接入的工作，不属于
`12-front-implementation-issues` 缺陷清单，也不计入 P0/P1/P2 Issue 完成度。

> 2026-08-29 说明：全量扁平化迁移已经按
> [29-cateringfront全量扁平化迁移-plan](29-cateringfront全量扁平化迁移-plan.md)
> 实施完成，该文档只保留历史记录，不得重新执行；本文 TODO-001/002/003 状态不因结构迁移改变。

当前状态摘要：

- `CLOSED`：TODO-001 已按用户裁决收口（交易状态、24 账户明细、25 平台明细已启用；
  账户状态/余额明确保留挡板，不再作为待实现项）；
- `CLOSED`：平安退款代码、DDL 和文档已完成静态验收，并于 2026-08-19 经用户确认关闭；
- `DEFERRED`：report 报表库跨实例重复交易补查，用户明确暂时不做。
- `PENDING-CONFIRM`：TODO-004 catering-system 启动报错（Nacos import 缺 `.yml` 后缀），
  2026-09-02 已诊断，修复方案待用户确认后实施。

## TODO-001 平安查询 Capability 逐接口核对和接入（CLOSED）

- 状态：`CLOSED`（2026-08-19 用户裁决）——交易状态和两类明细已实现；
  账户状态/余额不再安排接入，固定保留 `ADAPTER_NOT_READY` 挡板
- 代码入口：`channel/pingan/account/PingAnAccountStatusCapability` 与 `PingAnAccountBalanceCapability`（三域收口后类名）
- 当前行为：账户状态、账户余额两个公开查询方法在银行调用前抛出 `ADAPTER_NOT_READY`（交易状态/24明细/25明细已启用）

### 保留挡板原因

平安查询字段、`bizFunc`、请求路径、账户定位方式和返回数组结构尚未逐接口对照银行 Word 文档确认。
旧 Handle / 当前挡板 Capability 中的本地常量、字段映射和请求组装只属于历史实现分析草稿，
不是正式字段契约，不能通过
整理参数或补字段常量的方式顺带启用。

### 接口最终状态

| Front 方法 | 当前状态 | 说明/未来条件 |
|---|---|---|
| `queryAccountStatus` | `CLOSED` / 按裁决保留 `ADAPTER_NOT_READY` | 不再确认或实现等价能力；除非用户未来重新打开 |
| `queryAccountBalance` | `CLOSED` / 按裁决保留 `ADAPTER_NOT_READY` | 不再确认或实现 `63/64/01/02/03`；除非用户未来重新打开 |
| `queryTransactionStatus` | `CLOSED`（2026-08-17） | bizFunc 02/03/04 按 capability 转译；提现 cardNoEnc 渠道表回查；S/P/F 三态 |
| `queryPlatformTransactionDetails` | `CLOSED`（2026-08-19，17 号 spec） | 25-01/03→6050（inAcctType 过滤回填）、25-02→6048（termSsn） |
| `queryTransactionDetails` | `CLOSED`（2026-08-19，17 号 spec） | 24-04→6073（queryFlag=2 + commission 作 fee + 订单号按 tenantId+bankQueryId 查渠道表） |

### 未来如经用户明确重新打开时必读

1. [03-平安银行接口能力汇总](03-平安银行接口能力汇总.md)
2. [10-transaction-query-field-contract](10-transaction-query-field-contract.md)
3. [05-front代码开发约束](05-front代码开发约束.md)
4. 对应平安银行 Word 接口文档

### 重新打开后的启用门槛

1. 每次只领取一个查询接口并完成人工字段核对，不批量启用两个接口。
2. 明确该接口的路径、`bizFunc`、`chnlNo`、顶层字段、`reserve` 字段、响应节点和状态映射。
3. `bizFunc/chnlNo/API path` 作为带业务注释的 Capability 本地固定参数；字段 key 才进入该接口专属的
   PingAn Query ContractKeys，且使用银行协议原始名。
4. 只在对应接口的确认实现中增加实际使用的本地固定参数，不为尚未实现的分支预留草稿常量或映射。
5. 删除该接口对中信 ContractKeys、普通转账 ContractKeys 和未确认字符串字段 key 的借用。
6. 保持 `baseData/specialData/accountSpecialData` 边界及既定 API 返回类型。
7. 只有该接口核对完成后，才允许移除对应入口的 `pendingIntegration()`；另一个未确认入口继续返回
   `ADAPTER_NOT_READY`。
8. LiteFlow 业务异常写 Slot 后中断，系统异常继续抛出。
9. 按用户当次明确授权决定是否新增测试或执行编译，不以历史编译记录作为验收证据。

### 当前禁止事项

- 不根据现有草稿猜测或补齐平安查询协议。
- 不为了统一参数而创建未经银行文档确认的正式字段契约。
- 不移除账户状态/余额两个入口的待接入挡板（明细两项与交易状态已于 2026-08-17/19 启用）。
- 不将本待办计为当前 P0/P1/P2 未修复缺陷。
- 不得主动领取、核对 6108 等候选接口或实现账户状态/余额；只有用户新的明确要求才能重新打开。

## TODO-002 平安退款边界与协议字段实施

- 状态：`CLOSED`（2026-08-19，静态验收通过并经用户确认）
- 详细取证与修复要求：
  [TODO-002-pingan-refund-boundary.md](12-front-implementation-issues/TODO-002-pingan-refund-boundary.md)

### 最新确认口径

已静态核验 lsym 分支 `release/lsym_20260820_limeng` 的平安退款实际 Handle、`SaasPaTest`、
请求 DTO 和上游组装链路后，用户进一步明确渠道数据边界：

1. `fee`：`bizFunc=02` 实际 Handle 顶层发送；为空时补 `0`，单位分。
2. `oriTransSsn`：顶层字段，来源是原交易请求 `transSsn`，对应 SaaS 原渠道记录 `frontSsn`；
   不是银行响应 `bankUserSsn`。
3. `oriTransDate`：顶层字段，来源是原交易时间的 `yyyyMMdd` 日期部分。
4. 原交易边界：业务系统不知道渠道字段；Front 按租户和原业务主子流水精确查询原转账/消费渠道表，
   取 `frontSsn`、日期及原账户/会员字段，但不判断累计退款金额或退款资格。
5. 当前只使用 `bizFunc=02`；`SaasPaTest` 虽有 `06` 样例，本待办不得启用 `06`。
6. 上述裁决只适用于平安退款，不改变中信 `FRONT-P1-005` 已关闭的实现。

### 目标实现与当前状态

| 范围 | 文件 | 目标与当前状态 |
|---|---|---|
| 组装器 | `FrontSpecialDataAssembler`、`PingAnSpecialDataAssembler` | 退款仅保留可选备注；`withdraw()` 与退款 Javadoc 均已恢复、修正 |
| 银行请求对象 | `PingAnRefundRequest` | 顶层原流水/日期/金额/手续费已明确；`oriOrderId` 当前不发送 |
| Capability 实现 | `PingAnTransHandle`（历史名，现 `PingAnRefundCapability`） | `bizFunc=02`、两表精确查询、`frontSsn`、账号加密、原记录/日期校验和单实例查重均已闭环 |
| 渠道落库 | `PingAnTransHandle#insertRefundInitRecord`（历史入口，现位于 `PingAnRefundCapability`） | 本次业务字段、原渠道三项关联及原账户字段完整落库 |
| 字段常量 | `PingAnRefundContractKeys` | key 与来源、加密及不发送字段的注释已统一 |
| 引用文档 | 03、05、08、13、15、16、WIKI、Issue 索引 | 设计边界、实现状态和 `originalBizTransactionId` 选填/DDL 可空口径已统一 |

### 静态验收结果

最终静态验收确认：TODO-002 的原渠道查询、报文映射、必填校验、日期兼容、INIT 落库、
单实例并发查重、DDL 和文档口径均已闭环；用户已确认验收通过。详细证据见 TODO-002 §12。

## TODO-003 report 汇总表接入后的跨实例重复交易补查

- 状态：`DEFERRED`（2026-08-19 用户裁决：暂时不做）
- 已完成边界：当前银行、当前能力业务表内已按
  `tenantId + bizOrderNo + bizSubOrderNo` 精确检查，`FRONT-P1-012` 按当前部署边界保持 `CLOSED`。
- 当前行为：各银行交易 Capability（`channel/{bank}/transaction/`，三域收口后替代原 TransHandle）只查当前银行/能力业务表，
  不调用 report 查询接口或统一交易表。
- 暂缓约束：不主动开发 Provider、Mapper、Feign 或 report 查询逻辑；不因此重新打开
  `FRONT-P1-012`。
- 恢复条件：只有用户未来明确要求重新接入 report 跨实例查重时再开发。

## TODO-004 catering-system 启动报错：Nacos import dataId 缺 `.yml` 后缀

- 状态：`PENDING-CONFIRM`（2026-09-02 已诊断并向用户给出修复方案，未经确认未改代码）
- 现象：catering-system 启动抛 `BeanDefinitionStoreException`，`@MapperScan("${mybatis-plus.mapperPackage}")`
  占位符无法解析（`catering-common-mybatis` 的 `MybatisPlusConfiguration`）。
- 根因：`catering-modules/catering-system/src/main/resources/application.yml` 的
  `spring.config.import` 写的是 `optional:nacos:application-common` / `optional:nacos:${spring.application.name}`，
  是全仓 13 个模块中唯一不带 `.yml` 后缀的。spring-cloud-alibaba 2025.0.0.0 的
  `NacosConfigDataLocationResolver.dataIdFor` 按 URI 字面量取 dataId、不补 `file-extension`
  （反编译确认；`suffixFor` 只决定内容解析格式），因此拉取的 dataId 在 Nacos 中不存在，
  `optional:` 静默跳过 → `application-common.yml` 的 `mybatis-plus.mapperPackage` 缺失。
- 附带发现：该文件第二段 `spring.nacos.config.file-extension: yml` 是双重无效——
  属性前缀经 SPI（`SpringCloudNacosPropertiesPrefixProvider`）钉死为 `spring.cloud.nacos`，
  该键绑定不到；且机制上 `file-extension` 也不参与 dataId 拼接，建议一并删除。
- 修复方案（与 front 等 12 个模块对齐）：import 行补 `.yml` 后缀并删除无效段；
  修复后还需确认 Nacos `saas` 命名空间存在 `catering-system.yml`（数据源在其专属配置中，
  `datasource.yml` import 处于注释状态）。
