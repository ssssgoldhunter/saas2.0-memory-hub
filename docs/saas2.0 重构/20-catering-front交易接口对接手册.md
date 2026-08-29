# Catering Front 交易接口对接手册

> 状态：current / verified-against-source
> 核验日期：2026-08-25
> 适用对象：调用 `catering-front` 的业务上游开发人员
> 覆盖范围：当前 `FrontTransApi` 已定义的 8 个交易接口
> 不覆盖：银行 Capability 开发、账户查询、交易查询；这些内容分别见 19、21 号手册

---

## 1. 接入结论

- 服务名：`catering-front`。
- Feign 接口：`com.chinaums.front.api.FrontTransApi`。
- 路径前缀：`/front/v1/transactions`。
- 请求固定为 `FrontRequest<T>`，JSON 只有 `baseData + specialData` 两段。
- 金额统一使用 `Long`，单位人民币分，禁止使用元或浮点数。
- 业务上游推荐使用 `FrontSpecialDataAssembler` 生成银行协议原始 key，避免手写两套映射。
- 只有 `R.code == 200 && data.frontRespCode == "200"` 才是 Front 业务成功。
- `UNKNOWN`、`ACCEPTED`、`PROCESSING` 不是最终成功，必须调用交易状态查询确认。
- Front 内部三域改造不改变本手册任何 API：8 个方法仍由 Transaction 域处理，调用方无需感知
  `FrontTransSlot/frontTransExecute/BankTransCapabilityRegistry`。

### 1.1 当前银行支持矩阵

| 接口 | `FrontTransApi` 方法 | 中信 `zxegj` | 平安 `pajzb` |
|---|---|---|---|
| 普通转账 | `transfer` | 已实现 | 已实现 |
| 短信鉴权转账 | `transferAuth` | 不支持 | 已实现 |
| 发送/重发授权码 | `resendTransferAuthCode` | 不支持 | 已实现 |
| 消费 | `consume` | 已实现 | 已实现 |
| 退款 | `refund` | 已实现 | 已实现 |
| 提现 | `withdraw` | 已实现 | 已实现 |
| 平台付款 | `platformPay` | 已实现 | 不支持 |
| 平台收款 | `platformReceive` | 已实现 | 不支持 |

未支持能力返回 `F200002`，不会返回模拟成功。

---

## 2. 接入准备

### 2.1 Maven 依赖

```xml
<dependency>
    <groupId>com.chinaums</groupId>
    <artifactId>catering-api-front</artifactId>
    <version>${project.version}</version>
</dependency>
```

工程应已启用 OpenFeign 和 Nacos 服务发现。业务代码直接注入：

```java
private final FrontTransApi frontTransApi;
```

不要在上游重新声明一份相同 Feign 接口或复制 DTO。

### 2.2 四个链路请求头

| Header / `BaseRequest` 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `tenantId` | String | 是 | 租户标识 |
| `clientId` | String | 否 | 调用客户端标识 缺失时 Front 从 `tenant_base_config` 回填 |
| `platformCode` | String | 否 | `zxegj` 中信；`pajzb` 平安。缺失时 Front 用 tenantId 从 `tenant_base_config` 回填（2026-08-20 起） |
| `dataSourceId` | String | 否 | 分库编号，如 `2`；缺失时 Front 用 tenantId 从 `tenant_base_config` 回填。显式传入优先于配置值 |

正常 Feign Web 调用由 `catering-common-feign` 自动转发并注入到 `baseData`。异步线程或定时任务没有
原请求上下文时，调用方必须显式建立正确的 RequestContext；不能只填 JSON 而遗漏请求头链路。

### 2.3 实际对接顺序

1. 确认租户已配置目标银行，并能提供正确 `platformCode`。
2. 最少准备 `tenantId/storeId`；`clientId/platformCode/dataSourceId` 可省略，Front 域 ExecuteNode 第④步会从租户基础配置回填（回填后仍缺失则请求失败）。
3. 准备业务唯一号、主子订单号、金额和日期时间。
4. 从账户/企业/绑卡等上游 check 结果取得标准账户要素。
5. 每笔请求新建 `FrontSpecialDataAssembler` 并生成 `specialData`。
6. 构造对应强类型 `FrontRequest<T>`。
7. 调用 `FrontTransApi`。
8. 同时判断顶层 `R.code`、Front 业务码和 `frontStatus`。
9. 保存 `frontSsn/frontQueryId`，供交易状态查询和排障使用。

