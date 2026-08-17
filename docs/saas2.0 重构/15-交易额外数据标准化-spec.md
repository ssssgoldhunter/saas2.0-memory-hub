# 交易额外数据（specialData）标准化 Spec

> Wiki 入口：[WIKI-START.md](./WIKI-START.md)
> 状态：approved-for-implementation（2026-08-17 用户逐条确认）
> 配套执行计划：[16-交易额外数据标准化-plan.md](16-交易额外数据标准化-plan.md)
> 基线：cateringsass master 分支，2026-08-17（交易明细 transDate/transTime/transType 缩写已合入）

## 1. 背景与目标

现状：交易请求的 `specialData` 由业务方按银行协议原始键名（outAcctNo/USER_D_NM/cardNoEnc/ORI_USER_D_ID…）
直接提供。问题：

1. 业务方必须读银行 Word 文档才知道传什么，SaaS 多租户场景下负担不可接受；
2. 同一业务概念在不同银行、不同能力下键名不同（转账 inAcctName / 鉴权 inSubAcctName / 重发 intAcctNo），
   极易传错；
3. 必填校验散落在各 Handle 的 `requireSpecialData` 逐键调用里，无单一事实来源（即遗留技术债 P1-002）。

目标：业务方只传**银行无关的标准账户结构**；front 在交易链路内部按
`(bankCode, capability)` 组装出协议键 JSONObject，Handle 消费组装结果。组装与校验同源，
P1-002 就地关闭。

## 2. 目标架构

```
业务系统 ── 交易请求(baseData + specialData=标准账户结构) ──► front
   LiteFlow: validate → route（已解析 bankCode+capability）
                → specialDataAssemble（新增节点：注册表取转换器，标准结构 → 协议键 JSONObject，缺失即报错）
                → contextPrepare → dispatch → Handle（SM2 加密 + 上送银行）
```

- 转换器注册表与 `TransactionHandleRegistry` 同构：key = `(BankCode, FrontCapability)` 复合键；
- 转换器输出**明文协议键** JSONObject；SM2 加密保持在 Handle，不引入新加密位置；
- 组装即校验：标准结构缺必填字段时转换器抛 `FrontException(INVALID_REQUEST)`，
  错误消息带完整路径（如 `specialData.pay.bankEAccountId`）；
- 查询接口（5 个查询能力）**本期不动**：specialData 维持现有协议键直传模式。

## 3. 数据结构定义

