# 明细查询对外契约重构与平安启用 Spec（17 号）

> Wiki 入口：[WIKI-START.md](./WIKI-START.md)
> 状态：implementation-review-pending（2026-08-19，FRONT-P1-014/FRONT-P2-009 已关闭；
> FRONT-P1-015 与 FRONT-P2-008 已静态修复，状态为 FIXED_PENDING_REVIEW，等待用户确认）
> 来源依据：`/Users/limeng/WorkBuddy/钱包功能/文档/中信24_25明细查询_平安对齐映射表.md`（v6.10，24 章，
> 本 spec 将其结论固化并按用户裁决修正；执行者以本 spec 为准，原始文档用于字段级溯源）
> 平安原始协议依据：`docs/客户钱包应用平台_接口文档-平安项目(总)v5.5.doc`（提现用途 36 与 6073）
> 配套执行计划：[18-明细查询对外契约与平安启用-plan.md](18-明细查询对外契约与平安启用-plan.md)

## 0. 用户九点裁决（2026-08-18～2026-08-19，本 spec 的最高约束）

1. **24/25 是两个独立接口，请求/返回分开两套**；各自内部中信/平安是同一套请求返回。
   请求侧维持现有键：`specialData.acctNo/transType/transDate(/accountType)` + `baseData.pageNo`
   （对齐映射表的 pageNum 统一写为 pageNo；transType/transDate 即 transType/transDate）；
   **bankAccountCode 与 acctNo 是两个东西**——acctNo 是请求键（用户编号），bankAccountCode 只作返回字段。
2. **24 的 fee 单位 = 分**（对齐映射表 v6.6 写"元"不采纳；全局铁律金额统一分）。
3. **totalPage/totalNum 放 TableDataInfo**（分页壳），不放行级。
4. **对外仅开放 4 个交易类型**（24-04 / 25-01 / 25-02 / 25-03）；中信 Handle 的协议层类型白名单
   **保持全量不删**（对外收窄在组装器/校验层做，后续业务需要放开只改对外白名单）。
5. **commission=0 原样返回**：6073 记录不过滤 commission 空/0，fee 直接返回 0（2026-08-18 裁决，
   推翻文档 11.3"建议过滤"）。
6. **6048 的 frontSeqNo = termSsn**（收款方见证系统流水号；2026-08-18 裁决，替代文档建议的 platSsn）。
7. **totalNum 按文档口径**：中信无原生总记录数 → `TOTAL_PAGE × 银行页大小` 估算（最后页不满时偏大，
   联调后可改置空）；平安 totalNum 直传。
8. **24 分页不做任何对齐**：不考虑每页几行，pageNo 透传、行集与 totalPage 直接按银行原生返回
   （中信 50/页、平安 20/页，调用方自知；不凑页、不聚合）。
9. **平安流水字段分离保存、按协议语义关联**：请求 `transSsn` 保存到渠道表 `front_ssn`；
   应答 `queryId` 保存到 `bank_query_id`（并作为对外 `frontQueryId`）；只有实际应答明确存在
   `USER_SSN/ssn` 时才保存到 `bank_user_ssn`。平安提现用途 36 的应答字段名为 `queryId`，
   但原始文档明确标注其业务含义为 `FrontSeqNo（见证系统流水号）`；6073 明细的
   `frontSeqNo` 与该 `queryId` 是同一银行流水。因此 6073 补业务订单号必须按
   `tenant_id + bank_query_id = frontSeqNo` 查原提现渠道表，不得改查 `bank_user_ssn`，也不得将
   `queryId` 全局重命名为 `ssn`。此处 `FrontSeqNo` 是应答 `queryId` 的业务说明，**不等于**
   原提现请求 `transSsn/front_ssn`；平安单笔状态查询才使用原请求 `frontSsn → oriTransSsn`，
   6073 不得改查 `front_ssn`。

## 1. 对外契约（最终形态）

