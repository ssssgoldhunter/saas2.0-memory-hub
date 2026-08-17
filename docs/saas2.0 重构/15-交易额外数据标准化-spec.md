# 交易额外数据（specialData）标准化 Spec

> Wiki 入口：[WIKI-START.md](./WIKI-START.md)
> 状态：approved-for-implementation（2026-08-17 用户逐条确认；同日修正组装位置：组装能力以 front API 暴露，由 catering-consume 的 flow 节点调用，**不是** front 交易链上的节点）
> 配套执行计划：[16-交易额外数据标准化-plan.md](16-交易额外数据标准化-plan.md)
> 基线：cateringsass master 分支，2026-08-17（交易明细 transDate/transTime/transType 缩写已合入）

## 1. 背景与目标

现状：交易请求的 `specialData` 由业务方按银行协议原始键名（outAcctNo/USER_D_NM/cardNoEnc/ORI_USER_D_ID…）
直接提供。问题：

1. 业务方必须读银行 Word 文档才知道传什么，SaaS 多租户场景下负担不可接受；
2. 同一业务概念在不同银行、不同能力下键名不同（转账 inAcctName / 鉴权 inSubAcctName / 重发 intAcctNo），
   极易传错；
3. 必填校验散落在各 Handle 的 `requireSpecialData` 逐键调用里，无单一事实来源（遗留问题 P1-002 的
   根因，P1-002 已 CLOSED，本方案提供系统性解法）。

目标：业务方只向 front 的**组装 API** 提交**银行无关的标准账户结构**；front 按
`(platformCode→bankCode, capability)` 组装出**协议键明文 specialData** 返回；业务方
（catering-consume）把返回值原样放入交易请求。front 的交易 API、LiteFlow 链、Handle
**全部维持现状**（仍收协议键 + `requireSpecialData` 校验，作为业务方绕过组装 API 直传时的最后防线）。

## 2. 目标架构

```
catering-consume（业务系统，自己的 LiteFlow flow）
    └─ specialDataAssemble 节点（组装 check：调 front 组装 API → 校验返回 → 注入交易请求）
          │ Feign: FrontAssembleApi.assembleSpecialData(...)
          ▼
front 组装 API（Controller → Service → SpecialDataAssemblerRegistry）
    (BankCode, FrontCapability) → 转换器（13 个绑定）
          │ 标准账户结构 → 协议键明文 JSONObject
          ▼
    返回 R<SpecialDataAssembleResult{ specialData }>
          │
catering-consume 组交易请求（baseData 业务字段 + specialData=组装结果）
          │ Feign: FrontTransactionApi.*
          ▼
front 交易链路（validate → route → contextPrepare → dispatch → Handle）——不改动
```

要点：

- 组装发生在**交易调用之前**、**front 之外**（catering-consume flow 节点内），是两步调用；
- front 交易链 `front-flow.xml` **零改动**（8 交易链 + 5 查询链维持原节点）；
- Handle **零改动**：仍消费协议键 specialData，`requireSpecialData` 逐键校验保留（组装 API 与交易 API
  解耦，交易 API 必须能独立校验直传的协议键报文）；
- 交易 API 请求结构**不变**：baseData 现有字段 + 协议键 specialData。auth/originalBusinessDate/contractId
  **不进**交易 baseData，它们只作为组装 API 的入参（见 §3.2）；
- 查询接口（5 个查询能力）不涉及：查询 specialData 仍由调用方按 10 号契约直传；
- 组装 API 不进 LiteFlow：无编排需求，Controller → Service → Registry 一层直达。

## 3. 数据结构定义

### 3.1 标准账户结构（组装 API 入参，pay/rec 命名，禁止 payer/payee）

