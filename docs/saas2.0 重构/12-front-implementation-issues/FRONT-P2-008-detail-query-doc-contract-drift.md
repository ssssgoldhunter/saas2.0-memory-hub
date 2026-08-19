# FRONT-P2-008 24/25 明细查询联动文档仍有当前口径漂移

- 状态：OPEN（2026-08-19 用户复核，第八轮重新打开）
- 优先级：P2
- 修复结果：13 号已将对外类型统一为 25=`01/02/03`、24=`04`，并将
  `accountType` 改为选填、仅中信生效；16 号已固定 6073 使用 `bank_query_id` 回查。

## 边界

1. 本问题只收口 Markdown 契约、状态和示例，不修改 Java、XML、DDL 或银行映射。
2. 17 号 spec 是 24/25 明细查询的唯一契约事实源；字段、分页、平安 6048/6050/6073
   和流水关联口径不得在本问题中重新设计。
3. 历史迁移对照中为了说明“旧对象 → 新对象”而出现旧类名是合法的；
   只清理仍被当作当前签名、当前返回或当前完成状态的旧口径。
4. 禁止把分页结果重新包入 `R`，禁止恢复 `FrontPageResult`。

## 正确契约

```java
TableDataInfo<PlatformTransDetailItem> queryPlatformTransactionDetails(
    FrontRequest<PlatformDetailQueryData> request);

TableDataInfo<AccountTransDetailItem> queryTransactionDetails(
    FrontRequest<AccountDetailQueryData> request);
```

- 24：`AccountDetailQueryData + AccountDetailType + AccountTransDetailItem`；
- 25：`PlatformDetailQueryData + PlatformDetailType + PlatformTransDetailItem`；
- 两个分页接口直接返回 `TableDataInfo<T>`，不包 `R`；
- 平安 3/5 查询已启用：交易状态、24 明细、25 明细；
- 平安只有账户状态、账户余额两个入口保留 `pendingIntegration()/ADAPTER_NOT_READY`。

## 问题证据（2026-08-19）

### 1. `10-transaction-query-field-contract.md`

- §1 两个当前 API 签名仍使用 `TransactionDetailQueryData`，且在单个泛型中混写
  `PlatformTransDetailItem（25）/AccountTransDetailItem（24）`；
- §4.1 仍声明 `TransactionDetailQueryData` 是当前公共请求对象；
- §9 仍声明平安两个明细查询处于 TODO-001 挡板、不支持组装。

### 2. `13-front-api-external.md`

- §6 仍将当前分页行结构定义为 `TransactionDetailItem`，示例字段与 17 号两套 DTO 都不一致；
- 错误码表把 `F200003` 泛化为“如平安查询”，应收窄为尚未接入的平安账户状态/余额。

### 3. `15-交易额外数据标准化-spec.md`

- §3.4 仍将已删除的 `TransactionDetailItem` 写成当前查询返回模型；
- §10 仍声明查询组装只有交易状态落地、其余 4 个查询直传协议键，未反映
  24/25 两个明细组装已启用。

### 4. `05-front代码开发约束.md`

- 交易明细请求边界仍引用 `TransactionDetailQueryData`；
- 分页返回示例仍使用 `TableDataInfo<TransactionDetailItem>`；
- 分页行 `specialData` 约束仍绑定 `TransactionDetailItem`，没有改为两套行 DTO。

`R<FrontPageResult<...>>` 出现在“禁止清单”中是合法的，修复 AI 不得因 grep 命中就删除该反例。

### 5. `WIKI-START.md`

- “已提供能力”和“不允许变更”两处仍将分页契约写成
  `TableDataInfo<TransactionDetailItem>`。

### 6. `13-front后续待办.md`

- TODO-001 的状态表已正确写成 3/5 已启用，但“当前行为”仍声明五个公开查询方法
  全部抛 `ADAPTER_NOT_READY`；
- “其他四个入口继续返回”的数量口径也已过期，应收口为“另一个未确认入口”或直接
  明确账户状态/余额两个挡板。

## 建议修改范围

1. `10-transaction-query-field-contract.md`：改正签名、请求对象、枚举归属和 §9 状态。
2. `13-front-api-external.md`：将单个旧行结构拆为 24/25 两套，或直接引用 17 号 §1.2 字段表；
   收窄 `F200003` 示例。