---

## 3. 公共请求契约

### 3.1 外壳 `FrontRequest<T>`

| 字段 | 类型 | 必填 | 注释 |
|---|---|---|---|
| `baseData` | 具体请求 DTO | 是 | 银行无关的公共业务字段，参与 Bean Validation |
| `specialData` | `JSONObject` | 视接口而定 | 银行和能力特有的动态字段；无字段时传 `{}`，不要传账户静态配置 |

### 3.2 `FrontBaseRequestData` 字段

| 原始字段 | 类型 | 必填 | 来源 | 注释 |
|---|---|---|---|---|
| `platformCode` | String | 是 | Header 自动注入 | 银行平台编码：`zxegj` / `pajzb` |
| `tenantId` | String | 是 | Header 自动注入 | 租户标识 |
| `clientId` | String | 是 | Header 自动注入 | 客户端标识 |
| `dataSourceId` | String | 是 | Header 自动注入 | Front 渠道流水分库键 |
| `storeId` | String | 是 | 业务请求 | 发起本次请求的业务门店 ID，不等同于收付款门店 |

### 3.3 `BaseTransactionBusinessData` 全字段

| 原始字段 | 类型 | 公共校验 | 说明 |
|---|---|---|---|
| `bizRequestNo` | String | 必填，最大 64 | 业务系统本次调用唯一号 |
| `bizSystemCode` | String | 必填，最大 32 | 来源业务系统编码 |
| `bizTransactionType` | String | 必填，最大 32 | 业务交易逻辑类型，不传物理表名 |
| `bizTransactionId` | String | 必填，最大 64 | 来源业务主记录 ID，数字或 UUID 均按字符串传递 |
| `bizSubTransactionId` | String | 选填，最大 64 | 来源业务子记录/明细记录 ID |
| `bizOrderNo` | String | 必填，最大 64 | 业务主订单号 |
| `bizSubOrderNo` | String | 条件必填，最大 64 | 业务子订单号；中信转账/消费/退款必填，平安退款必填 |
| `amount` | Long | 必填，`>0` | 交易或退款金额，人民币分 |
| `fee` | Long | 选填，`>=0` | 手续费，人民币分；多数接口空值按 0 处理 |
| `currency` | String | 选填，默认 `CNY` | 币种，最大 3 |
| `businessDate` | String | 银行条件必填 | `yyyyMMdd`；中信交易类当前要求，平安普通交易不要求 |
| `businessTime` | String | 银行条件必填 | `HHmmss`；中信交易类当前要求，平安普通交易不要求 |
| `remark` | String | 选填 | 备注；长度限制见具体接口 |
| `payStoreNo` | String | 选填，最大 32 | 付款方业务门店编码 |
| `payStoreId` | String | 选填，最大 32 | 付款方业务门店 ID |
| `recStoreNo` | String | 选填，最大 32 | 收款方业务门店编码 |
| `recStoreId` | String | 选填，最大 32 | 收款方业务门店 ID |

### 3.4 公共请求示例

```json
{
  "baseData": {
    "tenantId": "10001",
    "clientId": "consume-service",
    "platformCode": "zxegj",
    "dataSourceId": "2",
    "storeId": "20001",
    "bizRequestNo": "REQ202608190001",
    "bizSystemCode": "CONSUME",
    "bizTransactionType": "TRANSFER",
    "bizTransactionId": "900001",
    "bizSubTransactionId": "90000101",
    "bizOrderNo": "ORD202608190001",
    "bizSubOrderNo": "SUB202608190001",
    "amount": 10000,
    "fee": 0,
    "currency": "CNY",
    "businessDate": "20260819",
    "businessTime": "143022",
    "remark": "业务款项",
    "payStoreNo": "S001",
    "payStoreId": "20001",
    "recStoreNo": "S002",
    "recStoreId": "20002"
  },
  "specialData": {}
}
```

示例展示全部公共字段；实际调用不得使用示例账号、订单号或租户值。

---