```json
{
  "pay": {
    "bankEAccountId": "银行电子账户id（中信账号 / 平安见证子账户号）",
    "bankEMemberCode": "银行电子用户code（平安会员号；中信不使用，可不传）",
    "bankAccountName": "银行账户名称（户名）",
    "bankCard": {
      "bankCardNo": "提现绑定卡号",
      "cardHolderName": "持卡人户名（卡要素，非账户户名；仅平安提现需要）"
    }
  },
  "rec":  { "同 pay 结构，bankCard 一般不传" },
  "oriPay": { "同 pay，退款定位原交易付款方" },
  "oriRec": { "同 rec，退款定位原交易收款方" }
}
```

字段名来源：lsym 生产库 `bas_company_info`（bank_e_account_id / bank_e_member_code / account_name）
+ `bas_bank_info`（卡号 / 持卡人户名）。**certNo（证件号）不进结构**：按生产模式走绑定卡配置推导
（二期），平安提现协议的 certNoEnc 维持"不传不上送"行为。

### 3.2 组装 API 请求/响应对象（全部落 catering-api-front）

```java
/** 组装请求：继承 BaseRequest，自动获得 tenantId/clientId/platformCode/dataSourceId 四参数注入 */
public class AssembleSpecialDataRequest extends BaseRequest {
    private FrontCapability capability;        // 必填，目标交易能力
    private FrontAccountInfo pay;              // 按能力必填，见 §4 矩阵
    private FrontAccountInfo rec;
    private FrontAccountInfo oriPay;           // 仅退款
    private FrontAccountInfo oriRec;
    private AuthInfo auth;                     // 仅鉴权转账：{authOrderNo, authCode}
    private String originalBusinessDate;       // 仅退款：原交易日期 yyyyMMdd
    private String contractId;                 // 仅平台收付，选填
}

public class FrontAccountInfo implements Serializable {
    private String bankEAccountId;
    private String bankEMemberCode;
    private String bankAccountName;
    private FrontBankCard bankCard;            // 仅提现
}
public class FrontBankCard implements Serializable {
    private String bankCardNo;
    private String cardHolderName;             // 仅平安提现
}
public class AuthInfo implements Serializable {
    private String authOrderNo;                // 授权订单编号（授权发起时系统签发，如平安短信指令号）
    private String authCode;                   // 授权验证码（用户实时输入）
}

/** 组装响应：specialData 即业务方要放进交易请求的协议键明文 JSONObject */
public class SpecialDataAssembleResult implements Serializable {
    private JSONObject specialData;
}
```

说明：

- `auth/originalBusinessDate/contractId` 是**组装时入参**，组装结果已含 messageOrderNo/
  ORI_USER_TRANS_DT/contractId 等协议键，交易请求不再携带这些语义字段；
- 授权是跨银行通用语义（其他银行也可能有"授权码+授权订单编号"需求），故作为独立 `AuthInfo`
  对象存在，不绑定平安；
- 交易 API 的 `BaseTransactionBusinessData/RefundBusinessData/PlatformTransferBusinessData`
  **不加任何新字段**。

### 3.3 类改名（保留，独立清理项）

`AuthTransferBusinessData` → `AuthBusinessData`（授权语义独立，非转账变体；改名后为
`BaseTransactionBusinessData` 空子类，保留作 API 类型语义位）。

### 3.4 已完成（基线，无需再做）

`TransactionDetailItem` 明细字段已缩写：`transDate / transTime / transType`（查询返回模型），
中信/平安 QueryHandle setter 已同步，10 号契约已更新。

## 4. (bank × capability) 组装矩阵 —— 转换器的唯一事实来源

🔒 = 交易时 Handle SM2 加密后上送；明文 = 原样上送。**组装 API 一律输出明文协议键**（加密只发生在
交易链 Handle 内，与现状一致）。

### 4.1 中信 CITIC

