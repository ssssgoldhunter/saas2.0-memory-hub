# 交易额外数据（specialData）标准化 Spec

> Wiki 入口：[WIKI-START.md](./WIKI-START.md)
> 状态：approved-for-implementation（2026-08-17 用户逐条确认；同日两次架构修正：
> ①组装位置改为 catering-consume 的 flow 节点两步调用；②最终形态为 **catering-api-front 实例工具类**
> `FrontSpecialDataAssembler`（本地调用，不服务化、不 Feign，front 服务零改动），consume 侧 check
> 按能力维度组织。2026-08-17 晚已实施：工具类 + 7 个 check 骨架落地，见 16 号实施记录）
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

目标：业务方只向**组装工具类**提交**银行无关的标准账户结构**；工具类按
`(platformCode→bankCode, capability)` 组装出**协议键明文 specialData** 返回；业务方
（catering-consume）把返回值原样放入交易请求。front 的交易 API、LiteFlow 链、Handle
**全部维持现状**（仍收协议键 + `requireSpecialData` 校验，作为业务方绕过组装工具直传时的最后防线）。

## 2. 目标架构

```
catering-consume（业务系统，自己的 LiteFlow flow）
    └─ specialData 组装 check（*AssembleCheck：new 工具 → 子类填标准结构 → assemble() → 回填 slot）
          │ 本地方法调用（同 JVM，无网络）
          ▼
catering-api-front 组装工具类 FrontSpecialDataAssembler
    （BankCode, FrontCapability）内部类路由 → 协议键明文 JSONObject
          │
catering-consume 组交易请求（baseData 业务字段 + specialData=组装结果）
          │ Feign: FrontTransactionApi.*
          ▼
front 交易链路（validate → route → contextPrepare → dispatch → Handle）——不改动
```

要点：

- 组装是 catering-api-front 中的**实例工具类**（`com.chinaums.front.api.assemble.FrontSpecialDataAssembler`），
  consume 本地调用，**不服务化、不 Feign**：纯静态映射不查库不调银行，无网络开销与新增失败模式；
- **front 服务零改动**：无新增 Controller/Service/Registry/接口，front-flow.xml、两个 TransactionHandle、
  三个交易 baseData 类、BankRequestContext 全部原样；
- Handle 仍消费协议键 specialData，`requireSpecialData` 逐键校验保留（直传协议键报文的最后防线）；
- 工具类**全实例方法、零 static**：每次组装 `new FrontSpecialDataAssembler()` 用完即弃，禁止单例复用
  （多线程安全靠请求内生命周期，不靠共享）；小对象通过 `newPay()/newRec()/newOriPay()/newOriRec()/newAuth()`
  工厂方法创建并挂到当前实例；嵌套数据类（AccountInfo/BankCard/Auth）为静态嵌套类型（JSON 反序列化需要）；
- 银行路由为**工厂模式**（2026-08-17 晚按用户要求从私有内部类重构）：`assemble()` 校验后经
  `bankAssembler()` 工厂按 `BankCode.fromCode(platformCode)` 创建银行组装类
  （`CiticSpecialDataAssembler` / `PingAnSpecialDataAssembler`，实现 `BankSpecialDataAssembler`
  接口，同包 package-private，非 Spring Bean），银行类内部再按 capability 分发到具体组装方法，
  即 (bank × capability) 两级寻址；新增银行 = BankCode 加枚举 + 新增一个组装类 + 工厂加一个 case +
  api-front 升版本（用户已确认此更新模式）；
- 交易 API 请求结构**不变**：baseData 现有字段 + 协议键 specialData。auth/originalBusinessDate/contractId
  **不进**交易 baseData，它们只是组装工具的入参（见 §3.2）；
- 查询接口（5 个查询能力）不涉及：查询 specialData 仍由调用方按 10 号契约直传。

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
+ `bas_bank_info`（卡号 / 持卡人户名）。**certNo/certType 已进 AccountInfo 作为通用预留字段**
（2026-08-17 用户确认：平安场景可能需要——提现为"会员提现-不验证"模式 6033 故当前非必填；
目前不组装上送，激活时在对应银行组装器加"有则输出"并补矩阵行）；平安提现协议的
`certNoEnc` 维持"不传不上送"行为，`certType` 固定 24 仍由 Handle 处理。

### 3.2 组装工具类结构（唯一新增模型，落 catering-api-front）