### 1.1 请求（2026-08-19 修订：请求对象与查询类型枚举均按 24/25 拆分；specialData 键不变）

**请求对象拆分**：`TransactionDetailQueryData` 拆为 `AccountDetailQueryData`（24）/`PlatformDetailQueryData`
（25），字段相同（pageNo/pageSize），仅作 API 类型区分与未来独立演化；`acctNo/transType/
transDate/accountType` **仍在 specialData**（不提升为强类型字段），键与取值不变。

**查询类型枚举拆分**（api-front `model/enums`，同码不同义故必须分开；wire 仍是 code 字符串）：

```java
public enum AccountDetailType { WITHDRAW_FEE("04", "提现手续费"); }        // 24，仅开放此值
public enum PlatformDetailType { TRANSFER_IN("01","转账入金"), REMITTANCE_RETURN("02","退汇"),
    CHANNEL_IN("03","支付渠道入金"); }                                     // 25
```

| 能力 | 请求类型 | specialData（Front 契约键） | baseData |
|---|---|---|---|
| TRANS_DETAIL_QUERY（24） | `FrontRequest<AccountDetailQueryData>` | `acctNo`（必填，用户编号，Handle SM2）、`transType`（枚举 `AccountDetailType`，对外仅 04）、`transDate`（必填 yyyyMMdd）、`accountType`（选填 01/12/13/17；**仅中信生效**，平安 6073 无登记簿类型概念，忽略该键） | `pageNo` |
| PLATFORM_TRANS_DETAIL_QUERY（25） | `FrontRequest<PlatformDetailQueryData>` | `transType`（枚举 `PlatformDetailType`，对外 01/02/03）、`transDate`（必填 yyyyMMdd）；无 acctNo（平台级） | `pageNo` |

组装器 `requireIn` 白名单集合改由两个枚举生成（Handle 协议层白名单继续用 ContractKeys 常量、保持全量）。

- 对齐映射表的 `bankMemberCode`（传空占位）**不落地**——请求侧无此键即占位语义本身；
- `pageSize` 语义不变（仅表达期望，银行固定页大小不可覆盖）。

### 1.2 返回——两套独立行对象 + 分页壳扩展

**24 账户明细 → 新 `AccountTransDetailItem`（11 行级主字段 + specialData）**

| 字段 | 类型 | 中信 24 来源 | 平安 6073 来源 | 转译 |
|---|---|---|---|---|
| mchntMbrId | String | mchntMbrId（壳） | stlAcctNo | 平台账号 |
| bankAccountCode | String | USER_ID | subAcctNo（SM2 解密） | 账户 id |
| userName | String | USER_NAME | subAcctName（SM2 解密） | |
| transType | String | TRANS_TYPE=04/JJ08 | bookingFlag=01 | 统一回填 04 |
| bizOrderNo / bizSubOrderNo | String | MCHNT_ORDER_ID / SUB_ID | 无 → frontSeqNo 按 `tenant_id + bank_query_id` 查原提现渠道表 | 见 §0.9/§3.2 |
| bankMemberCode | String | —（空） | tranNetMemberCode | |
| frontTransSsn | String | REQ_JRN | frontSeqNo | REGISTER_SSN 进 specialData |
| fee | **Long（分）** | TRANS_AMT（元 ×100） | commission（分直传） | 取 commission 非 tranAmt |
| transDate | String | TRANS_DT | tranDate | yyyyMMdd |
| transTime | String | TRANS_TM | tranTime | 对齐表 transTm 即本字段 |
| specialData | JSONObject | 其余字段原样（MCHNT_ID/C_D_FLAG/CUR_AMT/GOAC/OANM/DIGEST/REGISTER_SSN 等） | 其余原样（tranStatus/tranAmt/bookingFlag/bookingMsg/remark/resultNum/startRecordNo 等，解密后放） | 兜底 |

**25 平台明细 → 新 `PlatformTransDetailItem`（12 行级主字段 + specialData，三类型字段集统一）**