| 能力 | 标准结构/入参来源 | 目标协议键（进返回 specialData） | 加密 |
|---|---|---|---|
| TRANSFER / CONSUME (27) | pay.bankEAccountId | `outAcctNo` | 🔒 |
| | pay.bankAccountName | `USER_D_NM` | 明文 |
| | rec.bankEAccountId | `inAcctNo` | 🔒 |
| | rec.bankAccountName | `USER_C_NM` | 明文 |
| WITHDRAW (26) | pay.bankEAccountId | `acctNo` | 🔒 |
| | pay.bankAccountName | `WITH_ACCNAME` | 🔒 |
| | pay.bankCard.bankCardNo | `cardNoEnc` | 🔒 |
| REFUND (23) | oriPay.bankEAccountId | `ORI_USER_D_ID` | 明文 |
| | oriPay.bankAccountName | `ORI_USER_D_NM` | 明文 |
| | oriRec.bankEAccountId | `ORI_USER_C_ID` | 明文 |
| | oriRec.bankAccountName | `ORI_USER_C_NM`（选填，有则输出） | 明文 |
| | originalBusinessDate | `ORI_USER_TRANS_DT`（yyyyMMdd 校验在组装器） | 明文 |
| PLATFORM_PAY (2041) | rec.bankEAccountId | `inAcctNo` | 🔒 |
| | rec.bankAccountName | `inAcctNm` | 🔒 |
| | contractId | `contractId`（选填，有则输出） | 明文 |
| PLATFORM_RECEIVE (2042) | pay.bankEAccountId | `outAcctNo` | 🔒 |
| | pay.bankAccountName | `outAcctNm` | 🔒 |
| | contractId | `contractId`（选填，有则输出） | 明文 |

### 4.2 平安 PING_AN

| 能力 | 标准结构/入参来源 | 目标协议键 | 加密 |
|---|---|---|---|
| TRANSFER / CONSUME (01) | pay.bankEMemberCode | `outAcctId`（交易时同时进顶层 mchntMbrId 与 reserve，由 Handle 既有逻辑处理） | 明文 |
| | pay.bankEAccountId | `outAcctNo` | 🔒 |
| | pay.bankAccountName | `outAcctName` | 🔒 |
| | rec.bankEAccountId | `inAcctNo` | 🔒 |
| | rec.bankAccountName | `inAcctName` | 🔒 |
| | rec.bankEMemberCode | `inAcctId` | 明文 |
| TRANSFER_AUTH (45) | pay.bankEMemberCode | `outMemberCode` | 明文 |
| | pay.bankEAccountId | `outAcctNo` | 🔒 |
| | pay.bankAccountName | `outSubAcctName` | 🔒 |
| | rec.bankEAccountId | `inAcctNo` | 🔒 |
| | rec.bankAccountName | `inSubAcctName` | 🔒 |
| | rec.bankEMemberCode | `inMemberCode` | 明文 |
| | auth.authOrderNo | `messageOrderNo` | 明文 |
| | auth.authCode | `messageCheckCode` | 🔒 |
| TRANSFER_AUTH_CODE_RESEND (26) | pay.bankEMemberCode | `outAcctId` | 明文 |
| | pay.bankEAccountId | `acctNo` | 🔒 |
| | rec.bankEAccountId | `intAcctNo`（协议原始拼写，**禁止**改成 inAcctNo） | 🔒 |
| WITHDRAW (01) | pay.bankEMemberCode | `outAcctId` | 明文 |
| | pay.bankEAccountId | `acctNo` | 🔒 |
| | pay.bankAccountName | `nameEnc`（客户户名） | 🔒 |
| | pay.bankCard.bankCardNo | `cardNoEnc` | 🔒 |
| | pay.bankCard.cardHolderName | `userNameEnc`（持卡人户名，与 nameEnc 是两个字段） | 🔒 |
| REFUND (02) | **无**（平安退款 specialData 为空，Handle 查渠道表补原交易要素；组装器返回空 specialData） | — | — |

### 4.3 矩阵纪律

- 输出键名一律用 `*ContractKeys` 常量（`catering-common-core/.../constant/front/`），组装器不得出现
  字符串字面量键；
- 同一协议键在不同能力下名字不同（outAcctId/outMemberCode、outAcctName/outSubAcctName、
  inAcctNo/acctNo/intAcctNo），必须严格按本矩阵，不得"统一"；