### 3.1 specialData 标准账户结构（业务方上送，pay/rec 命名，禁止 payer/payee）

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
  "oriRec": { "同 rec，退款定位原交易收款方" },
  "extraData": {}
}
```

字段名来源：lsym 生产库 `bas_company_info`（bank_e_account_id / bank_e_member_code / account_name）
+ `bas_bank_info`（卡号 / 持卡人户名）。**certNo（证件号）不进结构**：按生产模式走绑定卡配置推导
（二期），平安提现协议的 certNoEnc 维持当前"不传不上送"行为。

wire 层仍是 `JSONObject`（`FrontRequest.specialData` 类型不变），front 内部解析为强类型：

```java
// 新增于 catering-api-front：com.chinaums.front.api.model.request
public class FrontAccountInfo implements Serializable {
    private String bankEAccountId;    // 必填（凡用到该角色的能力）
    private String bankEMemberCode;   // 平安能力必填；中信可空
    private String bankAccountName;   // 视能力必填
    private FrontBankCard bankCard;   // 仅提现使用
}
public class FrontBankCard implements Serializable {
    private String bankCardNo;      // 提现必填
    private String cardHolderName;  // 平安提现必填
}
```

### 3.2 baseData 新增（银行无关交易语义，强类型）

| 位置 | 字段 | 说明 |
|---|---|---|
| `BaseTransactionBusinessData` | `AuthInfo auth`（可选） | 授权对象，按能力必填。`AuthInfo { String authOrderNo; String authCode; }`——authOrderNo=授权订单编号（授权发起时系统签发，平安短信指令号）；authCode=授权验证码（用户实时输入）。放基类：授权是跨银行通用语义 |
| `RefundBusinessData` | `String originalBusinessDate` | 原交易日期 yyyyMMdd，与 originalBizOrderNo/originalBizSubOrderNo 成组必填。映射中信 `ORI_USER_TRANS_DT`。业务方发起退款时天然知道原订单日期，**不查本地表**（维持"中信退款不查本地原交易表"既有约束） |
| `PlatformTransferBusinessData` | `String contractId`（可选） | 平台收付合同编号，映射中信 reserve `contractId`，仅业务要求时传 |

### 3.3 类改名

`AuthTransferBusinessData` → `AuthBusinessData`（授权语义独立，非转账变体）。改名后为
`BaseTransactionBusinessData` 空子类，保留作 API 类型语义与鉴权扩展位。

### 3.4 已完成（本轮基线，无需再做）

`TransactionDetailItem` 明细字段已缩写：`transDate / transTime / transType`（查询返回模型），
中信/平安 QueryHandle setter 已同步，10 号契约已更新。

## 4. (bank × capability) 组装矩阵 —— 转换器的唯一事实来源

🔒 = Handle 内 SM2 加密后上送；明文 = 原样上送。转换器一律输出明文值。

### 4.1 中信 CITIC（channel/citic/CiticTransactionHandle.java 消费）

| 能力 | 标准结构来源 | 目标协议键 | 加密 |
|---|---|---|---|
| TRANSFER / CONSUME (27) | pay.bankEAccountId | 顶层 `outAcctNo` | 🔒 |
| | pay.bankAccountName | reserve `USER_D_NM` | 明文 |
| | rec.bankEAccountId | 顶层 `inAcctNo` | 🔒 |
| | rec.bankAccountName | reserve `USER_C_NM` | 明文 |
| WITHDRAW (26) | pay.bankEAccountId | 顶层 `acctNo` | 🔒 |
| | pay.bankAccountName | reserve `WITH_ACCNAME` | 🔒 |
| | pay.bankCard.bankCardNo | 顶层 `cardNoEnc` | 🔒 |
| REFUND (23) | oriPay.bankEAccountId | reserve `ORI_USER_D_ID` | 明文 |
| | oriPay.bankAccountName | reserve `ORI_USER_D_NM` | 明文 |
| | oriRec.bankEAccountId | reserve `ORI_USER_C_ID` | 明文 |
| | oriRec.bankAccountName | reserve `ORI_USER_C_NM`（选填，有则传） | 明文 |
| | baseData.originalBusinessDate | reserve `ORI_USER_TRANS_DT`（yyyyMMdd 校验） | 明文 |
| PLATFORM_PAY (2041) | rec.bankEAccountId | 顶层 `inAcctNo` | 🔒 |
| | rec.bankAccountName | reserve `inAcctNm` | 🔒 |
| | baseData.contractId | reserve `contractId`（选填，有则传） | 明文 |
| PLATFORM_RECEIVE (2042) | pay.bankEAccountId | 顶层 `outAcctNo` | 🔒 |
| | pay.bankAccountName | reserve `outAcctNm` | 🔒 |
| | baseData.contractId | reserve `contractId`（选填，有则传） | 明文 |

### 4.2 平安 PING_AN（channel/pingan/PingAnTransactionHandle.java 消费）

| 能力 | 标准结构来源 | 目标协议键 | 加密 |
|---|---|---|---|
| TRANSFER / CONSUME (01) | pay.bankEMemberCode | 顶层 `mchntMbrId` + reserve `outAcctId` | 明文 |
| | pay.bankEAccountId | 顶层 `outAcctNo` | 🔒 |
| | pay.bankAccountName | reserve `outAcctName` | 🔒 |
| | rec.bankEAccountId | 顶层 `inAcctNo` | 🔒 |
| | rec.bankAccountName | reserve `inAcctName` | 🔒 |
| | rec.bankEMemberCode | reserve `inAcctId` | 明文 |
| TRANSFER_AUTH (45) | pay.bankEMemberCode | 顶层 `mchntMbrId` + reserve `outMemberCode` | 明文 |
| | pay.bankEAccountId | 顶层 `outAcctNo` | 🔒 |
| | pay.bankAccountName | reserve `outSubAcctName` | 🔒 |
| | rec.bankEAccountId | 顶层 `inAcctNo` | 🔒 |
| | rec.bankAccountName | reserve `inSubAcctName` | 🔒 |
| | rec.bankEMemberCode | reserve `inMemberCode` | 明文 |
| | baseData.auth.authOrderNo | reserve `messageOrderNo` | 明文 |
| | baseData.auth.authCode | reserve `messageCheckCode` | 🔒 |
| TRANSFER_AUTH_CODE_RESEND (26) | pay.bankEMemberCode | 顶层 `mchntMbrId` | 明文 |
| | pay.bankEAccountId | 顶层 `acctNo` | 🔒 |
| | rec.bankEAccountId | reserve `intAcctNo`（协议原始拼写，**禁止**改成 inAcctNo） | 🔒 |
| WITHDRAW (01) | pay.bankEMemberCode | 顶层 `mchntMbrId` | 明文 |
| | pay.bankEAccountId | 顶层 `acctNo` | 🔒 |
| | pay.bankAccountName | reserve `nameEnc`（客户户名） | 🔒 |
| | pay.bankCard.bankCardNo | 顶层 `cardNoEnc` | 🔒 |
| | pay.bankCard.cardHolderName | reserve `userNameEnc`（持卡人户名，与 nameEnc 是两个字段） | 🔒 |
| REFUND (02) | **无**（Handle 查渠道表补原交易要素，转换器输出空对象） | — | — |

### 4.3 矩阵纪律

- 键名一律用 `*ContractKeys` 常量（`catering-common-core/.../constant/front/`），转换器不得出现字符串字面量键；
- 平台收付款**只取对手方一侧**（平台侧由商户配置隐式定位），不得要求 pay+rec 同时存在；
- `extraData` 当前为空预留，任何能力不得私自读取其中字段。

## 5. 转换器设计

```java
// 新增包 catering-modules/catering-front/src/main/java/com/chinaums/front/channel/assemble/
public interface SpecialDataAssembler {
    BankCode bankCode();
    FrontCapability capability();
    /** 标准结构 → 明文协议键 JSONObject；缺失必填字段抛 FrontException(INVALID_REQUEST)。 */
    JSONObject assemble(FrontRequest<? extends FrontBaseRequestData> request);
}