| 字段 | 类型 | 中信 25 来源 | 平安 6050（01/03）/ 6048（02）来源 | 转译 |
|---|---|---|---|---|
| mchntMbrId | String | MCHNT_ID（壳） | stlAcctNo | |
| bankAccountCode | String | USER_ID（仅 01 返回） | 6050 subAcctNo（解密）/ 6048 acctNo（解密） | 02/03 中信侧空 |
| userName | String | USER_NM（仅 01 返回） | 6050 inAcctName（解密）/ 6048 查表或空 | |
| transType | String | TRANS_TP=01/02/03 | 6050 按 inAcctType=02→回填 01 / 03→回填 03；6048 固定 02 | |
| transDate | String | TRANS_DT | 6050 accountingDate / 6048 returnDate | |
| transTime | String | TRANS_TM | 无 → **置空**（查表补全为后续增强） | v6.8 拍板 |
| transAmt | **Long（分）** | TRANS_AMT（元 ×100） | tranAmt（分直传，6048 同） | 不÷100 |
| payAcctNo | String | PAY_ACCNO | 6050 inAcctNo（解密）/ 6048 cardNoEnc（解密） | |
| payAcctName | String | PAY_ACCNAME | 6050 inAcctName（解密）/ 6048 nameEnc（解密） | |
| remark | String | REMARK | remark / transNote | |
| frontSeqNo | String | REARK2（仅 01 返回） | 6050 frontSeqNo / 6048 **termSsn**（裁决 §0.6） | |
| bankMemberCode | String | —（空） | 6050 tranNetMemberCode / 6048 空 | |
| specialData | JSONObject | 其余原样（CUR_AMT/C_D_FLAG/JRNO/BKNO/ACSQ/ACTN/FTFL/TSTM/DIGEST/REARK1/REARK3） | 其余原样（ccy/bankName/inAcctType/endFlag/resultNum/startRecordNo/reserve；6048 的 termSsnOut/oriTermSsn/oriPlatSsn/returnReason/bankNo/bankName/termSsn/ssn） | 兜底 |

**TableDataInfo 扩展**：新增 `totalPage`（与既有 `total` 并列；`total` 语义即 totalNum）。
**全链路 TableDataInfo（2026-08-19 用户裁决）**：`FrontPageResult` 中间承接层**废除并删除**——
两个明细 Handle 方法直接返回 `TableDataInfo<AccountTransDetailItem>` / `TableDataInfo<PlatformTransDetailItem>`
（成功 code=200/msg="查询成功"；业务失败 Handle 内填 code=500/空 rows/安全 msg；total/totalPage/rows
一并填好），`FrontQueryApplicationService` 分页结果**纯透传**，API/Controller/Service 三层签名一致。
赋值：
中信两侧 `totalPage=TOTAL_PAGE` 直传、`total=TOTAL_PAGE×银行页大小` 估算（裁决 §0.7，最后页偏大）；
平安 6050/6073 `totalPage=ceil(totalNum/银行原生页大小)`、`total=totalNum` 直传；
6048 无分页壳：totalPage=1、total=List 条数。

**24 分页（50 vs 20）处置**：直接返回银行原生分页，不做任何对齐/凑页/聚合（裁决 §0.8）。
**25 分页**：天然一致（中信 20 = 平安 6050 page 20）；6048 无分页一次全返。

**`TransactionDetailItem` 退役**：被上述两个 DTO 取代（仅两个明细查询消费，无其他引用）。

### 1.3 原对象 → 新对象改造对照（迁移映射，执行者按此逐字段核对）

**请求侧：结构不变，仅枚举收窄**

| 项 | 原状 | 改造后 |
|---|---|---|
| `TransactionDetailQueryData`（24/25 共用） | pageNo/pageSize | **字段不变**（pageSize 注释补"仅期望，银行原生页大小透传：24 中信 50/平安 20、25 统一 20"） |
| specialData 键 | acctNo/transType/transDate/accountType | **键不变**；transType 取值收窄：24 → {04}、25 → {01,02,03}（组装器白名单承担） |

