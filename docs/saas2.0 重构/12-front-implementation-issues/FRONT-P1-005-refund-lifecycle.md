# FRONT-P1-005 中信退款定位、协议必填字段来源及职责越界

- 状态：CLOSED
- 优先级：P1
- 影响：Handle 已按最新中信退款边界组装报文；若已有库未执行本问题提供的 ALTER 脚本，五个旧兼容列的 `NOT NULL` 约束仍会阻断退款 INIT 插入。

## 最新边界（2026-08-09 用户确认）

- 本问题只处理中信退款；平安退款边界另见 `TODO-002`，未确认前不得照搬中信修改。
- 当前退款流水只按当前中信退款表的 `tenantId + bizOrderNo + bizSubOrderNo` 做重复交易检查。
- 银行原协议允许 `ORI_BUSS_ID + ORI_BUSS_SUB_ID` 或 `ORI_USER_SSN` 二选一定位；这是银行协议能力，
  不等于 Front 对外必须提供两套定位参数。
- catering-front 中信退款固定采用 `orgBizOrderNo + orgBizSubOrderNo`，映射
  `ORI_BUSS_ID + ORI_BUSS_SUB_ID`。异常交易不一定存在 `orgFrontSsn`，并且 Front
  `orgFrontSsn/transSsn` 不等同于银行 `ORI_USER_SSN`，不得直接映射或用于查询本地记录补字段。
- 定位方式只决定原交易定位字段；其他银行必填字段仍按各自规则独立校验：
  - `baseData.amount`：必填且大于 0，映射 `transAmt/ORI_USER_C_AMT`；
  - `baseData.bizOrderNo + baseData.bizSubOrderNo`：本次退款主子流水均必填，映射
    `REFUND_BUSS_ID + REFUND_BUSS_SUB_ID`；
  - `baseData.businessDate + baseData.businessTime`：均必填，映射 `TRANS_DT + TRANS_TM`；
  - `specialData.ORI_USER_D_ID`：必填；
  - `specialData.ORI_USER_D_NM`：必填；
  - `specialData.ORI_USER_C_ID`：必填；
  - `specialData.ORI_USER_C_NM`：银行协议选填，有值时上送；
  - `specialData.ORI_USER_TRANS_DT`：必填，格式 `yyyyMMdd`；
  - `accountSpecialData.default_fund_type`：当前普通退款的 `FUND_TP` 必填来源。
- Front 只校验上述字段能否组装有效的中信退款请求；不查询本地原交易补齐字段。
- 支持部分退款；原交易是否存在、是否成功、是否超过可退金额及退款业务资格由银行和上游业务系统负责。

## 当前核验结果（2026-08-09）

Handle 报文组装和目标 DDL 口径已收口：

- 中信退款固定使用 `originalBizOrderNo + originalBizSubOrderNo`；
- 本次退款主子流水、日期、时间、金额均在调用银行前校验；
- 原付款方、原收款方、原交易日期从 `specialData` 原始协议 key 读取；
- 不再查询本地 transfer/consume 原交易，不执行原交易状态、金额、累计退款或退款资格校验；
- 支持部分退款，保持 Front 银行渠道适配器边界；
- `original_capability/original_channel_transaction_id/original_front_ssn/original_biz_transaction_id/
  original_biz_sub_transaction_id` 保留为可空兼容列，当前中信 Handle 不读写；
- 09A、09B、09-final 和 09 落库规则已同步可空性、默认值和兼容说明；
- 已提供 `09C-citic-refund-legacy-columns-nullable.sql` 供已有库放宽非空约束；
- 兼容列和原有索引暂时保留，不恢复本地原交易查询或生命周期校验。

## 验收标准

1. 中信退款保留当前退款流水的三字段重复交易检查，命中后不调用银行。
2. 中信退款只使用 `orgBizOrderNo + orgBizSubOrderNo`，两字段成组必填并分别映射
   `ORI_BUSS_ID + ORI_BUSS_SUB_ID`；中信路径不消费 `orgFrontSsn/originalFrontSsn`，不组装
   `ORI_USER_SSN`。
3. 删除中信路径的第三组 `originalBizTransactionId + originalBizSubTransactionId`；若共享 DTO 字段仍被
   未确认的平安退款使用，不得在本问题中直接破坏平安契约，应先隔离中信校验和映射。
4. 调用银行前按中信协议原始 key 校验 `specialData.ORI_USER_D_ID`、`specialData.ORI_USER_D_NM`、
   `specialData.ORI_USER_C_ID`、`specialData.ORI_USER_TRANS_DT` 必填，`specialData.ORI_USER_C_NM`
   选填；日期格式必须为 `yyyyMMdd`。
5. 银行请求显式映射上述 `specialData`；`ORI_USER_C_AMT` 取本次 `baseData.amount`，
   `P_SELF_FLAG/P_DEAL_AMT` 当前固定 `N/0`，`FUND_TP` 取
   `accountSpecialData.default_fund_type` 且缺失明确失败。