3. `15-交易额外数据标准化-spec.md`：修正当前 DTO 和查询组装完成状态。
4. `05-front代码开发约束.md`：改成两套 QueryData/Item，保留禁止 `R` 包分页和禁止
   `FrontPageResult` 的反例。
5. `WIKI-START.md`：将两处分页泛型改为
   `TableDataInfo<AccountTransDetailItem>` / `TableDataInfo<PlatformTransDetailItem>`。
6. `13-front后续待办.md`：将 TODO-001 当前行为和挡板数量改为当前 3/5 已启用、2/5 待办。
7. 修改后在 18 号 plan 的 T10 记录实际文件清单，再申请重新勾选。

## 验收标准

1. 非历史迁移上下文中，05/10/13/15/WIKI 不再把 `TransactionDetailItem` 或
   `TransactionDetailQueryData` 写成当前契约。
2. 10 号当前签名与 API/Controller/ApplicationService 完全一致。
3. 13 号对外文档中 24/25 行字段与 17 号 §1.2 一致，不发明第三套字段。
4. 所有当前状态文档一致声明：平安交易状态+24+25 已启用，账户状态/余额保留两个挡板。
5. 两个分页接口仍直接返回 `TableDataInfo<T>`，没有 `R` 或 `FrontPageResult` 包装。
6. 未收到用户明确要求时，不修改代码、不新增测试类、不运行测试、不编译、不 commit/push。

## 修复记录（2026-08-19，FIXED_PENDING_REVIEW）

### 实际修改文件

1. `10-transaction-query-field-contract.md`：§1 签名拆两套 QueryData/Item；§4.1 请求对象拆分；§9 平安明细已启用 + 6073 bankQueryId 回查口径
2. `13-front-api-external.md`：§6 拆为 24/25 两套引用 17号 §1.2（不发明第三套字段）；F200003 收窄为"当前仅平安账户状态/余额 2 个查询"
3. `15-交易额外数据标准化-spec.md`：§3.4 旧 DTO 改两套新 DTO；§10 查询组装完成状态更新（3 个已启用）
4. `05-front代码开发约束.md`：请求边界改两套 QueryData；分页返回示例拆分泛型；specialData 约束改两套行 DTO 共同适用；禁止 R/FrontPageResult 反例保留
5. `WIKI-START.md`：两处分页泛型改为两套明确泛型
6. `13-front后续待办.md`：当前行为改 2/5 挡板口径；启用门槛数量修正

### 静态检查证据

- 6 份文档 grep `TransactionDetailItem|TransactionDetailQueryData` → **全部 0 命中**（无当前契约残留）
- 05 号禁止清单中 `R<FrontPageResult<...>>` 反例**保留**（合法历史上下文）
- "五个方法全部抛异常"口径 grep → 0 命中
- git diff 仅涉及 docs 目录 Markdown 文件 + Java 2 文件（P1-014），零 Java 模型/接口改动

### 第二轮修复（2026-08-19，用户复核反馈 6 处遗漏）

用户复核发现 10 号文档仍有 6 处错误，已全部修复：

1. §4.1 请求对象混入 `AccountDetailQueryData` → 删除，25 只写 `PlatformDetailQueryData`
2. §4.1 transType 混入 `AccountDetailType` → 删除，25 只写 `PlatformDetailType`
3. §4.2 25 返回旧字段 `amount/direction` → 改为新 12 主字段集（transAmt/payAcctNo/payAcctName/frontSeqNo/bankMemberCode 等）
4. §5.1 24 transType 枚举未收窄 → 改为"对外仅 04（AccountDetailType）"
5. §5.1 24 返回误写 `PlatformTransDetailItem.specialData` → 改为 `AccountTransDetailItem.specialData`
6. §7 返回结构缺 `TableDataInfo<AccountTransDetailItem>` + `totalPage` → 补齐签名+字段+成功示例

### 未执行的验证

- 未修改 Java/XML/DDL、未新增测试类、未运行测试、未编译、未 commit/push——等待用户确认。

## 复核结论（2026-08-19，重新打开）

上述修复记录只清理了旧类名命中，未覆盖字段语义和任务状态。当前仍有以下可复现问题：

1. `10-transaction-query-field-contract.md` §1 只说明
   `TableDataInfo<PlatformTransDetailItem>`，遗漏
   `TableDataInfo<AccountTransDetailItem>`；