- 平台收付款只取对手方一侧（平台侧由商户配置隐式定位）；
- (中信, TRANSFER_AUTH)/(中信, RESEND)/(平安, PLATFORM_*)/平安 5 个查询能力不在组装范围，
  组装器不存在，请求这些组合返回 `CAPABILITY_NOT_SUPPORTED`。

## 5. front 组装 API 设计

### 5.1 API 契约（catering-api-front 新增 Feign 接口）

```java
@FeignClient(name = "catering-front")
public interface FrontAssembleApi {
    @PostMapping("/front/v1/assemble/special-data")
    R<SpecialDataAssembleResult> assembleSpecialData(@RequestBody AssembleSpecialDataRequest request);
}
```

- FrontAssembleController implements FrontAssembleApi → FrontAssembleApplicationService →
  SpecialDataAssemblerRegistry，三层签名一致（对齐现有 FrontTransactionApi 模式）；
- `platformCode → BankCode` 用 `BankCode.fromCode()`（不得 valueOf）；
- 入参校验：capability 非空；platformCode 能映射 BankCode；按矩阵校验角色/字段缺失 →
  `FrontException(INVALID_REQUEST)`，错误消息带完整路径（如 `pay.bankEAccountId不能为空`）；
- 不查租户配置、不查库、不调银行：纯静态映射，天然幂等。

### 5.2 组装器注册表（catering-front 新增）

```java
// 新增包 com.chinaums.front.channel.assemble
public interface SpecialDataAssembler {
    BankCode bankCode();
    FrontCapability capability();
    /** 标准结构 → 明文协议键 JSONObject；缺失必填字段抛 FrontException(INVALID_REQUEST)。 */
    JSONObject assemble(AssembleSpecialDataRequest request);
}

@Component
public class SpecialDataAssemblerRegistry {
    // 构造期收集全部 SpecialDataAssembler，按 BankCapabilityKey(bankCode, capability) 注册；
    // 重复注册启动失败（对齐 TransactionHandleRegistry 行为）；
    // get(bankCode, capability) 未注册抛 CAPABILITY_NOT_SUPPORTED。
}
```

- 13 个绑定：中信 6 + 平安 6 + 平安 REFUND 空实现（返回空 JSONObject）；
- 物理类数可少于 13：中信 TRANSFER 与 CONSUME 映射相同，可共用抽象父类或一类多绑定
  （对齐 Handle `capabilityDefinitions()` 返回 List 的模式）；
- 一个节点/一个 API + 注册表分发，**禁止**在单个组装器里按 capability switch。

## 6. front 交易链路：明确不改动

| 位置 | 处置 |
|---|---|
| front-flow.xml | 零改动（不新增节点） |
| Handle（中信/平安交易） | 零改动：仍消费协议键 + `requireSpecialData` 逐键校验（直传报文的最后防线） |
| BaseTransactionBusinessData / RefundBusinessData / PlatformTransferBusinessData | 不加字段 |
| BankRequestContext | 不加 assembledSpecialData |
| 查询 5 能力 | 不涉及 |

## 7. catering-consume 侧集成契约（2026-08-17 补充组件设计）

组装 check 以**一系列 (银行 × capability) 组件**落地，放
`consume/flow/component/base/platform/`（与 PlatformInfoCheck 并列；withdraw/deduction 所在的
fund flow 与 consume 同属一个 Spring 应用，LiteFlow 按 bean 名引用，无包限制）：

```java
public abstract class AbstractSpecialDataAssembleCheck extends NodeComponent {
    // 模板方法 process()：
    // 1. AssembleSpecialDataRequest req = buildRequest(slot);          ← 变化段，子类实现
    // 2. req.setCapability(capability());                              ← 子类常量
    // 3. frontAssembleApi.assembleSpecialData(req)                     ← Feign 调 front 组装 API
    //    platformCode/tenantId/clientId/dataSourceId 由 Feign 拦截器 + BaseDataRequestBodyAdvice
    //    从请求上下文自动注入，子类不填
    // 4. 校验：R.code==200 且 specialData 非 null（平安退款组装结果为空对象，豁免非空校验）
    // 5. slot.setAssembledSpecialData(result.specialData)              ← 交易组件组 FrontRequest 时取用
    // 6. 失败抛 BaseException 终止链，禁止降级为自行拼协议键
    protected abstract FrontCapability capability();
    protected abstract AssembleSpecialDataRequest buildRequest(/* 对应 slot */);
}
```