## 4. 推荐的 specialData 组装方式

`FrontSpecialDataAssembler` 接收银行无关标准账户结构，输出当前银行需要的原始 key。它不查数据库、
不调银行、不读取租户配置；业务上游必须先从自己的 check/查询结果准备数据。

### 4.1 标准输入字段

| 组装字段 | 类型 | 说明 |
|---|---|---|
| `capability` | `FrontCapability` | 目标交易能力 |
| `platformCode` | String | `zxegj` / `pajzb` |
| `pay` | `AccountInfo` | 付款方/提现方/平台收款用户 |
| `rec` | `AccountInfo` | 收款方/平台付款用户 |
| `oriPay` | `AccountInfo` | 原交易付款方，仅中信退款 |
| `oriRec` | `AccountInfo` | 原交易收款方，仅中信退款 |
| `auth` | `Auth` | 鉴权订单号和验证码，仅平安鉴权转账 |
| `originalBusinessDate` | String | 原交易日期 `yyyyMMdd`，仅中信退款 |
| `refundRemark` | String | 平安退款可选银行备注 |
| `contractId` | String | 中信平台收付可选合同编号 |

`AccountInfo`：

| 字段 | 说明 |
|---|---|
| `bankEAccountId` | 中信电子账号 / 平安见证子账户号 |
| `bankEMemberCode` | 平安交易网会员编号；中信不使用 |
| `bankAccountName` | 银行账户户名 |
| `bankCard.bankCardNo` | 提现绑定卡号 |
| `bankCard.cardHolderName` | 平安提现持卡人户名 |
| `certNo/certType` | 当前预留，不由 Assembler 组装上送 |

### 4.2 通用 Java 用法

```java
FrontSpecialDataAssembler assembler = new FrontSpecialDataAssembler();
assembler.setPlatformCode(platformCode);
assembler.setCapability(FrontCapability.TRANSFER);

FrontSpecialDataAssembler.AccountInfo pay = assembler.newPay();
pay.setBankEAccountId(payAccountNo);
pay.setBankEMemberCode(payMemberCode);
pay.setBankAccountName(payName);

FrontSpecialDataAssembler.AccountInfo rec = assembler.newRec();
rec.setBankEAccountId(recAccountNo);
rec.setBankEMemberCode(recMemberCode);
rec.setBankAccountName(recName);

JSONObject specialData = assembler.assemble();
```

每笔调用新建实例，禁止把 Assembler 注册成单例或跨请求复用。输出是明文业务数据；按当前用户裁决，
业务请求/响应字段（账号、卡号、姓名、手机号、验证码、证件号等）允许明文记录。
`appKey`、私钥、签名材料、签名/认证 Header、`Authorization`、`Cookie`、完整银行 URL 等
非业务凭证仍禁止进入日志。

---

## 5. 公共响应契约

### 5.1 `R<FrontTransResult>`

顶层 `R`：

| 字段 | 类型 | 说明 |
|---|---|---|
| `code` | int | `200` 表示 Front 业务成功；当前业务失败通常为 `500` |
| `msg` | String | 顶层结果说明 |
| `data` | `FrontTransResult` | 交易结果；业务失败时仍可能返回，用于取得 Front 错误码 |

`FrontTransResult` 原始字段：

| 字段 | 类型 | 可能为空 | 说明 |
|---|---|---|---|
| `frontRespCode` | String | 否 | Front 业务码，`"200"` 才是业务成功 |
| `frontRespDesc` | String | 否 | Front 业务说明 |
| `specialData` | JSONObject | 否 | 响应白名单字段，默认 `{}` |
| `frontSsn` | String | 失败早期可能为空 | Front 发送银行时使用的渠道流水号，调用方必须保存 |
| `frontStatus` | enum | 失败早期可能为空 | `INIT/SENDING/ACCEPTED/PROCESSING/SUCCESS/FAILED/UNKNOWN/RETURNED/REFUNDED` |
| `frontQueryId` | String | 是 | 银行/钱包查询关联标识 |
| `frontRemark` | String | 是 | Front 归一化备注，当前多数实现为空 |
| `frontTransDate` | String | 是 | `yyyyMMdd`；中信响应有映射，平安当前通常为空 |
| `frontTransTime` | String | 是 | `HHmmss`；中信响应有映射，平安当前通常为空 |
| `bankRespCode` | String | 是 | 银行原始业务响应码 |
| `bankRespDesc` | String | 是 | 银行原始业务响应说明 |

