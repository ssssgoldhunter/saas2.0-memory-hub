# Catering Front 凭证下载接口对接手册

> 状态：current / verified-against-source
> 核验日期：2026-09-03（转账/消费/退款/提现/平台收付款五类已 UAT 实测通过；充值/TI 待上游能力接入后验证）
> 适用对象：需要下载中信银行电子账户交易凭证（回执 PDF）的业务上游开发人员
> 覆盖范围：`CiticFrontFileProcessApi#receiptDownload` 单张凭证下载（bizFunc=02，MSG 模式）
> 不覆盖：批量凭证（申请/状态查询/批量下载，见 `receipt-test.html` 与 19 号手册）；银行 Capability 开发

---

## 1. 接入结论

- 服务名：`catering-front`。
- Feign 接口：`com.chinaums.front.api.citic.CiticFrontFileProcessApi#receiptDownload`。
- 路径：`POST /front/trans/receiptDownload`。
- 请求：**header 必要参数（tenantId 等）+ 请求体 `frontSsn + capability`（+ 能力差异 `specialData`）**。
  三要素（银行流水/银行日期/凭证交易类型）由 front 自查定位，调用方不传、也不需要知道。
- 返回：`R<CiticReceiptDownloadRes>`，`fileName + fileContent`（PDF Base64），
  前端/调用方 Base64 解码即得 PDF 文件。
- **仅成功交易（front_status=SUCCESS）可下载**；银行未返回文件名时 front 兜底 `{bankSsn}.pdf`。
- 中信 `zxegj` 已全量支持 8 能力映射；平安不支持（`F200002`）。
- 失败应答 `msg` 带错误码前缀（如 `[F300002] 渠道交易不存在: frontSsn=xxx`）。

### 1.1 支持矩阵（capability → 中信凭证 TRANS_TYPE）

| capability | 含义 | 凭证 TRANS_TYPE | 定位链路 | 调用方需传 |
|---|---|---|---|---|
| TRANSFER | 转账 | 06 联机支付 | 渠道表 front_citic_transfer_transaction | frontSsn |
| CONSUME | 消费 | 06 联机支付 | 渠道表 front_citic_consume_transaction | frontSsn |
| REFUND | 退款 | 07 联机退款 | 渠道表 front_citic_refund_transaction | frontSsn |
| WITHDRAW | 提现 | 04 智能提现 | 渠道表；缺银行流水时 front 自动经 74 状态查询补号并回填 | frontSsn |
| PLATFORM_PAY | 平台付款 | 12 平台付款 | 渠道表 front_citic_platform_pay_transaction | frontSsn |
| PLATFORM_RECEIVE | 平台收款 | 13 平台收款 | 渠道表 front_citic_platform_receive_transaction | frontSsn |
| RECHARGE | 充值（05 转账入金） | 05 | 中信通知表 trans_platform_notify_zx（frsc_senum） | specialData.bizOrderNo=充值表 transNo |
| TI | 清分入金（03） | 03 | 中信 24 接口明细翻页比对 JJ02+MCHNT_ORDER_ID | specialData.acctNo / transDt / bizOrderNo |

> 充值/TI 的上游交易能力尚未接入（TI 为新增通用能力，交易侧待设计）；当前传入这两类 capability，
> front 会按上表链路定位，查不到即返回 F300002。上游接入后无需再改此接口契约。

## 2. 请求

### 2.1 字段

| 字段 | 位置 | 必填 | 说明 |
|---|---|---|---|
| tenantId | header（body 同步可传） | 是 | 租户；body 缺失时 front 用 header 回填 |
| capability | body | 是 | 原交易能力枚举名（见支持矩阵） |
| frontSsn | body | 普通能力必填；RECHARGE/TI 不传 | 发起交易时 front 返回的渠道流水号 |
| specialData.bizOrderNo | body | RECHARGE/TI 必填 | 充值=充值表 transNo（对应通知表 frsc_senum）；TI=业务系统流水号 |
| specialData.acctNo | body | TI 必填 | 中信账户 |
| specialData.transDt | body | TI 必填 | 原流水日期 yyyyMMdd |

### 2.2 请求示例

普通能力（以转账为例）：

```json
{
  "tenantId": "80001",
  "capability": "TRANSFER",
  "frontSsn": "J040694000000002026090315110263043065744"
}
```

充值：

```json
{
  "tenantId": "80001",
  "capability": "RECHARGE",
  "specialData": { "bizOrderNo": "20260903145026259934669" }
}
```

TI（清分入金）：

```json
{
  "tenantId": "80001",
  "capability": "TI",
  "specialData": {
    "acctNo": "J04069400000297",
    "transDt": "20260903",
    "bizOrderNo": "20260903145026259934669"
  }
}
```

## 3. 响应

### 3.1 成功

```json
{
  "code": 200,
  "msg": "操作成功",
  "data": {
    "fileName": "EMSSBPG2609036057988376941414401.pdf",
    "fileContent": "<PDF Base64>",
    "sysRespCode": "00000"
  }
}
```

- `fileContent` 为 PDF 的 Base64，解码后即凭证文件；`fileName` 为银行返回名，缺省 `{bankSsn}.pdf`。

### 3.2 失败（msg 带 Front 错误码前缀）

```json
{ "code": 500, "msg": "[F300002] 渠道交易不存在: frontSsn=xxx", "data": null }
```

| 错误码 | 含义 | 常见原因 |
|---|---|---|
| F100001 | 请求参数非法 | capability/frontSsn/specialData 缺失或格式错 |
| F100003 / F100004 | 租户银行配置问题 | 租户未配中信账户配置；header/body tenantId 不一致 |
| F200002 | 当前银行不支持该能力 | 传了查询类/平安系能力 |
| F200003 | 适配器未接入 | 预留 |
| F300002 | 渠道交易不存在 | frontSsn/bizOrderNo 查无记录；TI 24 接口未命中 JJ02 明细 |
| F300003 | 渠道交易不满足凭证下载条件 | 交易非 SUCCESS；bankUserSsn/bankTransDate 缺失；74 补号未返回流水 |
| F4000xx | 钱包/银行通信类错误 | 银行拒绝、应答格式错误等，透传银行描述 |

## 4. 调用方须知

1. **frontSsn 从哪来**：发起交易（转账/消费/退款/提现/平台收付款）成功应答里的
   `data.frontSsn`，原样保存后用于凭证下载。
2. **仅成功可下载**：`frontStatus=SUCCESS` 的交易才有银行要素；处理中/失败交易返回 F300003。
3. **提现自动补号**：提现应答不含 USER_SSN 键，front 在下载时自动经交易状态查询（74）
   补齐并回填渠道表，首次下载会多一次银行查询，调用方无感。
4. **充值/TI 是"先入账、后凭证"**：充值入金来自银行通知（无同步渠道流水），
   TI 清分入金需要按账户+日期+业务流水号到银行明细中反查，front 已封装，调用方只给业务流水号。
5. **PDF 处理**：Base64 解码为 `application/pdf`；web-test 首页"🧾 凭证下载(中信)" tab
   可直接联调（成功后浏览器自动下载 PDF）。
6. **历史交易回补**：2026-09-03 修复前落库的交易行缺银行要素（应答键大小写差异导致），
   转账/消费/退款/提现/平台收付款的**新**交易不受影响；历史行如需下载需另行补偿（未实施）。
