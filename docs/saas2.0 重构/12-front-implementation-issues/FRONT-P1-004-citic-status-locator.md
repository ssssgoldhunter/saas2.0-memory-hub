# FRONT-P1-004 中信状态查询未按原交易业务类型选择业务流水字段

- 状态：CLOSED
- 优先级：P1
- 影响：仅中信单笔交易状态查询（`/query-trans-status + bizFunc=74`）。

## 最新边界（2026-08-09 用户确认）

- 当前 API capability 固定为 `TRANS_STATUS_QUERY`，只负责路由当前查询能力。
- 请求 `baseData.originalCapability` 描述被查询原交易的 Front 业务能力，不参与当前 API 路由：
  - `TRANSFER/CONSUME/REFUND`：上送 `BUSS_ID + BUSS_SUB_ID + TRANS_TYPE=01`；
  - `WITHDRAW`：只上送 `BUSS_ID`，不送 `BUSS_SUB_ID/TRANS_TYPE`。
- 请求还必须提供 `baseData.originalTransactionDate`，映射银行顶层 `oriTransDate`。
- 待查询用户编号由业务系统使用协议原始 key `specialData.acctNo` 提供，Handle 加密后映射银行顶层 `acctNo`。
- `frontSsn` 当前只在 Front 返回对象中原样保留，不作为本次中信查询定位条件。
- Front 是银行渠道适配器，只校验银行报文能否有效组装；不校验业务系统内部原交易关系。
- 不扫描 Front 本地转账、消费、退款、提现等渠道表补查询字段。

## 历史实现证据

已核对 lsym `lsym_prod`、`lsym_uat` 和 `lsym_20260625_limeng_refundTask` 分支中的
`ZxTransQueryHandle`：

- `BUSS_ID` 固定取业务主流水；
- 转账和消费查询追加 `BUSS_SUB_ID`，并固定追加 `TRANS_TYPE=01`；
- 提现查询不追加 `BUSS_SUB_ID/TRANS_TYPE`；
- `oriTransDate` 和 `acctNo` 均由调用方明确提供；
- 不查询本地渠道交易表补 `acctNo`。

中信 Word 协议将 `TRANS_TYPE=01` 描述为退款。当前代码遵循已运行的 lsym 转账/消费报文行为，退款按
协议同样使用 `01`；在真实银行联调证据出现前，不得擅自把转账/消费改成 `00`。

## 验收标准

1. 请求使用独立强类型 `originalCapability` 描述原交易，不复用银行 `specialData.transactionType`，也不使用
   当前查询 API capability 冒充原交易类型。
2. 转账、消费、退款必须同时上送 `BUSS_ID/BUSS_SUB_ID` 和 Handle 本地固定值 `TRANS_TYPE=01`；提现只上送
   `BUSS_ID`。
3. `originalTransactionDate` 映射 `oriTransDate`；`specialData.acctNo` 按中信协议加密后映射顶层 `acctNo`。
4. 银行字段 key 保留在 `CiticTransStatusQueryContractKeys`；接口固定 value 保留在具体 Handle。
5. 不扫描本地渠道表，不校验 `frontSsn` 与业务流水是否指向同一记录。
6. 不支持的原交易能力、双流水缺失、日期或账户号缺失时，在调用银行前返回明确业务异常；系统异常继续抛出。

## 当前核验结果（2026-08-09）

已完成静态修改：

1. `TransStatusQueryData` 新增强类型 `originalCapability` 和 `originalTransactionDate`。
2. `CiticQueryTransStatusRequest` 已新增银行顶层 `oriTransDate`，并删除当前不使用的 `oriTransSsn` 字段。
3. `CiticQueryHandle.queryTransactionStatus()` 已按四类原交易能力直接组装银行字段，并校验原交易日期格式。
4. 已删除查询 Handle 对转账、消费、提现 Mapper 的依赖，以及按流水扫描本地渠道表补账户号的逻辑。
5. 已删除对外暴露但不再使用的状态查询 `transactionType` value 常量；协议字段 key 继续集中管理。
6. `frontSsn` 不再映射 `oriTransSsn`，只在 Front 结果中原样保留。

本轮按约束未新增测试、未运行测试、未执行编译。

## 关闭记录（2026-08-09）

- 用户确认当前映射：转账、消费、退款使用业务主子流水，提现只使用业务主流水；
- 最终复核 lsym `lsym_prod`、`lsym_uat`、`lsym_20260625_limeng_refundTask` 中
  `ZxTransQueryHandle.queryTransStatus()` 的相关报文组装逻辑一致：固定上送 `BUSS_ID`，转账/消费追加
  `BUSS_SUB_ID + TRANS_TYPE=01`，并由调用方提供 `oriTransDate/acctNo`；
- 当前 Front 已按确认后的四类原交易能力直接组装，不再扫描本地渠道表，本问题关闭；
- 后续联调若出现相反银行报文证据，作为新的协议修正单独处理，不回退本问题边界。


## 字段更正注（2026-08-19）

本文 `originalCapability`/`originalTransactionDate` 已随交易状态查询统一改造更名为
`capability`/`transDate`（2026-08-17 执行、2026-08-19 trans 缩写定名），语义不变。