中信成功时可能在 `data.specialData.USER_SSN` 返回银行侧流水。平安普通交易当前没有额外响应
`specialData`；授权码接口除外。

### 5.1.1 银行业务失败时 frontRespDesc 的取值（2026-08-20 起）

钱包/银行业务失败（`frontRespCode != "200"`）时，应用服务会把 `frontRespDesc` 与顶层
`R.msg` 覆写为银行原始错误描述原文（不转译、不拼接）。取值优先级：
银行层 `sysRespDesc`（原文通常自带错误码，如 `[JU005]用户编号不存在`）>
`sysRespCode` > 平台层 `errInfo` > `errCode`：

```json
{
  "code": 500,
  "msg": "[JU005]用户编号不存在",
  "data": {
    "frontRespCode": "F400004",
    "frontRespDesc": "[JU005]用户编号不存在",
    "frontSsn": "...",
    "specialData": {}
  }
}
```

- `frontRespCode` 仍为 Front 统一码（如 `F400005` 钱包平台拒绝、`F400004` 银行拒绝），
  与描述文本不再一一对应，判断成败必须用 `frontRespCode`/`R.code`；
- 银行层失败取 `sysRespDesc`（原文自带 `[JU005]` 类错误码）；平台层失败取 `errInfo`；
  描述缺失时退回对应错误码本身；
- `specialData` 按约束只存放接口额外返回内容，不包含错误诊断字段（错误要素仅在
  Front 进程内中转，覆写 `frontRespDesc` 后即移除）；
- 渠道流水落库仍保存统一文案（如"钱包平台拒绝请求"），便于按 Front 错误码分类审计；
  银行原始码保存在渠道表 `bank_resp_code/bank_resp_desc` 等明确列；
- Front 内部业务失败（参数校验、路由、配置缺失）没有银行原始错误，`frontRespDesc`
  保持 Front 统一文案或具体校验消息。

### 5.2 判断模板

```java
R<FrontTransResult> response = frontTransApi.transfer(request);

if (response == null || response.getCode() != R.SUCCESS || response.getData() == null) {
    // 调用或 Front 业务失败；不得当作交易成功
    throw new IllegalStateException(response == null ? "Front无响应" : response.getMsg());
}

FrontTransResult result = response.getData();
if (!"200".equals(result.getFrontRespCode())) {
    throw new IllegalStateException(result.getFrontRespDesc());
}

switch (result.getFrontStatus()) {
    case SUCCESS -> handleSuccess(result);
    case ACCEPTED, PROCESSING, UNKNOWN -> scheduleStatusQuery(result.getFrontSsn());
    default -> handleFailure(result);
}
```

不得只看 HTTP 200，也不得只看 `frontSsn` 非空。

---

## 6. 普通转账

```text
POST /front/v1/transactions/transfer
FrontRequest<TransferBusinessData> → R<FrontTransResult>
```

### 6.1 银行条件

| 项目 | 中信 | 平安 |
|---|---|---|
| `businessDate/businessTime` | 必填，`yyyyMMdd/HHmmss` | 当前平安 Capability 不要求 |
| `bizSubOrderNo` | 必填 | 选填；有值时上送 `orderId` |
| `remark` 最大长度 | 256 | 256 |
| 同步成功状态 | `SUCCESS` | `SUCCESS` |

### 6.2 specialData 原始字段

中信：

| 原始 key | 类型 | 必填 | 标准来源 | 注释 |
|---|---|---|---|---|
| `outAcctNo` | String | 是 | `pay.bankEAccountId` | 付款电子账号，Front 加密后上送 |
| `USER_D_NM` | String | 是 | `pay.bankAccountName` | 付款户名 |
| `inAcctNo` | String | 是 | `rec.bankEAccountId` | 收款电子账号，Front 加密后上送 |
| `USER_C_NM` | String | 是 | `rec.bankAccountName` | 收款户名 |

平安：