```java
// com.chinaums.front.api.assemble.FrontSpecialDataAssembler（@Data，extends BaseRequest，
// 4 参数注入能力保留；implements Serializable，可直接作 web-test 端点入参反序列化）
public class FrontSpecialDataAssembler extends BaseRequest {
    private FrontCapability capability;        // 必填，目标交易能力
    private AccountInfo pay;                   // 按能力必填，见 §4 矩阵
    private AccountInfo rec;
    private AccountInfo oriPay;                // 仅退款
    private AccountInfo oriRec;
    private Auth auth;                         // 仅鉴权转账：{authOrderNo, authCode}
    private String originalBusinessDate;       // 仅退款：原交易日期 yyyyMMdd
    private String contractId;                 // 仅平台收付，选填

    // 小对象工厂：new 即挂到当前实例，返回后逐字段 set（业务方从 slot 各来源对象赋值）
    public AccountInfo newPay();  public AccountInfo newRec();
    public AccountInfo newOriPay();  public AccountInfo newOriRec();  public Auth newAuth();

    // 组装入口：实例方法。校验 capability/platformCode → bankAssembler() 工厂分发
    public JSONObject assemble();
    private BankSpecialDataAssembler bankAssembler();   // switch (BankCode.fromCode) → 银行组装类

    @Data public static class AccountInfo {   // bankEAccountId / bankEMemberCode / bankAccountName
                                              // / certNo / certType（通用预留，目前不上送）/ bankCard
        public BankCard newBankCard();
    }
    @Data public static class BankCard { … }   // bankCardNo / cardHolderName（仅平安提现）
    @Data public static class Auth { … }       // authOrderNo / authCode
}

// 同包独立银行组装类（package-private，实现 BankSpecialDataAssembler 接口，
// 构造持有当次组装数据实例，非 Spring Bean，每次组装新建）：
class CiticSpecialDataAssembler { … }    // 矩阵 §4.1，switch capability → 6 能力
class PingAnSpecialDataAssembler { … }   // 矩阵 §4.2，REFUND 返回空对象
```

说明：

- `auth/originalBusinessDate/contractId` 是**组装时入参**，组装结果已含 messageOrderNo/
  ORI_USER_TRANS_DT/contractId 等协议键，交易请求不再携带这些语义字段；
- 授权是跨银行通用语义，作为独立 `AuthInfo` 语义对象存在，不绑定平安；
- 交易 API 的 `BaseTransactionBusinessData/RefundBusinessData/PlatformTransferBusinessData`
  **不加任何新字段**。

### 3.3 类改名（暂缓，独立清理项，本次不动）

`AuthTransferBusinessData` → `AuthBusinessData`（授权语义独立，非转账变体）。因涉及 front 服务 7 处
文件改动，与"front 零改动"原则冲突，本次不执行，留作独立清理项。

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

### 4.3 查询能力组装（2026-08-17 增，交易状态查询先行）

| 能力 | 中信 | 平安 |
|---|---|---|
| TRANSACTION_STATUS_QUERY | `pay.bankEAccountId` → `acctNo`（被查用户编号） | `pay.bankEMemberCode` → `mchntMbrId`（被查会员编号）；`acctNo` 为平台汇总账户，由 Handle 从租户账户配置读取加密上送，不经组装；原交易定位走 `baseData.frontSsn`（平安必填），不走 specialData |

其余查询能力（账户状态/余额/两类明细）待实现时补格。

### 4.4 矩阵纪律

- 输出键名一律用 `*ContractKeys` 常量（`catering-common-core/.../constant/front/`），组装器不得出现
  字符串字面量键；
- 同一协议键在不同能力下名字不同（outAcctId/outMemberCode、outAcctName/outSubAcctName、
  inAcctNo/acctNo/intAcctNo），必须严格按本矩阵，不得"统一"；
- 平台收付款只取对手方一侧（平台侧由商户配置隐式定位）；
- (中信, TRANSFER_AUTH)/(中信, RESEND)/(平安, PLATFORM_*)/平安 5 个查询能力不在组装范围，
  组装器不存在，请求这些组合返回 `CAPABILITY_NOT_SUPPORTED`。

## 5. 组装工具类设计（catering-api-front，已实现）

- 位置：`com.chinaums.front.api.assemble` 包共 4 个文件：`FrontSpecialDataAssembler`（公开大对象 +
  工厂入口）、`BankSpecialDataAssembler`（接口）、`CiticSpecialDataAssembler` / `PingAnSpecialDataAssembler`
  （同包独立银行组装类，package-private）；
