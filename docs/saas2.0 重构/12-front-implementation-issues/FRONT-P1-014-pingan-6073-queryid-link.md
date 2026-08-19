# FRONT-P1-014 平安 6073 订单回查错用 bank_user_ssn

- 状态：CLOSED
- 优先级：P1
- 影响：6073 明细可以返回 `frontSeqNo`，但 Front 按错误的渠道表列查询，导致
  `bizOrderNo/bizSubOrderNo` 无法从原提现记录补全。

## 边界与字段裁决

1. `queryId` 与 `ssn` 是不同协议字段，不做全局改名、不合并数据库列。
2. Front 发送给银行的 `transSsn` 保存在渠道表 `front_ssn`。
3. 银行/钱包应答 `queryId` 保存在 `bank_query_id`，同时可作为对外 `frontQueryId`。
4. 实际应答明确存在 `USER_SSN/ssn` 时，该值独立保存到 `bank_user_ssn`。
5. 平安 v5.5 原始文档对提现用途 36 的应答明确定义：`queryId` 的业务含义是
   `FrontSeqNo（见证系统流水号）`；6073 行返回的 `frontSeqNo` 就是该值。
6. 这里的 `FrontSeqNo` 是平安对应答 `queryId` 的业务描述，不是 Front 请求
   `transSsn/front_ssn` 的同义词。
7. 平安单笔状态查询使用原请求 `frontSsn/front_ssn → oriTransSsn`；6073 明细订单补全使用
   原应答 `queryId/bank_query_id`，两条链路禁止互换。
8. 所以本问题的关联规则固定为：

```text
6073 recordList.frontSeqNo
    = 原提现应答 queryId
    = front_pingan_withdraw_transaction.bank_query_id
```

原始文档：`saas2.0-memory-hub/docs/客户钱包应用平台_接口文档-平安项目(总)v5.5.doc`，
目标章节为“提现-用途 36”和“交易明细查询-用途 08-6073”。

## 问题证据（2026-08-19）

1. `PingAnTransHandle.updateResponse()` 已将应答 `queryId` 写入 `bank_query_id`，该部分正确。
2. `PingAnQueryHandle.fillWithdrawBizOrders()` 当前使用：

```java
.eq(FrontPinganWithdrawTransaction::getBankUserSsn, frontSeqNo)
```

3. 平安 v5.5 原始文档全文没有定义 `USER_SSN`；文档可证明的 6073 关联列是
   `bank_query_id`，不是 `bank_user_ssn`。
4. `PingAnTransHandle` 中“6073 按 bank_user_ssn 回查”的现有注释与原始文档冲突。

## 建议修改范围

只修改与本关联闭环直接相关的代码：

1. `catering-modules/catering-front/.../channel/pingan/PingAnQueryHandle.java`
   - `fillWithdrawBizOrders()` 保留 `tenantId` 条件；
   - 将 `getBankUserSsn()` 改为 `getBankQueryId()`；
   - 方法注释写明 `6073 frontSeqNo = 原提现应答 queryId`。
2. `catering-modules/catering-front/.../channel/pingan/PingAnTransHandle.java`
   - 删除或改正“6073 按 bank_user_ssn 回查”的误导性注释；
   - 不得把 `queryId` 改写成 `USER_SSN`；
   - 如实际钱包应答确实额外提供 `USER_SSN`，可保留其独立落
     `bank_user_ssn` 的逻辑，但不再声明它是 6073 的关联依据。

不修改 DTO、Controller/API 签名、中信 Handle、DDL、分页、金额、6050/6048 映射和挡板。

## 验收标准

1. `fillWithdrawBizOrders()` 固定按
   `tenantId + bankQueryId(frontSeqNo)` 查 `FrontPinganWithdrawTransaction`。
2. 找到原提现记录时回填 `bizOrderNo/bizSubOrderNo`；查不到继续置空，不改变已有返回行。
3. 请求 `transSsn`、应答 `queryId`、显式 `USER_SSN/ssn` 的保存列继续分离。
4. 代码和注释中不再存在“6073 `frontSeqNo` 固定查 `bank_user_ssn`”的口径。
5. 修复 AI 同步更新 17/18 号文档的状态和实际修改证据，先将本 Issue 改为
   `FIXED_PENDING_REVIEW`；只有用户确认后才改为 `CLOSED`。
6. 未收到用户明确要求时，不新增测试类、不运行测试、不执行编译、不 commit/push。

## 修复记录（2026-08-19，FIXED_PENDING_REVIEW）

### 实际修改文件

1. `catering-modules/catering-front/.../channel/pingan/PingAnQueryHandle.java`
   - `fillWithdrawBizOrders()`：`getBankUserSsn` → `getBankQueryId`（保留 tenantId 条件）
   - 方法注释改写关联公式：6073 frontSeqNo = 原提现应答 queryId = bank_query_id
   - parseClearWithdrawDetail 调用处注释同步
2. `catering-modules/catering-front/.../channel/pingan/PingAnTransHandle.java`
   - 2 处注释从"6073 按 bank_user_ssn 回查"改为"USER_SSN 独立落 bank_user_ssn，6073 订单回查走 bank_query_id"
   - `USER_SSN → bank_user_ssn` 的独立保存逻辑保留（不改写 queryId）

### 静态检查证据

- `grep getBankUserSsn PingAnQueryHandle.java` → **0 命中**
- `grep getBankQueryId PingAnQueryHandle.java` → 1 命中（fillWithdrawBizOrders:729）
- `git diff --stat` → 仅 2 个 Java 文件（PingAnQueryHandle.java + PingAnTransHandle.java）
- `git diff --check` → 无空白错误
- 中信代码/DTO/API/Controller/DDL/6048/6050/金额/分页/挡板 → **零触碰**

### 未执行的验证

- 未新增测试类、未运行测试、未执行 Maven 编译、未 commit/push——等待用户确认后执行。

## 关闭条件

1. 修复后静态检查满足全部验收标准；
2. 如用户要求编译，补充当次编译命令与真实结果；
3. 用户明确确认后改为 `CLOSED`。

## 关闭记录（2026-08-19）

- 静态复核确认 `fillWithdrawBizOrders()` 已按
  `tenantId + bankQueryId(frontSeqNo)` 查询原平安提现渠道记录；
- `front_ssn`、`bank_query_id`、`bank_user_ssn` 三类流水的保存与 6073 关联语义保持分离；
- 用户已明确要求将修复完成的原 Issue 关闭，本项改为 `CLOSED`；
- 本次只采用当前工作区静态证据，未运行测试或编译。

## 用户再次确认的查询边界（2026-08-19）

用户确认平安提现流水必须按查询场景分开解释：

```text
单笔状态查询
    baseData.frontSsn
    = 原交易请求 transSsn/front_ssn
    → 平安 oriTransSsn

6073 明细订单补全
    recordList.frontSeqNo
    = 原提现应答 queryId/bank_query_id
```

`bank_user_ssn` 只承接实际应答中明确存在的 `USER_SSN/ssn`，既不替代请求 `front_ssn`，
也不参与 6073 订单回查。本次确认不改变本 Issue 的 `CLOSED` 状态，也不要求回退已经完成的
`getBankQueryId()` 修复。

同步将 `PingAnQueryHandle.buildTransStatusWire()` 中“原交易银行流水号”的旧注释和异常说明改为
“原交易请求 `transSsn/front_ssn`”，仅修正文案，不改变单笔状态查询报文映射。