| 原始 key | 类型 | 必填 | 标准来源 | 注释 |
|---|---|---|---|---|
| `payMemberCode` | String | 是 | `pay.bankEMemberCode` | 付款会员编号（对外语义键，更名自 outAcctId） |
| `outAcctNo` | String | 是 | `pay.bankEAccountId` | 付款见证子账户，Front 加密 |
| `outAcctName` | String | 是 | `pay.bankAccountName` | 付款户名，Front 加密 |
| `recMemberCode` | String | 是 | `rec.bankEMemberCode` | 收款会员编号（对外语义键，更名自 inAcctId） |
| `inAcctNo` | String | 是 | `rec.bankEAccountId` | 收款见证子账户，Front 加密 |
| `inAcctName` | String | 是 | `rec.bankAccountName` | 收款户名，Front 加密 |

`mrchCode/txnClientNo/stlAcctNo/functionFlag/transType` 等由 Front 配置或 Capability 固定，调用方不要传。

---

## 7. 短信鉴权转账（仅平安）

```text
POST /front/v1/transactions/transfer/auth
FrontRequest<AuthTransferBusinessData> → R<FrontTransResult>
```

先调用授权码接口，取得 `authOrderNo`（授权指令号），用户输入验证码后再调用本接口。

请求 specialData 使用对外语义键（9 键，银行协议键由 Capability 内部映射）：

| 键 | 类型 | 必填 | 标准来源 | 注释 |
|---|---|---|---|---|
| `payMemberCode` | String | 是 | `pay.bankEMemberCode` | 付款会员编号 |
| `payAccountNo` | String | 是 | `pay.bankEAccountId` | 付款见证子账户 |
| `payName` | String | 是 | `pay.bankAccountName` | 付款户名 |
| `recMemberCode` | String | 是 | `rec.bankEMemberCode` | 收款会员编号 |
| `recAccountNo` | String | 是 | `rec.bankEAccountId` | 收款见证子账户 |
| `recName` | String | 是 | `rec.bankAccountName` | 收款户名 |
| `authType` | String | 是 | `auth.authType` | 授权类型，本期仅 `SMS`（APP 组装/Capability 双层拒绝） |
| `authOrderNo` | String | 是 | `auth.authOrderNo` | 授权码申请返回的授权指令号，原样回传 |
| `authCode` | String | 是 | `auth.authCode` | 用户验证码明文交给 Front，Front 加密后上送；作为业务 payload 按当前裁决允许明文记录 |

`bizOrderNo` 和 `amount` 必填，`fee` 空按 0，`remark` 最大 120。

组装示例：

```java
assembler.setPlatformCode("pajzb");
assembler.setCapability(FrontCapability.TRANSFER_AUTH);
// pay、rec 同普通转账
FrontSpecialDataAssembler.Auth auth = assembler.newAuth();
auth.setAuthType(AuthType.SMS);
auth.setAuthOrderNo(authOrderNo);   // 接口一返回的 authOrderNo，原样回传
auth.setAuthCode(userInputCode);
JSONObject specialData = assembler.assemble();
```

---

## 8. 发送或重发转账授权码（仅平安）

```text
POST /front/v1/transactions/transfer/auth-code/resend
FrontRequest<TransferAuthCodeBusinessData> → R<FrontTransResult>
```

“重发”是再次调用相同银行申请接口，每次产生新的 `frontSsn`，不传上一次授权指令号；发码允许重发
（每次新 frontSsn 新行，豁免查重，25 号 §3A）。

请求 specialData 使用对外语义键（3 键）：

| 键 | 类型 | 必填 | 标准来源 | 注释 |
|---|---|---|---|---|
| `payMemberCode` | String | 是 | `pay.bankEMemberCode` | 付款会员编号 |
| `payAccountNo` | String | 是 | `pay.bankEAccountId` | 付款见证子账户 |
| `recAccountNo` | String | 是 | `rec.bankEAccountId` | 收款见证子账户（Capability 内部映射 reserve intAcctNo，协议原始拼写） |

`bizOrderNo`、`amount` 必填，`remark` 最大 120。组装时 `auth.authType` 必填（SMS），但只作
组装入参校验、不进 wire specialData。

返回 `R<FrontTransResult>`（公用，无专用结果对象）：

