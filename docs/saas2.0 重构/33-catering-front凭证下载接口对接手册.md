# Catering Front 凭证下载接口对接手册

> 状态：current / verified-against-source
> 核验日期：2026-09-07（代码 aa3dc5db，静态核验）
> 历史验证：2026-09-03 渠道能力 UAT 记录见 32 号；充值/TI 待上游接入后验证，本次未复跑测试。
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
- 六个渠道表能力要求 `front_status=SUCCESS`；RECHARGE 按通知表定位，TI 按银行明细定位，不检查渠道行状态。
  银行未返回文件名时 front 兜底 `{bankSsn}.pdf`。
- 已实现中信 `zxegj` 的 8 能力映射；专项 Pack 校验银行非中信时报 `F100004`。
  通过中信配置准备后，传入不支持的凭证 capability 才报 `F200002`。
- 已识别的 FrontException 失败应答 `msg` 带错误码前缀（如 `[F300002] 渠道交易不存在: frontSsn=xxx`）。

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
> front 会按上表链路定位；查询正常完成但未命中时返回 F300002，部署/数据库异常按 §3.2 收口。
> 实际可用性还需满足下述部署前提并完成联调，不以接口契约已提交替代验收。

部署前提：RECHARGE 凭证定位通过 FrontTransPlatformNotifyZxMapper 查询 `trans_platform_notify_zx`，但仓库
三套分片配置仍只声明原 10 张渠道流水表，未声明该通知表且没有 SINGLE 兜底。实际部署规则和表可达性
待确认，不能据定位代码已提交推定该分支已完成分库验收。

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

### 3.2 失败（FrontException 的 msg 带错误码前缀）

```json
{ "code": 500, "msg": "[F300002] 渠道交易不存在: frontSsn=xxx", "data": null }
```

| 错误码 | 含义 | 常见原因 |
|---|---|---|
| F100001 | 请求参数非法 | capability/frontSsn/specialData 缺失或格式错；Header tenantId 缺失或与 body 不一致 |
| F100003 | 租户配置/映射不可用 | 缺租户基础或中信账户配置；无可用租户数据源映射 |
| F100004 | 公共字段与配置冲突 | dataSourceId/clientId/platformCode 与有效配置冲突，或目标银行不是中信 |
| F200002 | 不支持该凭证能力 | 已通过中信 Pack，但传入查询类等非支持矩阵 capability |
| F200003 | 适配器未接入 | 预留 |
| F300002 | 渠道交易不存在 | frontSsn/bizOrderNo 查无记录；TI 24 接口未命中 JJ02 明细 |
| F300003 | 渠道交易不满足凭证下载条件 | 交易非 SUCCESS；bankUserSsn/bankTransDate 缺失；74 补号未返回流水 |
| F4000xx | 钱包/银行通信类错误 | 银行拒绝、应答格式错误等，透传银行描述 |

未预期的 RuntimeException 被应用服务转换为 `R.fail("Front内部异常")`，该分支不带 Front 错误码前缀；
不要假定每个失败 msg 都以 `[Fxxxxxx]` 开头。请求未进入应用服务前的参数绑定/校验按统一异常处理器返回。

日志：入口切面正常收到失败 R 时仍记 front_response_returning；专项不会产生 flow_interrupted。
用实际 traceId/REQ_ID 关联应用服务和 Sender，并从请求 payload 中查 frontSsn/capability；详见 19 §10。

## 4. 调用方须知

1. **frontSsn 从哪来**：发起交易（转账/消费/退款/提现/平台收付款）成功应答里的
   `data.frontSsn`，原样保存后用于凭证下载。
2. **渠道行状态**：六个渠道表能力只读取 SUCCESS 行；处理中/失败行返回 F300003。
   RECHARGE/TI 不查询渠道状态，分别依赖通知行和 24 接口明细。
3. **提现自动补号**：提现应答不含 USER_SSN 键，front 在下载时自动经交易状态查询（74）
   补齐并回填渠道表，首次下载会多一次银行查询，调用方无感。
4. **充值/TI 是"先入账、后凭证"**：充值入金来自银行通知（无同步渠道流水），
   TI 清分入金需要按账户+日期+业务流水号到银行明细中反查，front 已封装；RECHARGE 传 bizOrderNo，TI 必须同时传 acctNo、transDt、bizOrderNo。
5. **PDF 处理**：Base64 解码为 `application/pdf`；web-test 首页"🧾 凭证下载(中信)" tab
   可直接联调（成功后浏览器自动下载 PDF）。
6. **历史交易回补**：2026-09-03 修复前落库的交易行缺银行要素（应答键大小写差异导致），
   转账/消费/退款/提现/平台收付款的**新**交易不受影响；历史行如需下载需另行补偿（未实施）。