@Component
public class SpecialDataAssemblerRegistry {
    // 构造期收集全部 SpecialDataAssembler，按 BankCapabilityKey(bankCode, capability) 注册；
    // 重复注册启动失败（对齐 TransactionHandleRegistry 行为）；
    // get(bankCode, capability) 未注册抛 CAPABILITY_NOT_SUPPORTED。
}
```

- 13 个转换器实现：中信 6 + 平安 6 + 平安 REFUND 空实现（返回空 JSONObject）；
- 每个转换器内嵌一张"字段读取路径 → 协议键常量"映射表（即 §4 矩阵的代码化），
  读取用 fastjson `JSONObject.getObject("pay", FrontAccountInfo.class)` 反序列化标准结构；
- 转换结果写入 `BankRequestContext.assembledSpecialData()`（新增字段，保留原始 `specialData()`
  供持久化/日志使用）；Handle 一律从 `assembledSpecialData()` 取值；
- LiteFlow 落位：`front-flow.xml` 8 条交易链在 `route` 之后、`contextPrepare` 之前插入
  `specialDataAssemble` 节点（新增 1 个公共节点类，总节点数 7 → 8）；查询 5 链不变。

## 6. Handle 改造点

1. 删除各交易方法内 `requireSpecialData(specialData, ...)` 逐键校验，改为消费
   `context.assembledSpecialData()`（校验已由转换器完成）；
2. 取值仍走 `*ContractKeys` 常量 + `sm2Encrypt`（加密位置不变）；
3. 平安鉴权转账：`messageOrderNo`/`messageCheckCode` 改从 `baseData.auth` 经转换器输出；
4. 中信退款：`ORI_USER_TRANS_DT` 改从 `baseData.originalBusinessDate` 经转换器输出（yyyyMMdd 校验保留）；
5. 中信平台收付：`contractId` 改从 `baseData.contractId` 经转换器输出；
6. 平安退款维持 `loadOriginalRefundFields` 查表逻辑不动（TODO-002 另行核对 oriTransDate/原双方四要素）。

## 7. web-test 改造

- `static/js/app.js`：`fillTabSpecialFields` / `buildTransactionBody` 改为产出标准结构
  （账户下拉 → `pay`/`rec` 对象；提现 → `pay` + `bankCard`；退款 → `oriPay`/`oriRec` + baseData.originalBusinessDate；
  鉴权 → baseData.auth；平台收付 → 对手方 + baseData.contractId 选填）；
- `index.html`：鉴权 Tab 增加 authOrderNo/authCode 输入；退款 Tab 增加 originalBusinessDate 输入；
  平台收付 Tab 增加 contractId 输入（选填）；
- `14-catering-web-test-使用说明.md` §4.3 联动表同步重写。

## 8. 文档联动清单

| 文档 | 改动 |
|---|---|
| 05-front代码开发约束 | "specialData 必须银行协议原始名"条款改写为"业务方传标准账户结构（pay/rec），协议键由 front 转换器组装"；P1-002 相关检查项同步 |
| 06-transfer-consume字段契约 | specialData 章节重写为标准结构 + 指向 §4 矩阵 |
| 07-transferAuth-resend 字段契约 | 同上；auth 对象(baseData) + intAcctNo 拼写警示 |
| 08-withdraw-refund-platform-transfer | 同上；originalBusinessDate/contractId 归入 baseData |
| 13-front-api-external | 各交易接口 specialData 示例改为标准结构 |
| WIKI-START.md | 注册本文档与 16 号 plan |
| 12-issues/P1-002 | 状态已 CLOSED（散装 requireSpecialData 校验）；补充关闭注记：散装校验将由本方案转换器统一实现取代，Phase 4 完成后交易 Handle 内 requireSpecialData 清零 |

## 9. 明确不做（边界）

1. 查询类 5 个能力的 specialData 不动（acctNo/registerAttr/transactionDate 等协议键直传）；
2. certNo / 门店→账户配置解析（二期，另行评审配置结构）；
3. 平安退款查表字段补齐（TODO-002 范畴）；
4. 不新增 JUnit 测试（按项目惯例，编译 + web-test 人工验证为准，如需测试由用户当次授权）。

## 10. 验收标准（执行方自检 + 用户复核）

1. `mvn compile -pl catering-api/catering-api-front,catering-modules/catering-front -am` 与
   web-test 单独编译均 BUILD SUCCESS；
2. `grep -rn "requireSpecialData" catering-modules/catering-front/src/main/java/com/chinaums/front/channel/{citic,pingan}/*TransactionHandle.java`
   仅剩 0 处交易类调用（查询 Handle 保留）；
3. `grep -rn "payer\|payee" --include="*.java" catering-api/catering-api-front catering-modules/catering-front` 0 命中；
4. SpecialDataAssembler 实现数 = 13（中信 6 + 平安 6 + 平安退款空实现 1）；
5. front-flow.xml 交易 8 链均含 specialDataAssemble 节点、查询 5 链不含；
6. §8 文档清单全部更新且与矩阵一致。