| 字段 | 说明 |
|---|---|
| `frontRespCode/frontRespDesc` | Front 业务结果（失败时 desc=银行原文） |
| `frontStatus` | SUCCESS / UNKNOWN / FAILED |
| `frontSsn` | 本次授权码申请流水 |
| `frontQueryId` | 钱包查询关联号 |
| `specialData.authType` | 授权码类型（本期固定 SMS） |
| `specialData.authOrderNo` | 银行返回并经 Front 解密后的授权指令号（响应 smsIdx 的统一命名，闭环传接口二） |
| `specialData.receiveMobile` | 银行返回并经 Front 解密后的接收手机号 |

组装示例：

```java
assembler.setPlatformCode("pajzb");
assembler.setCapability(FrontCapability.TRANSFER_AUTH_CODE_RESEND);
// pay、rec 同普通转账
FrontSpecialDataAssembler.Auth auth = assembler.newAuth();
auth.setAuthType(AuthType.SMS);
JSONObject specialData = assembler.assemble();
```

---

## 9. 消费

```text
POST /front/v1/transactions/consume
FrontRequest<ConsumeBusinessData> → R<FrontTransResult>
```

`ConsumeBusinessData` 当前没有额外字段，继承全部公共交易字段。中信和平安的 `specialData` 与普通转账
完全相同，条件必填和备注长度也同普通转账。

Front 保留独立消费入口和独立消费渠道表；业务上游不能用 `transfer()` 代替 `consume()`。

### 9.1 `catering-consume` 当前接入状态

已存在 `ConsumeAssembleCheck`、`SpecialDataAssembleCheck` 和 `TransSlot.assembledSpecialData`，但当前：

- `ConsumeAssembleCheck.buildRequest()` 仍显式抛 TODO 异常；
- 未挂入消费 LiteFlow 资源链；
- 未发现正式 `FrontTransApi.consume()` 调用点。

实际补齐顺序应为：账户/企业 check → `ConsumeAssembleCheck` 填 pay/rec → 写回
`assembledSpecialData` → 交易节点构造 `FrontRequest<ConsumeBusinessData>` → 调 `frontTransApi.consume()` →
处理三层结果。不得把现有 check 骨架当成已完成接入。

---

## 10. 退款

```text
POST /front/v1/transactions/refund
FrontRequest<RefundBusinessData> → R<FrontTransResult>
```

### 10.1 RefundBusinessData 额外字段

| 原始字段 | 类型 | 必填 | 注释 |
|---|---|---|---|
| `originalBizOrderNo` | String | 是 | 原交易业务主订单号 |
| `originalBizSubOrderNo` | String | 是 | 原交易业务子订单号 |
| `originalBizTransactionId` | String | 选填 | 原业务主记录 ID；平安退款渠道记录关联使用，中信不使用 |
| `originalBizSubTransactionId` | String | 选填 | 原业务子记录 ID；平安退款渠道记录关联使用，中信不使用 |
| `refundReason` | String | 选填 | 中信映射退款备注，最大 100；平安银行备注不取此字段 |

本次退款自身的 `bizOrderNo + bizSubOrderNo` 也必须填写，`amount` 是退款金额，单位分。

### 10.2 中信退款 specialData

| 原始 key | 类型 | 必填 | 标准来源 | 注释 |
|---|---|---|---|---|
| `ORI_USER_D_ID` | String | 是 | `oriPay.bankEAccountId` | 原付款用户编号 |
| `ORI_USER_D_NM` | String | 是 | `oriPay.bankAccountName` | 原付款用户名 |
| `ORI_USER_C_ID` | String | 是 | `oriRec.bankEAccountId` | 原收款用户编号 |
| `ORI_USER_C_NM` | String | 选填 | `oriRec.bankAccountName` | 原收款用户名 |
| `ORI_USER_TRANS_DT` | String | 是 | `originalBusinessDate` | 原交易日期，`yyyyMMdd` |

中信还要求本次 `businessDate/businessTime`。Front 使用真退款 `/refund + bizFunc=23`，按
`originalBizOrderNo + originalBizSubOrderNo` 定位；不会查本地原中信渠道表补字段。

### 10.3 平安退款 specialData