2. §4.1 将 24/25 请求对象和枚举混写在 25 号接口中，并把页大小统一说成 20；
3. §4.2 仍使用旧字段 `amount/direction`，与
   `PlatformTransDetailItem.transAmt` 等 17 号字段契约不一致；
4. §5 将 24 号返回的 `specialData` 错写为
   `PlatformTransDetailItem.specialData`；
5. §7 返回清单遗漏 `TableDataInfo<AccountTransDetailItem>`，
   `TableDataInfo` 固定字段遗漏 `totalPage`。

`18-明细查询对外契约与平安启用-plan.md` 的 T6 和“八条自检”状态已在本次复核中收口；
T10/T11 保持打开，等待上述 10 号契约问题修复。

因此本 Issue 不满足关闭条件，状态从
`FIXED_PENDING_REVIEW` 改为 `OPEN`。

## 第三轮复核（2026-08-19，第二轮修复后）

第二轮已修正 25 返回字段、24/25 DTO 归属和§7主返回列表，但仍不满足关闭条件。

| 对应文档 | 未修复点 | 原因 | 建议修复思路 |
|---|---|---|---|
| `10-transaction-query-field-contract.md` §1 | 第 27 行只说明 `TableDataInfo<PlatformTransDetailItem>` | 正文前面已给出两个分页签名，后续总结遗漏 24 账户明细 | 改为同时列出 `TableDataInfo<PlatformTransDetailItem>` 和 `TableDataInfo<AccountTransDetailItem>`，并保留“不包 R” |
| `10-transaction-query-field-contract.md` §4.1 | 25 请求示例仍使用 `transType=99` | `PlatformDetailType` 对外只允许 `01/02/03`，示例无法通过组装器校验 | 将示例改为 `01`、`02` 或 `03`；`99` 只能作为 Handle 协议白名单说明，不得作对外请求示例 |
| `10-transaction-query-field-contract.md` §5 | 24 请求示例仍使用 `transType=98` | `AccountDetailType` 对外只允许 `04` | 将示例改为 `04`；`98/99` 只保留在银行协议值解释中 |
| `10-transaction-query-field-contract.md` §7 | 业务失败示例缺 `totalPage` | §7 已声明 `code/msg/total/totalPage/rows` 为固定字段，失败示例与本节自相矛盾 | 失败示例增加 `"totalPage": 0` |
| `18-明细查询对外契约与平安启用-plan.md` | 顶部 T10 未勾选，底部却写“T1-T10 全部完成”；已关闭 P1-014 又被写成 `FIXED_PENDING_REVIEW` | 第二轮修复只追加执行记录，没有同步顶层任务和已关闭 Issue 状态 | 在本 Issue 残留项修正前保持 T10/T11 未勾选；底部改为“T1-T9 完成，T10/T11 打开”；P1-014 统一写 `CLOSED` |
| `12-front-implementation-issues/README.md` | “平安退款边界和 report …改为 DEFERRED”的语法会读成两者都暂缓 | 实际状态是平安退款 `OPEN`，report `DEFERRED` | 拆成两句：平安退款边界仍 `OPEN`；report 跨实例查重为 `DEFERRED` |

### 第三轮验收方式

1. 25/24 两个 JSON 请求示例必须分别使用 `PlatformDetailType` / `AccountDetailType` 允许值；
2. §1 和§7 同时出现两套 `TableDataInfo<...>`；
3. 成功和失败分页示例都包含 `code/msg/total/totalPage/rows`；
4. 18 号 T10/T11、底部执行状态和 P1-014 状态不再冲突；
5. README 明确分开平安退款 `OPEN` 与 report `DEFERRED`。

## 第四轮静态复核（2026-08-19，第三轮修复后）

第三轮列出的文档残留现已全部修复：

1. 10 号 §1 同时列出 25 的 `TableDataInfo<PlatformTransDetailItem>` 和 24 的
   `TableDataInfo<AccountTransDetailItem>`，并明确分页不包 `R`；
2. 25/24 请求示例的 `transType` 已分别改为允许值 `01` / `04`；
3. 10 号 §7 的成功、失败示例均包含 `code/msg/total/totalPage/rows`；
4. 18 号 T10 已勾选、T11 保持未勾选，底部统一为 `T1-T10` 完成；
5. 18 号中的 `FRONT-P1-014` 状态统一为 `CLOSED`；
6. README 已分别表述平安退款 `OPEN` 和 report 跨实例查重 `DEFERRED`。
7. WIKI Issue 入口已同步为“无 OPEN、FRONT-P2-008 为 FIXED_PENDING_REVIEW”，不再展示
   第三轮修复前的旧问题描述。