**返回侧：`TransactionDetailItem`（旧，9 字段）拆解迁移**

| 旧字段 | → AccountTransDetailItem（24） | → PlatformTransDetailItem（25） | 说明 |
|---|---|---|---|
| transDate | transDate ✅ | transDate ✅ | 保留 |
| transTime | transTime ✅ | transTime ✅（平安置空） | 保留；对齐表 transTm 即本字段 |
| transType | transType ✅（回填 04） | transType ✅（回填 01/02/03） | 保留 |
| amount | → **fee**（Long 分；中信 TRANS_AMT×100 / 平安 commission 直传，空/0 返回 0） | → **transAmt**（Long 分；中信×100 / 平安直传） | 拆分改名，语义分化 |
| direction | ❌ 降级进 specialData（`C_D_FLAG`） | ❌ 降级进 specialData（`C_D_FLAG`） | 对齐表口径：方向属兜底 |
| remark | ❌ 降级进 specialData（`DIGEST`） | remark ✅（主字段） | 24 无备注主字段 |
| bizOrderNo / bizSubOrderNo | ✅ 保留（平安查渠道表补） | ❌ 删除（v6.7 裁决，25 无业务订单号） | 两接口分化 |
| frontSsn | ❌ 删除 | ❌ 删除 | 24/25 明细均无此主字段 |
| specialData | specialData ✅（兜底容器） | specialData ✅ | 保留 |
| （新增） | mchntMbrId / bankAccountCode / userName / bankMemberCode / frontTransSsn | mchntMbrId / bankAccountCode / userName / bankMemberCode / frontSeqNo / payAcctNo / payAcctName | 银行维度与对手方要素提为主字段 |

**分页壳**：`TableDataInfo` 增加 `totalPage`（total 即 totalNum 语义，赋值规则见上节）。

**API 签名对照（三层同步改泛型）**

| 层 | 原签名 | 新签名 |
|---|---|---|
| FrontQueryApi / Controller / ApplicationService | `TableDataInfo<TransactionDetailItem> queryPlatformTransactionDetails(...)` | `TableDataInfo<PlatformTransDetailItem> ...` |
| 同上 | `TableDataInfo<TransactionDetailItem> queryTransactionDetails(...)` | `TableDataInfo<AccountTransDetailItem> ...` |

**平安接口路由对照（新增实现）**

| 对外调用 | 平安接口 | 备注 |
|---|---|---|
| 24 + transType=04 | 6073（bizFunc=08, queryFlag=2） | 唯一 24 通道 |
| 25 + 01 / 25 + 03 | 6050（bizFunc=04，共用请求） | 返回按 inAcctType 过滤回填 |
| 25 + 02 | 6048（bizFunc=02） | 无日期无分页一次全返；frontSeqNo=termSsn |

## 2. 中信侧改造（CiticQueryHandle）

1. parse 两个方法改产出新 DTO（字段映射见 §1.2；金额 yuanToCent 已有）；
2. Handle 协议层类型白名单**保持全量**（24 八类 + 25 五类 + accountType 四值）；
3. 对外收窄不在 Handle 做——由组装器枚举白名单承担（§4）；
4. 25 的 02/03 类型中信侧不返回 USER_NM/USER_ID/REARK2（协议"仅 01 展示"），对应主字段自然为空。

## 3. 平安侧实现（PingAnQueryHandle，TODO-001 明细两项启用）

### 3.1 接口路由（bizFunc 三态 + 类型分流）

| 对外能力 + transType | 平安接口 | 关键请求差异 |
|---|---|---|
| 24 + 04 | **6073** bizFunc=08 | functionFlag（当日=1 不传 begin/end；历史=2 + begin=end=transDate）、subAcctNo=acctNo（SM2，必传）、queryFlag=2、pageNum |
| 25 + 01 / 25 + 03 | **6050** bizFunc=04（共用同一请求，业务体无 inAcctType） | functionFlag（1当日/2历史，**业务体无 begin/end**）、page |
| 25 + 02 | **6048** bizFunc=02 | 仅 stlAcctNo/mrchCode/txnClientNo（租户配置），**无日期、无分页、一次全返** |