6. `baseData.bizOrderNo/bizSubOrderNo/businessDate/businessTime/amount` 按上文独立必填规则校验；
   `transSsn/transTime/laasSsn` 由 Handle 生成，`mchntId/mchntMbrId` 由租户银行配置提供。
7. 不查询 Front 本地原 transfer/consume 记录，不调用 `loadOriginalRefundFields` 或
   `fillRefundAccountFieldsFromOriginal`，不使用 `FOR UPDATE`。
8. 不校验本地原交易状态、银行、能力、原金额、累计退款金额或业务退款资格；不计算或更新
   `refundedAmount`，不保存 `originalCapability/originalChannelTransactionId`。
9. 中信部分退款合法；银行拒绝、成功或未知结果按现有渠道响应规则处理。
10. 中信 Entity、VO、Mapper 不得要求回填 `originalCapability/originalChannelTransactionId`；五个旧字段可作为数据库兼容列保留，但必须允许 `NULL` 并标明当前不读写。不擅自修改平安退款结构。
11. 同步更新 WIKI、02、04、05、08、09、09A、09B 和本问题引用的退款字段契约，区分"银行定位二选一"
    与"其他协议字段独立必填"，删除 Front 查询原渠道记录补字段或承担退款生命周期的描述。

## 已完成修改

### 修改文件

| 文件 | 修改内容 |
|------|----------|
| `CiticTransactionHandle.java` | `refund()` 完全重写——增加 baseData+specialData 必填校验、只使用 `originalBizOrderNo + originalBizSubOrderNo` 定位原交易、从 specialData 映射 `ORI_USER_D_ID/ORI_USER_D_NM/ORI_USER_C_ID/ORI_USER_C_NM/ORI_USER_TRANS_DT`；移除 `fillRefundOriginalLocator`/`loadOriginalRefundFields`/`fillRefundAccountFieldsFromOriginal` 三个旧方法。 |
| `CiticTransactionHandle.java` | 退款 INIT 写入不再保存旧生命周期和本地原交易字段。 |
| `FrontCiticRefundTransaction.java` | 删除 `originalCapability`、`originalChannelTransactionId` 字段。 |

### 验收标准覆盖

| 标准 | 覆盖状态 |
|------|----------|
| 1 | 当前实例内已有检查；`FRONT-P1-012` 已关闭并登记 report 汇总表接入后的跨实例补查 TODO |
| 2 | 已实现：`refund()` 只校验和使用 `originalBizOrderNo + originalBizSubOrderNo` |
| 3 | 已实现：中信 `doInsertInit` 不再保存 `originalBizTransactionId/originalBizSubTransactionId`；共享 DTO 未动 |
| 4 | 已实现：`requireSpecialData` 校验 ORI_USER_D_ID/ORI_USER_D_NM/ORI_USER_C_ID/ORI_USER_TRANS_DT + 日期格式 |
| 5 | 已实现：显式映射全部 specialData + `ORI_USER_C_AMT`/`P_SELF_FLAG`/`P_DEAL_AMT`/`FUND_TP` |
| 6 | 已实现：baseData 必填校验 |
| 7 | 已实现：`loadOriginalRefundFields`/`fillRefundAccountFieldsFromOriginal` 已删除 |
| 8 | 已实现：Handle 不保存 `originalCapability/originalChannelTransactionId`，五个兼容列不作为当前中信退款数据源 |
| 9 | 已实现：不校验交易状态/金额/资格，支持部分退款 |
| 10 | 已实现：09A/09B/09-final 将五个兼容列统一为可空，09C 提供已有库 ALTER |
| 11 | 已实现：WIKI、05、08、09 及本 issue 已同步兼容列和当前 Handle 边界 |

## 关闭条件

- 中信退款五个兼容列在 09A、09B、09-final 中均允许 `NULL`，不要求 Handle 回填；
- 全新库使用 09B/09-final 可直接插入当前 INIT 记录，已有库由部署人员执行 09C ALTER；
- 同步所有引用退款旧定位和本地原交易查询的记忆体文档；
- 不修改未确认的平安退款结构，平安继续由 `TODO-002` 跟踪。

## 本次修复（2026-08-09）

1. `FrontCiticRefundTransactionVo.java`：删除 `originalCapability`、`originalChannelTransactionId` 字段。
2. `FrontCiticRefundTransactionMapper.xml`：从 `@ResultMap` 和 `Base_Column_List` 中移除 `original_capability`、`original_channel_transaction_id`。
3. 用户确认保留五个历史兼容列并改为允许 `NULL`；09A、09B、09-final 已同步，现有库执行 `09C-citic-refund-legacy-columns-nullable.sql`。

## 关闭记录（2026-08-09）

- 用户已确认现有物理库完成 `09C-citic-refund-legacy-columns-nullable.sql`；
- 中信退款五个历史兼容列已放宽为允许 `NULL`，当前 Handle 的 INIT 插入不再受旧非空约束阻断；
- 本问题关闭，后续不得恢复本地原交易查询、累计退款或其他上游业务校验。