补充 grep 结果：05/10/13/15/WIKI 中不存在把 `TransactionDetailItem` 或
`TransactionDetailQueryData` 当作当前契约的命中；05 号中的
`R<TableDataInfo<...>>/R<FrontPageResult<...>>` 仅存在于明确的禁止示例中。

本轮只做静态复核，未修改 Java/XML/DDL，未运行测试、未编译、未 commit/push。
因此状态由 `OPEN` 改为 `FIXED_PENDING_REVIEW`，等待用户确认后关闭。

## 关闭条件

1. 当前静态证据满足第三轮验收表；
2. 用户确认文档口径与 17 号契约一致后，才能改为 `CLOSED`。

## 第五轮静态复核（2026-08-19，24/25 任务终验）

前四轮列出的10号文档问题已修复，但 T10 要求的其他联动文档仍存在
可复现的当前口径漂移，因此本 Issue 重新打开：

| 对应文档 | 未修复点 | 正确口径/修复思路 |
|---|---|---|
| `15-交易额外数据标准化-spec.md` §4.3 | 中信24/25组装格仍把 Handle 全量协议值当成对外值：25写 `01/02/03/04/99`，24写8个值 | 组装器对外只写25=`PlatformDetailType{01,02,03}`、24=`AccountDetailType{04}`；单独注明中信 Handle 协议白名单保留全量 |
| `15-交易额外数据标准化-spec.md` §5 | 仍农“平安6交易+1查询格”、“4个未启用查询” | 改为平安已有交易状态+24明细+25明细共3个查询组装格；只有账户状态/余额2个固定挡板 |
| `16-交易额外数据标准化-plan.md` 收盘记录 | 仍农“6073 frontSeqNo 与 `bank_user_ssn` 待联调” | 改为已确认的 `6073 frontSeqNo = 原提现应答 queryId = bank_query_id`；不再写待联调 |
| `05-front代码开发约束.md` 中信明细约束 | 仍把当前 Front 键写成 `transactionDate/transactionType` | 改为17号固定的 `specialData.transDate/transType`；24额外允许 `accountType` |

边界：只修上述 Markdown 口径，不修改 Java/银行映射，不夹带平安退款 TODO-002。

本轮未运行测试或编译。上述4处修正前，T10/T11 不得关闭。

## 第六轮静态复核（2026-08-19，问题修复后）

第五轮列出的 4 处漂移中，以下 3 处已修复：

1. 15 号 §4.3 已将组装器对外值收窄为 25=`01/02/03`、24=`04`，并与 Handle 全量白名单分开说明；
2. 15 号 §5 已改为平安 3 个已启用查询组装格，账户状态/余额 2 个固定挡板；
3. 05 号已统一使用 `specialData.transDate/transType`，24 额外允许 `accountType`。

当前剩余 2 处未修复：

| 对应文档 | 未修复点 | 正确口径/修复思路 |
|---|---|---|
| `13-front-api-external.md` §5.4/§5.5 | 章节开头虽已注明 25=`PlatformDetailType{01,02,03}`、24=`AccountDetailType{04}`，后面的“中信 specialData 字段”却仍把 Handle 全量协议类型写成业务系统可传值；24 的 `accountType` 还误标为必填 | 对外字段表必须统一为 25 `transType` 仅 `01/02/03`、24 `transType` 仅 `04`；Handle 保留值只可作为协议层说明，不得混入对外可传值。24 `accountType` 改为选填并注明仅中信生效、平安忽略 |
| `16-交易额外数据标准化-plan.md` 收盘记录 | 仍写“6073 frontSeqNo 与渠道表 `bank_user_ssn` 对应关系待联调验证” | 按 17 号 §0.9 和已关闭 FRONT-P1-014，改为已确认的 `6073 frontSeqNo = 原提现应答 queryId = front_pingan_withdraw_transaction.bank_query_id`；同时明确单笔状态查询才使用原请求 `front_ssn → oriTransSsn`，不得再写待联调 |

本轮未修改业务代码，未编译、未运行测试、未 commit/push。上述两处修正前 T10/T11
仍不得关闭，Issue 状态保持 `OPEN`。退款任务不在本 Issue 范围内。