- 子类 11 个（bean 名 `zxTransferAssembleCheck` 等）：中信 6（Transfer/Consume/Withdraw/Refund/
  PlatformPay/PlatformReceive）+ 平安 5（Transfer/Consume/TransferAuth/AuthCodeResend/Withdraw）；
- 平安 Refund 免 check：组装结果为空对象，交易组件直接带空 specialData；
- `buildRequest` 允许暂 TODO（从 slot 收集 pay/rec/oriPay/oriRec/bankCard 的逻辑等账户体系定型），
  但 `capability()` 与基类调用/校验/回填段必须实现；
- `consume/flow/slot/TransSlot` 与 `fund/flow/slot/TransSlot` 各增加
  `private JSONObject assembledSpecialData;`；
- 组装结果单笔交易单次使用，不缓存跨请求复用（验证码/日期类字段时效性强）。

## 8. web-test 改造

- 交易 Tab 改为两步模拟 catering-consume：先调组装端点（新增 `POST /api/test/front/assemble/special-data`
  透传 FrontAssembleApi），把返回 specialData 展示/注入交易请求，再发交易；
- UI 账户下拉产出标准结构（pay/rec/oriPay/oriRec + bankCard），鉴权 Tab 填 auth 对象，退款 Tab 填
  originalBusinessDate，平台收付填 contractId（选填）；
- 查询 Tab 维持现状（协议键直传）；
- `14-catering-web-test-使用说明.md` 增补两步调用说明。

## 9. 文档联动清单

| 文档 | 改动 |
|---|---|
| 13-front-api-external | 新增组装 API 登记（§：FrontAssembleApi，含请求/响应结构） |
| 05-front代码开发约束 | 新增组装 API 章节：标准结构入参、矩阵引用、"交易 API 仍收协议键"的双层口径；**"specialData 必须银行协议原始名"条款保留不变**（交易请求仍协议键） |
| 06/07/08 字段契约 | 头部加注：业务方可经组装 API 获取下述协议键，标准结构与矩阵见 15 号 spec |
| WIKI-START.md | 已注册 15/16 号文档 |
| 12-issues/P1-002 | 状态已 CLOSED；补充注记：散装校验保留为直传防线，组装 API 提供上游解法 |

## 10. 明确不做（边界）

1. front 交易链路/Handle/baseData 模型零改动；
2. 查询类 5 能力不涉及；
3. certNo / 门店→账户配置解析（二期，另行评审配置结构）；
4. 平安退款查表字段补齐（TODO-002 范畴）；
5. 组装结果缓存、组装 API 鉴权特殊化（走现有内部调用认证）；
6. 不新增 JUnit 测试（编译 + web-test 人工验证为准，如需测试由用户当次授权）。

## 11. 验收标准（执行方自检 + 用户复核）

1. `mvn compile -pl catering-api/catering-api-front,catering-modules/catering-front -am` 与
   web-test 单独编译均 BUILD SUCCESS；
2. `git diff --stat` 确认 front-flow.xml、`*TransactionHandle.java`、三个交易 baseData 类零改动；
3. SpecialDataAssembler 绑定数 = 13（中信 6 + 平安 6 + 平安退款空 1）；
4. 组装器内无字符串字面量协议键（全部走 ContractKeys 常量）；
5. `grep -rn "payer\|payee" --include="*.java" catering-api/catering-api-front catering-modules/catering-front` 0 命中；
6. web-test 交易 Tab 两步调用可用，查询 Tab 行为不变；
7. §9 文档清单全部更新。