- 入口 `assemble()` 校验：capability 非空、platformCode 非空且能 `BankCode.fromCode`（不得 valueOf）映射，
  失败抛 `FrontException(INVALID_REQUEST / BANK_NOT_SUPPORTED)`，消息带完整路径（如 `pay.bankEAccountId不能为空`）；
- 银行内部类按矩阵逐键组装，**能力映射共 12 个：中信 6 + 平安 6（含平安 REFUND 空实现，返回空 JSONObject）**；
  矩阵外组合（中信 TRANSFER_AUTH/RESEND、平安 PLATFORM_*、双方查询能力）抛 `CAPABILITY_NOT_SUPPORTED`；
  同一物理方法可服务多能力（中信 TRANSFER 与 CONSUME 映射相同，switch 中并列 case）；
- `originalBusinessDate` 的 yyyyMMdd 严格校验（BASIC_ISO_DATE 解析）在工具类内；
- 协议键一律取 `*ContractKeys` 常量，工具类内不得出现字符串字面量键；
- 不查租户配置、不查库、不调银行：纯静态映射，天然幂等。

## 6. front 交易链路：明确不改动

| 位置 | 处置 |
|---|---|
| front 服务整体 | 零改动（无新增 Controller/Service/接口/节点） |
| Handle（中信/平安交易） | 零改动：仍消费协议键 + `requireSpecialData` 逐键校验（直传报文的最后防线） |
| BaseTransactionBusinessData / RefundBusinessData / PlatformTransferBusinessData | 不加字段 |
| BankRequestContext | 不加 assembledSpecialData |
| 查询 5 能力 | 不涉及 |

## 7. catering-consume 侧集成契约（2026-08-17 晚已落地骨架）

组装 check 以**能力维度**组织（不再按银行 × 能力拆分；标准结构是超集，银行差异全部由工具类内部类消化，
check 无需按银行分支），落 `consume/flow/component/base/specialdata/`：

```java
public abstract class SpecialDataAssembleCheck<S> extends NodeComponent {
    // 模板方法 process()（不变段）：
    // 1. S slot = this.getFirstContextBean();                 ← 对齐 ConsumeTrans04 等现有组件取法
    // 2. FrontSpecialDataAssembler assembler = new FrontSpecialDataAssembler();  ← 每次新建,禁止单例复用
    // 3. assembler.setCapability(capability()); assembler.setPlatformCode(RequestContext.getPlatformCode());
    // 4. buildRequest(assembler, slot);                       ← 变化段,子类实现,允许 TODO 占位
    // 5. JSONObject specialData = assembler.assemble();
    // 6. writeBack(slot, specialData);                        ← 回填 slot.assembledSpecialData
    // 7. 失败抛 BaseException 终止链，禁止降级为自行拼协议键
    protected abstract FrontCapability capability();
    protected abstract void buildRequest(FrontSpecialDataAssembler assembler, S slot);
    protected abstract void writeBack(S slot, JSONObject specialData);
}
```

- **7 个子类**（因 consume/fund 两棵树 slot 类型不同，提现与扣款独立成类）：

| check（bean 名） | 能力 | slot 树 | 挂接点（随各链 front 适配时挂入，当前不挂链） |
|---|---|---|---|
| consumeAssembleCheck | CONSUME | consume | chainConsume（ConsumeTrans04 前） |
| refundAssembleCheck | REFUND | consume | chainConsumeRefund（Refund04 前） |
| transferAssembleCheck | TRANSFER | consume | chainTransfer + chainTransferInner（同一类挂两处） |
| transferAuthAssembleCheck | TRANSFER_AUTH | consume | chainConsumeAuth |
| transferAuthCodeResendAssembleCheck | TRANSFER_AUTH_CODE_RESEND | consume | 服务层重发调用点（非独立链） |
| withdrawAssembleCheck | WITHDRAW | consume | 原链已随划付迁移清空，待提现流程重建后落位 |
| deductionAssembleCheck | TRANSFER（扣款走转账，用户确认 2026-08-17） | consume | 原链组件已删，待扣款流程重建后挂接 |