mrchCode/txnClientNo/stlAcctNo 全部走 accountSpecialData（现有 fillAccountReserve 模式）。

### 3.2 返回处理要点

- **SM2 解密**：6073（subAcctNo/subAcctName）；6050（subAcctNo/inAcctNo/inAcctName）；6048（acctNo/cardNoEnc/nameEnc）；
- **过滤**：6073 仅保留 tranStatus=0（成功）；**commission 空/0 不过滤，fee 原样返回 0**（裁决 §0.5）；
  6050 按 inAcctType 过滤（01→02、03→03）后回填 transType；
- **查表补全（仅 24）**：bizOrderNo/bizSubOrderNo 以 6073 `frontSeqNo` 匹配原提现渠道表
  `tenant_id + bank_query_id`，查不到置空。溯源关系为“原提现应答 `queryId`（文档语义
  `FrontSeqNo`）= 6073 行 `frontSeqNo`”；`bank_user_ssn` 仅承接明确返回的 `USER_SSN/ssn`，
  不是本关联的查询列；原提现请求 `transSsn/front_ssn` 只用于单笔状态查询，也不是 6073
  订单补全的查询列；
- **分页三态**：见 §1.2 TableDataInfo；
- frontStatus 判定沿用 PingAnBankResponseChecker。

### 3.3 挡板状态变化

`queryTransactionDetails` / `queryPlatformTransactionDetails` 移除 `pendingIntegration()`；
`queryAccountStatus` / `queryAccountBalance` 按用户裁决继续保留挡板，
`TODO-001` 按此关闭，不再作为待实现项。

## 4. 组装矩阵同步（15 号 spec §4.3 修订）

| 能力 | 枚举白名单修订 |
|---|---|
| TRANS_DETAIL_QUERY | {04}（原八值收窄；98/99 等随业务放开） |
| PLATFORM_TRANS_DETAIL_QUERY | {01, 02, 03}（原五值收窄） |

Handle 层白名单不动（双层：组装器对外口径、Handle 协议口径）。

## 5. web-test

两个明细 Tab：transType 下拉收窄为对外口径（24：04；25：01/02/03）；两步组装不变；
返回展示新 DTO 字段。

## 6. 文档联动

10 号（§4/§5 重写为新契约 + 平安侧）、13 号（§5.4/§5.5 返回对象与平安状态）、15 号 §4.3（白名单修订）、
16 号（收盘记录）、13-front后续待办 TODO-001（明细两项转已启用，账户状态/余额保留挡板后关闭）、
05 号（如涉及平安查询挡板表述，同步为"4 个→2 个并固定保留"）。

## 7. 明确不做

1. 24 分页 50/20 凑页聚合（按银行差异返回）；
2. 25 transTime 查表补全（置空，后续增强）；
3. 对齐表"暂不实现"的 7 个类型（24-01/02/03/05/06、25-04/05）——白名单保留在 Handle，不对外；
4. accountType/registerAttr 语义变化（维持现状选填）。

## 8. 验收标准

1. 三模块 + consume 编译绿；
2. 中信 Handle 协议白名单仍为全量（grep Set.of 常量数不变）；
3. 组装器两格枚举 = {04} / {01,02,03}；
4. 平安明细两方法无 pendingIntegration，账户状态/余额仍有；
5. AccountTransDetailItem/PlatformTransDetailItem 落地、TransactionDetailItem 无引用残留；
6. TableDataInfo 含 totalPage；fee/transAmt 均为分（Long）；
7. §6 文档全部更新。
8. 平安 6073 订单补全固定使用 `tenant_id + bank_query_id = frontSeqNo`；
   `PingAnQueryHandle` 不得使用 `bank_user_ssn` 承担该关联。