| 原始 key | 类型 | 必填 | 注释 |
|---|---|---|---|
| `remark` | String | 选填 | 银行退款备注，来自 Assembler 的 `refundRemark` |

业务上游不要传原账户、原会员号、原 Front 流水或原交易日期。Front 会按
`tenantId + originalBizOrderNo + originalBizSubOrderNo` 精确查询平安原 transfer/consume 渠道表：

- 未命中、两表同时命中或单表多条均失败；
- 原 `frontSsn` 作为银行 `oriTransSsn`；
- 原日期、收付款账户和会员号从同一渠道记录取得；
- 同步成功状态为 `ACCEPTED`，需要状态查询确认。

---

## 11. 提现

```text
POST /front/v1/transactions/withdraw
FrontRequest<WithdrawBusinessData> → R<FrontTransResult>
```

### 11.1 中信 specialData

| 原始 key | 类型 | 必填 | 标准来源 | 注释 |
|---|---|---|---|---|
| `acctNo` | String | 是 | `pay.bankEAccountId` | 提现电子账号 |
| `WITH_ACCNAME` | String | 是 | `pay.bankAccountName` | 提现账户户名 |
| `cardNoEnc` | String | 是 | `pay.bankCard.bankCardNo` | 绑定卡号；调用方传明文，Front 加密 |

中信还要求 `businessDate/businessTime`，`remark` 最大 512，同步成功为 `SUCCESS`。

### 11.2 平安 specialData

| 原始 key | 类型 | 必填 | 标准来源 | 注释 |
|---|---|---|---|---|
| `payMemberCode` | String | 是 | `pay.bankEMemberCode` | 提现会员编号（对外语义键，更名自 outAcctId） |
| `acctNo` | String | 是 | `pay.bankEAccountId` | 提现见证子账户 |
| `nameEnc` | String | 是 | `pay.bankAccountName` | 客户户名 |
| `cardNoEnc` | String | 是 | `pay.bankCard.bankCardNo` | 绑定卡号 |
| `userNameEnc` | String | 是 | `pay.bankCard.cardHolderName` | 持卡人户名，不能用账户户名替代 |
| `certNo` | String | 选填 | 当前需调用方直传 | 有值时 Front 加密为银行 `certNoEnc`；Assembler 当前不组装该预留字段 |

平安 `remark` 最大 512；同步成功为 `ACCEPTED`，必须保存 `frontSsn` 并查询终态。

---

## 12. 平台付款与平台收款（仅中信）

```text
POST /front/v1/transactions/platform-pay
POST /front/v1/transactions/platform-receive
FrontRequest<PlatformTransferBusinessData> → R<FrontTransResult>
```

两者都继承公共交易字段，需要 `businessDate/businessTime`，`remark` 最大 256。平台侧使用租户中信
自有资金登记簿，业务上游不传平台银行账号。

### 12.1 平台付款 `2041`

| 原始 key | 类型 | 必填 | 标准来源 | 注释 |
|---|---|---|---|---|
| `inAcctNo` | String | 是 | `rec.bankEAccountId` | 用户收款账号 |
| `inAcctNm` | String | 是 | `rec.bankAccountName` | 用户收款户名 |
| `contractId` | String | 选填 | `contractId` | 合同编号 |

### 12.2 平台收款 `2042`

| 原始 key | 类型 | 必填 | 标准来源 | 注释 |
|---|---|---|---|---|
| `outAcctNo` | String | 是 | `pay.bankEAccountId` | 用户付款账号 |
| `outAcctNm` | String | 是 | `pay.bankAccountName` | 用户付款户名 |
| `contractId` | String | 选填 | `contractId` | 合同编号 |

`dealType` 和 `fundTp` 当前从租户账户配置 `self_dealType/self_fund_type` 读取。旧文档要求调用方传这两个
字段的说法已废弃；调用方不得通过 `specialData` 覆盖。

---

## 13. 完整 Java 调用案例

以下案例使用普通转账，其他接口替换 DTO、capability 和 API 方法即可。