## 第七轮静态复核（2026-08-19，修复实施后）

第六轮的 2 处残留均已修复：

1. `13-front-api-external.md` §5.4/§5.5：
   - 25 `transType` 对外仅 `PlatformDetailType{01,02,03}`；
   - 24 `transType` 对外仅 `AccountDetailType{04}`；
   - `accountType` 标为选填，并注明仅中信生效、平安 6073 忽略；
   - Handle 其他协议类型明确不对业务系统开放；
2. `16-交易额外数据标准化-plan.md`：固定
   `6073 frontSeqNo = 原提现应答 queryId = bank_query_id`，明确
   `bank_user_ssn` 不参与6073回查，并与单笔状态查询的
   `front_ssn → oriTransSsn` 分开。

相关冲突口径 grep 已清零，`git diff --check` 通过。本轮未编译、未运行测试、未
commit/push，状态改为 `FIXED_PENDING_REVIEW`，等待用户确认后关闭。退款任务不在本
Issue 范围内。

## 第八轮用户复核（2026-08-19，重新打开）

前七轮只清理旧类名命中和协议值口径，未覆盖字段必填语义，仍有 4 处可复现的当前口径漂移，
因此状态从 `FIXED_PENDING_REVIEW` 改回 `OPEN`：

| 对应文档/代码 | 未修复点 | 正确口径 | 修复 |
|---|---|---|---|
| `catering-api/.../FrontQueryApi.java` 24 号 `@Operation` | 把 `accountType` 描述为“需传入”，暗示必填；25 号把页大小写成“中信每页最大 20 条” | 17 号 §1.1：`accountType` 选填、仅中信生效、平安 6073 忽略；`pageNo/pageSize` 选填，pageNo 空默认第 1 页，pageSize 仅期望、银行原生页大小透传 | 注释改写：accountType 明确选填；pageNo/pageSize 选填语义补入 24/25 两个接口注释 |
| `13-front-api-external.md` §5.4（行 520-521） | `pageNo/pageSize` 标必填“是”，pageSize 写成“中信 ≤ 20”（调用方页大小限制） | DTO 仅 `@Positive` 允许为空；Handle 空 pageNo 默认 1；pageSize 仅期望，25 统一 20、6048 无分页一次全返 | pageNo/pageSize 改“否”，pageSize 说明改“仅表达期望，不限制调用方；银行原生页大小透传” |
| `13-front-api-external.md` §5.5（行 548-549） | 同上：pageNo/pageSize 标必填、pageSize 写“中信 ≤ 50” | 24 中信 50、平安 6073 20 | 同上（24 口径） |

`AccountDetailQueryData`/`PlatformDetailQueryData` 只有 `@Positive` 无 `@NotNull`，
`CiticQueryHandle` 对空 pageNo 默认第 1 页、pageSize 不参与银行请求——代码行为与 17 号一致，
本 Issue 只修契约表述。

### 第八轮修复内容

1. `catering-api/catering-api-front/src/main/java/com/chinaums/front/api/FrontQueryApi.java`：
   24 号 `accountType` 改“选填（仅中信生效，平安 6073 忽略）”，24/25 号补充
   `pageNo/pageSize 选填：pageNo 不传默认第 1 页，pageSize 仅表达期望，银行原生页大小透传`；
   25 号删除“中信每页最大 20 条”的调用方限制表述。
2. `13-front-api-external.md` §5.4/§5.5：`pageNo/pageSize` 必填改“否”，
   `pageSize` 说明改为“仅表达期望，不限制调用方；银行原生页大小透传”，
   并补“pageNo 不传默认第 1 页”。§5.5 的 `accountType` 行已正确（选填/仅中信生效），未改。

### 静态检查证据（第八轮）

- `FrontQueryApi.java`：24 号注释 grep `accountType（仅中信生效）` 0 命中（改为“选填”表述）；
  25 号注释 grep `每页最大 20 条` 0 命中；
- `13-front-api-external.md`：§5.4/§5.5 `pageNo/pageSize` 必填列均为“否”；
  grep `中信 ≤ 20|中信 ≤ 50` 0 命中；
- 未修改 DTO/Handle/银行映射，未编译、未运行测试、未 commit/push；
- 状态保持 `OPEN`，待用户确认文档口径后关闭；T10/T11 在 18 号 plan 保持未勾选。