- PlatformPay/PlatformReceive 组装映射保留在工具类中，但 **check 第一期不做**（consume 无调用链，等真实调用方出现再加）；
- `buildRequest` 当前全部 TODO 占位（抛 BaseException，注明计划数据源：pay/rec ← slot.compayInfoMaps、
  bankCard ← basBankInfoMap、auth ← 授权签发结果+用户输入、originalBusinessDate ← 原交易日期），
  等账户体系按 storeNo 定型后补齐；骨架（调用/校验/回填/终止）为实实现；
- slot 已统一：fund 树 slot 随划付迁移删除（2026-08 master 合并后），仅存 consume 树
  `TransSlot.assembledSpecialData`；withdraw/deduction 两个 check 已改指 consume slot；
- **当前未挂链**：老树银行组件本就 stub 待适配，fund 树在线走旧 FacadeApi，挂 TODO-抛异常的 check 会中断在线链路；
  挂接随各链的 front 新 API 适配进行；
- 组装结果单笔交易单次使用，不缓存跨请求复用（验证码/日期类字段时效性强）。

## 8. web-test 改造

- 新增小端点 `POST /api/test/front/assemble/special-data`：入参直接反序列化为
  `FrontSpecialDataAssembler`（继承 BaseRequest，4 参数由 RequestBodyAdvice 注入），后端调
  `assemble()` 返回 specialData，供页面两步展示/注入交易请求；
- UI 账户下拉产出标准结构（pay/rec/oriPay/oriRec + bankCard），鉴权 Tab 填 auth 对象，退款 Tab 填
  originalBusinessDate，平台收付填 contractId（选填）；
- 查询 Tab 维持现状（协议键直传）；
- `14-catering-web-test-使用说明.md` 增补两步调用说明。

## 9. 文档联动清单

| 文档 | 改动 |
|---|---|
| 13-front-api-external | 登记组装工具类（§：FrontSpecialDataAssembler，含标准结构与矩阵引用） |
| 05-front代码开发约束 | 新增组装工具类章节：标准结构入参、矩阵引用、"交易 API 仍收协议键"的双层口径；**"specialData 必须银行协议原始名"条款保留不变**（交易请求仍协议键） |
| 06/07/08 字段契约 | 头部加注：业务方可经组装工具类获取下述协议键，标准结构与矩阵见 15 号 spec |
| WIKI-START.md | 已注册 15/16 号文档 |
| 12-issues/P1-002 | 状态已 CLOSED；补充注记：散装校验保留为直传防线，组装工具类提供上游解法 |

## 10. 明确不做（边界）

1. front 服务零改动（无新接口/新节点/新注册表；AuthTransferBusinessData 改名暂缓为独立清理项）；
2. 查询组装仅交易状态查询落地（§4.3），其余 4 个查询能力暂协议键直传；
3. certNo/certType 组装上送**激活**（已进 AccountInfo 通用预留字段，需要时在对应银行组装器加
   "有则输出"并补矩阵行）／门店→账户配置解析（二期，另行评审配置结构）；
4. 平安退款查表字段补齐（TODO-002 范畴）；
5. 组装结果缓存、工具类鉴权特殊化（本地调用，无此面）；
6. 不新增 JUnit 测试（用户明确：不编译、不跑测试；验证以 web-test 人工两步调用为准）；
7. check 不挂链（挂接随各链 front 适配进行，避免 TODO 中断在线链路）。

## 11. 验收标准（执行方自检 + 用户复核）

1. `mvn compile -pl catering-api/catering-api-front -am` BUILD SUCCESS（2026-08-17 已验证并 install）；
2. `git diff` 确认 front 服务零改动（front-flow.xml、两个 TransactionHandle、三个交易 baseData 类均无变更）；
3. 工具类能力映射数 = 12（中信 6 + 平安 6 含平安退款空实现），全部走 ContractKeys 常量，无字面量协议键；
4. 工具类全实例方法零 static，每次组装 new 实例（类注释已声明禁止单例复用）；
5. `grep -rn "payer\|payee" --include="*.java" catering-api/catering-api-front` 0 命中；
6. consume 侧 7 个 check 骨架就位（buildRequest TODO 占位、基类模板实装），两个 TransSlot 有
   assembledSpecialData 字段；consume 全模块编译因存量欠账（report 包缺失、BaseMerchantFacadeApi 缺失、
   BasTransWithDrawRes 被置空）暂不可用，新增文件的编译验证随存量修复后补做；
7. web-test 交易 Tab 两步调用可用，查询 Tab 行为不变；
8. §9 文档清单全部更新。