```java
TransferBusinessData data = new TransferBusinessData();
data.setStoreId(storeId);
data.setBizRequestNo(requestNo);
data.setBizSystemCode("CONSUME");
data.setBizTransactionType("TRANSFER");
data.setBizTransactionId(transactionId);
data.setBizSubTransactionId(subTransactionId);
data.setBizOrderNo(orderNo);
data.setBizSubOrderNo(subOrderNo);
data.setAmount(10_000L); // 100.00 元，单位分
data.setFee(0L);
data.setBusinessDate("20260819");
data.setBusinessTime("143022");
data.setRemark("业务款项");

FrontSpecialDataAssembler assembler = new FrontSpecialDataAssembler();
assembler.setPlatformCode(platformCode);
assembler.setCapability(FrontCapability.TRANSFER);

FrontSpecialDataAssembler.AccountInfo pay = assembler.newPay();
pay.setBankEAccountId(payAccountNo);
pay.setBankEMemberCode(payMemberCode);
pay.setBankAccountName(payName);

FrontSpecialDataAssembler.AccountInfo rec = assembler.newRec();
rec.setBankEAccountId(recAccountNo);
rec.setBankEMemberCode(recMemberCode);
rec.setBankAccountName(recName);

FrontRequest<TransferBusinessData> request = new FrontRequest<>();
request.setBaseData(data);
request.setSpecialData(assembler.assemble());

R<FrontTransResult> response = frontTransApi.transfer(request);
FrontTransResult result = response == null ? null : response.getData();
if (response == null || response.getCode() != R.SUCCESS || result == null
    || !"200".equals(result.getFrontRespCode())) {
    String message = result != null ? result.getFrontRespDesc()
        : response != null ? response.getMsg() : "Front无响应";
    throw new IllegalStateException(message);
}

saveFrontReference(result.getFrontSsn(), result.getFrontQueryId());
if (result.getFrontStatus() != FrontTransactionStatus.SUCCESS) {
    scheduleStatusQuery(result.getFrontSsn());
}
```

`tenantId/clientId/platformCode/dataSourceId` 由 Feign 上下文注入；若调用场景没有拦截器上下文，必须先
建立上下文，不能在示例中硬编码真实租户或敏感账户。

---

## 14. 错误处理与重试规范

| 场景 | 处理 |
|---|---|
| `F100001` | 修正请求字段，不重试同一错误请求 |
| `F100003/F100004` | 检查租户银行配置和请求银行 |
| `F200001/F200002/F200003` | 不重试；确认银行支持或等待适配完成 |
| `F300001` | 视为重复请求，查询原交易，不再次发起交易 |
| `F400001` | 可确认通信失败；是否重新发起由业务幂等策略决定 |
| `F400002` 或 `frontStatus=UNKNOWN` | 禁止直接重发，先调用交易状态查询 |
| `F400003` | Front/银行响应契约异常，保留定位号并排障 |
| `F400004/F400005` | 明确业务拒绝，按 `frontRespDesc` 处理，不盲目重试 |
| `F900001` | 系统异常，保留安全定位信息并联系维护人员 |

---

## 15. 联调检查表

- [ ] 使用工程现有 `FrontTransApi` 和 DTO，没有复制契约。
- [ ] Header 中四个字段完整，`storeId` 已填写。
- [ ] 金额使用分，`amount>0`，`fee>=0`。
- [ ] 中信交易的 `businessDate/businessTime` 格式正确。
- [ ] 需要子订单号的接口已填写 `bizSubOrderNo`。
- [ ] specialData 由每次新建的 Assembler 生成，或严格使用本文原始 key 白名单。
- [ ] 未传 `bizFunc/chnlNo/path/appKey/stlAcctNo` 等 Front 内部值。
- [ ] 调用方业务日志未记录账号、卡号、姓名、手机号、验证码、证件号、密钥或完整 specialData；
      Front 最终 Sender 的完整明文钱包 body 日志属于服务内部既定口径，不要求上游复制。
- [ ] 同时判断 `R.code`、`frontRespCode` 和 `frontStatus`。
- [ ] 已保存 `frontSsn/frontQueryId`。
- [ ] `ACCEPTED/PROCESSING/UNKNOWN` 已进入查询确认流程，没有直接重发。
- [ ] 平安退款原交易在 Front 渠道表中可被唯一定位。
- [ ] 平台收付没有由调用方传 `dealType/fundTp` 或伪造平台账号。
