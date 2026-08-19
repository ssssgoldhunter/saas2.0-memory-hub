# catering-web-test 接口测试工具

> 本文记录 catering-web-test 模块的用途、启动方式、使用说明和当前状态。
> 后续修改该工具时，应同步更新本文。

## 1. 概述

`catering-web-test` 是 `catering-front` 的接口测试工具模块，位于：

```
cateringsass/catering-modules/catering-web-test/
```

**定位**：一个轻量的可运行 Spring Boot 服务（非 JUnit 测试库），通过浏览器 UI 模拟外部业务系统调用 `catering-front` 的所有 API。

**核心技术栈**：Spring Boot 3.5 + FeignClient → `catering-front` + Bootstrap 5 前端 SPA。

## 2. 启动方式

```bash
cd cateringsass/catering-modules/catering-web-test
mvn spring-boot:run -Dmaven.repo.local=/Users/limeng/shares/m2saas
```

启动后访问：`http://localhost:9207`

依赖：
- Nacos（服务发现，用于 Feign 调用 `catering-front`）
- `catering-front` 服务需已启动
- m2saas 仓库里的 `catering-api-front` 需为最新（改过组装器后先 `mvn install -pl catering-api/catering-api-front`，2026-08-19 踩过）

**本地启动与热改注意（2026-08-19 踩坑沉淀）**：
1. 必须进 `catering-modules/catering-web-test` 模块目录启动；仓库根目录 `-pl catering-modules/catering-web-test` 会报
   "Could not find the selected project in the reactor"（master 合并后 pom 结构变化）；
2. Nacos 公共配置默认关闭静态资源映射——本地 `application.yml` 末段已加
   `spring.web.resources.add-mappings: true` 强制开启（本地文档优先于 Nacos 导入），勿删；
3. 改静态资源（js/css/html）对**运行中**的服务不生效：服务读 `target/classes`。临时验证可手动
   `cp src/main/resources/static/* target/classes/static/`；正规做法重启；
4. 静态资源 URL 带 `?v=` 版本参数（index.html 中），每次改 css/js 记得递增版本号，否则浏览器可能缓存旧文件。

## 3. 功能覆盖

覆盖 `catering-front` 全部 13 个 API 方法（5 查询 + 8 交易）：

| 类别 | Tab | API 路径 | 备注 |
|---|---|---|---|
| 查询 | 账户状态查询 | `POST /query/account-status` | specialData={acctNo}，必填、联动自动填充 |
| 查询 | 账户余额查询 | `POST /query/account-balance` | |
| 查询 | 交易状态查询 | `POST /query/transaction-status` | |
| 查询 | 平台交易明细 | `POST /query/platform-transaction-details` | 分页 |
| 查询 | 登记簿明细 | `POST /query/transaction-details` | 分页 |
| 交易 | 转账 | `POST /transaction/transfer` | 需安全确认 |
| 交易 | 消费 | `POST /transaction/consume` | 需安全确认 |
| 交易 | 鉴权转账(平安) | `POST /transaction/transfer-auth` | 需安全确认 |
| 交易 | 授权码发送(平安) | `POST /transaction/resend-transfer-auth-code` | |
| 交易 | 退款 | `POST /transaction/refund` | 需安全确认 |
| 交易 | 提现 | `POST /transaction/withdraw` | 需安全确认 |
| 交易 | 平台付款(中信) | `POST /transaction/platform-pay` | 需安全确认 |
| 交易 | 平台收款(中信) | `POST /transaction/platform-receive` | 需安全确认 |

## 4. UI 使用说明

### 4.1 核心交互流程（web-test 校验规范 2026-08-19：全 Tab 统一两步调用 + 确认弹窗 + 双区域展示）

1. 每个 Tab 顶部选择**租户** → 联动加载该租户的可用账户列表
2. 选择**账户** → 标准账户结构（银行电子账户id、会员号、户名、卡要素）自动填充到**折叠区**
   （`<details>` 默认收起，std-* 输入保留为组装入参载体；页面不展示具体账户参数，
   需要手工调整时展开，见规范第 6 条）
3. 自动生成/固定值字段（bizSystemCode/bizTransactionType/bizTransactionId/bizRequestNo/
   bizOrderNo/bizSubOrderNo/businessDate/businessTime 共 8 个）渲染为 **hidden input**，
   页面只保留用户需要填写的字段（amount/fee/remark、auth 验证码、退款原订单号、查询条件等），
   值在确认弹窗中展示（见规范第 5 条）
4. 点击执行 → **第一步**：前端把标准结构（查询 Tab 为所选账户 + 查询条件）POST 到
   `/api/test/front/assemble/special-data`，后端本地调用
   `FrontSpecialDataAssembler.assemble()` 返回**协议键明文 specialData**；
   组装失败（缺必填/银行不支持该能力）在双区域展示组装入参与失败原因并终止，不发请求
5. **第二步**：**全部 Tab（交易 + 查询 + resendAuth）统一确认弹窗**——参数摘要行
   （含隐藏自动字段、所选账户）、组装出的协议键 specialData、
   **完整请求报文（可编辑 JSON，确认后按编辑后的报文发送；非法 JSON/缺 baseData 回退原报文并提示）**
6. 查询类 5 个 Tab **全部两步组装**（2026-08-19 起）：交易状态查询（{acctNo}/{mchntMbrId}）、
   平台明细/登记簿明细（transDate/transType/accountType 经组装校验）、
   **账户状态/账户余额（2026-08-19 新增组装格：所选账户→pay.bankEAccountId→acctNo；
   余额的 registerAttr 作为组装入参透传；平安侧两格抛「不支持」与 ADAPTER_NOT_READY 挡板一致）**；
   查询 Tab 的 acctNo 输入框已移除，账户参数一律经组装生成
7. 结果区为**请求/应答两个独立区域**（见规范第 4 条）：请求区一次渲染后不再变动，
   应答区独立更新（loading→结果/异常），各自带复制按钮、独立滚动，互不影响

> web-test 校验规范（用户 2026-08-19 口径）：① 所有请求参数经 api 组装工具类转换后请求
> front api（模拟其他 API 调用方式）；② 请求日志全量；③ 应答日志全量；④ 页面请求/应答
> 分两区域独立展示；⑤ 非用户填写参数不在页面展示、确认页展示；⑥ 选账户后不展示具体
> 账户参数、确认页展示。

### 4.2 租户与账户选择

- 每个 Tab **独立选择租户**，互不影响
- 双账户 Tab（转账、消费、鉴权转账、退款）需分别选择付款方和收款方
- **平台交易明细（25）不选用户**（2026-08-19 用户口径）：平台级查询请求不携带用户账号，
  选择租户后自动定位**平台账号**（租户配置第一个账户）仅作上下文，下拉不可手动切换
- **交易日期默认当日**（2026-08-19）：交易状态查询/平台明细/登记簿明细的 transDate
  输入默认填当日 yyyyMMdd（退款原交易日期 originalBusinessDate 不默认，须按原交易实际日期填写）
- 平台付款/平台收款为**单下拉**：平台付款只选收款方、平台收款只选付款方，对端（平台侧）
  自动取租户配置的第一个账户，平台侧门店填入 baseData（dealType/fundTp 为租户级配置，
  由 front 侧联动，不上送请求，见 §4.4）
- 单账户 Tab（提现、授权码发送及所有查询 Tab）只选一个账户

### 4.3 账户联动的标准结构字段（std-*）

2026-08-17 起，交易 Tab 的 specialData 协议键输入框已替换为**标准账户结构**输入（15 号 spec §3），
协议键由组装工具类按 (platformCode, capability) 矩阵生成，页面不再出现协议键名。
2026-08-19 起该组输入收纳进**默认收起的折叠区**（`<details>`），仍由账户下拉联动填充、
仅作为组装入参载体（规范第 ⑥ 条：选账户后不展示具体账户参数）；
如需核对或调整，展开折叠区或直接编辑确认弹窗的完整请求报文：

| Tab | 填充的组 | 来源字段 → 标准字段 |
|---|---|---|
| transfer / consume / transferAuth | pay（下拉一）+ rec（下拉二） | accountNo→bankEAccountId、name→bankAccountName；bankEMemberCode 需手填（租户账户配置可加 `bankEMemberCode` 自动带出） |
| resendAuth | pay + rec（同一所选账户） | accountNo→bankEAccountId；pay 另填 bankEMemberCode |
| refund | oriPay（下拉一）+ oriRec（下拉二） | accountNo→bankEAccountId、name→bankAccountName；另手填 originalBusinessDate（yyyyMMdd，中信） |
| withdraw | pay + 卡要素 | accountNo→bankEAccountId、name→bankAccountName、bankCardNo→pay.bankCard.bankCardNo；cardHolderName 手填（平安需要） |
| platformPay | 仅 rec（下拉） | 平台侧由租户配置隐式定位；contractId 选填 |
| platformReceive | 仅 pay（下拉） | 同上 |

门店信息（payStoreNo/recStoreNo）直接取所选账户 storeNo 填入 baseData，不再经协议键中转；
平台收付固定侧门店取租户第一个账户。

### 4.4 平台收付款资金配置（中信）

`dealType` 和 `fundTp` 是**租户级配置**（`zx_bank_config` 的 `self_dealType` / `self_fund_type`），
由 front 侧租户账户配置联动，**不进入请求 specialData**（2026-08-17 起测试页不再上送，
遵守"不允许调用方覆盖银行账户配置"红线）。

## 5. 测试数据

### 5.1 测试租户配置

数据源：`src/main/resources/application.yml` 的 `catering-web-test.tenants` 段。

**租户 1：LSYM 测试环境**

| 字段 | 值 |
|---|---|
| tenantId | 80001 |
| clientId | X001 |
| dataSourceId | 0 |
| platformCode | zxegj（中信） |
| selfDealType | 03 |
| selfFundType | 015001 |
| defaultRole | 011002 |
| defaultFundType | 001002 |

账户：
| name | accountNo | storeId |
|---|---|---|
| 四川省杨大爷文化传播有限公司 | J04069400000302 | L01010055 |
| 抽佣组织 | J04069400000297 | 1238912213 |

**租户 2：MDL 测试环境**

| 字段 | 值 |
|---|---|
| tenantId | 80002 |
| clientId | X001 |
| dataSourceId | 1 |
| platformCode | zxegj（中信） |
| selfDealType | 03 |
| selfFundType | 015001 |
| defaultRole | 015002 |
| defaultFundType | 015002 |

账户：
| name | accountNo | storeId |
|---|---|---|
| 成都哈哈哈科技有限公司 | J04101700000271 | 90197 |
| 宋小 | J04101700000302 | mdlceshi20260701 |

### 5.2 AccountConfig 字段对照

| Java 字段 | YAML key | 说明 |
|---|---|---|
| `name` | `name` | 企业/个人名称 |
| `accountNo` | `account-no` | 中信账户编号（同时也是 outAcctId） |
| `storeId` | `store-id` | 门店ID |
| `storeNo` | `store-no` | 门店编号 |
| `storeName` | `store-name` | 门店名称 |
| `bankCardNo` | `bank-card-no` | 银行卡号（提现用） |

### 5.3 TenantConfig 字段对照

| Java 字段 | YAML key | 说明 | 来源 |
|---|---|---|---|
| `tenantId` | `tenant-id` | 租户ID | 配置系统 |
| `clientId` | `client-id` | 客户端ID（四必要参数之一，请求缺失时 setupContext 自动补全） | 配置系统 |
| `platformCode` | `platform-code` | 银行平台编码（缺失时自动补全） | 配置系统 |
| `dataSourceId` | `data-source-id` | 数据源ID（四必要参数之一，缺失时自动补全） | 配置系统 |
| `selfDealType` | `self-deal-type` | 自营交易类型(中信) | zx_bank_config |
| `selfFundType` | `self-fund-type` | 自营资金类型(中信) | zx_bank_config |
| `defaultRole` | `default-role` | 默认角色(中信) | zx_bank_config |
| `defaultFundType` | `default-fund-type` | 默认资金类型(中信) | zx_bank_config |

## 6. 架构说明

### 6.1 请求体结构

所有请求统一为两段式：

```json
{
  "baseData": {
    "tenantId": "...",
    "storeId": "...",
    "platformCode": "zxegj",
    "bizSystemCode": "test",
    "bizTransactionType": "TRANSFER",
    "bizTransactionId": "uuid",
    "bizRequestNo": "uuid",
    "bizOrderNo": "...",
    "bizSubOrderNo": "...",
    "amount": 100,
    "fee": 0,
    "currency": "CNY"
  },
  "specialData": {
    "outAcctNo": "...",
    "inAcctNo": "..."
  }
}
```

### 6.2 数据流（web-test 规范 2026-08-19：全 Tab 两步调用）

```
浏览器 UI (index.html + app.js)
  │ 第一步（全 Tab）：标准账户结构(std-*) / 所选账户 + 查询条件
  │   → POST /api/test/front/assemble/special-data
  ▼
FrontTestController.assembleSpecialData
  │ 本地调用（无 Feign）catering-api-front FrontSpecialDataAssembler.assemble()
  │ 日志：test_assemble_request / test_assemble_response（全量明文 payload）
  ▼  返回协议键明文 specialData
浏览器确认弹窗（参数行 + 组装结果 + 可编辑完整报文）
  │ 第二步（全 Tab）：POST /api/test/front/transaction/* 或 /query/*
  │   （specialData 原样带入）
  ▼
FrontTestController (@RequestMapping /api/test/front)
  │ FeignClient 代理；日志：test_request_sending / test_response_received（全量 payload）
  ▼
catering-front (实际业务服务)
  │ 处理并响应
  ▼
浏览器双独立区域展示（请求区渲染后不变；应答区独立更新，各自复制）
```

## 7. 后台实现

- `FrontTestController.java`：通过 Feign 注入 `FrontQueryApi` 和 `FrontTransApi`，透传请求
- `TenantTestProperties.java`：`@ConfigurationProperties` 绑定 YAML 测试数据
- `CateringWebTestApplication.java`：入口，`@EnableFeignClients` 扫描 `catering-api-front`

### 7.1 业务失败响应的透出（2026-08-14 修复）

Feign 调用 `catering-front` 时，若 front 正常返回但业务失败（HTTP 200 + `R.code != 200`，
如银行拒绝交易），公共 `FeignJsonDecoder` 会按设计把该响应转为 `ServiceException`，
Feign 框架再包装为 `DecodeException` 抛出。

`FrontTestController.callFeign/callFeignTable` 捕获 `FeignException`，沿 cause 链提取
`ServiceException` 的真实消息（如"银行拒绝交易"）返回给浏览器 UI：

- `R` 类型接口：`R.fail(真实消息)`；
- `TableDataInfo` 分页接口：`code=500 + msg=真实消息` 的错误对象。

不捕获时异常会落到公共 `GlobalExceptionHandler` 的 `RuntimeException` 兜底分支，
被吞成 `发生未知异常，请联系管理员`，丢失真实业务失败原因，本修复即为解决该问题。

### 7.2 结构化调用日志（2026-08-14 升级）

web-test 后端调用日志由 `[test] >>>/<<<` 文本样式升级为与 catering-front 交易链路一致的结构化
event JSON（工具类 `com.chinaums.web.test.logging.WebTestLogJsonUtils`），覆盖全部 13 个
测试接口及 `/tenants`。每条日志是合法单行 JSON：

- `test_context_prepared`：RequestContext 装配完成（tenantId/clientId/platformCode/dataSourceId）；
- `test_request_sending`：Feign 调用发送前，payload=完整请求体；
- `test_response_received`：调用成功返回，payload=完整响应体，带 `elapsedMs`；
- `test_request_failed`：远程失败，payload=`{exceptionType,message}`，带 `elapsedMs`，保留完整堆栈；
- `test_tenants_loaded`：租户列表加载；
- `test_assemble_request` / `test_assemble_response` / `test_assemble_failed`（2026-08-19 增）：
  组装端点的完整入参 / 完整组装结果 / 失败原因，payload 全量明文
  （此前只记协议键名，按 web-test 规范第 ②③ 条放开为全量，与 2026-08-14 无掩码裁决一致）。

同一次调用的 `test_request_sending` 与 `test_response_received/test_request_failed` **两条**事件
日志共用同一 `traceId`（`test_` 前缀 + UUID）；`test_context_prepared` 独立输出、无 traceId，
metadata 携带 `tenantId/clientId/platformCode/dataSourceId` 定位字段（无 storeId）；字段值按明文输出
（与 front 日志口径一致，2026-08-14 用户确认无掩码）。

### 7.3 账户状态查询缺少 acctNo 的修复（2026-08-14）

`queryAccountStatus`（中信 2058 查询用户状态）协议要求 `specialData.acctNo`（用户编号）必填，
但 web-test 的 acctStatus Tab 此前 `specialData` 恒为空，导致 front 返回
`F100001 specialData.acctNo不能为空`。修复分两层：

1. **前端**：`index.html` acctStatus Tab 新增 `field-acctStatus-acctNo` 输入框（账户选择联动填充）；
   `app.js buildQueryBody` acctStatus 分支改为 `specialData = { acctNo: ... }`；说明文字同步更正。
2. **后端自动补全**：`FrontTestController.setupContext` 在请求 `specialData.acctNo` 缺失时，
   从 `application.yml` 租户配置取**第一个账户**的 `accountNo` 自动补全（用户已选账户时不做覆盖），
   与 `clientId/platformCode/dataSourceId` 的补全逻辑一致。

其余查询 Tab（acctBalance/transStatus/transDetail）acctNo 输入与 specialData 填充已齐备，未改动。

## 8. 维护说明

### 8.1 新增测试租户

1. 在 `application.yml` 的 `catering-web-test.tenants` 添加条目
2. 补充账户列表
3. 从 `zx_bank_config`（配置中心）补充租户级别字段

### 8.2 新增测试账户

1. 在已有租户下的 `accounts` 列表添加条目
2. 填写 `name`、`account-no`、`store-id`、`store-no`、`bank-card-no`

### 8.3 新增 API 测试

1. Controller 新增映射方法 + Feign 调用
2. UI 新增 Tab（index.html）
3. JS 补充 `API_PATH`、`getSpecialSchema`、`buildQueryBody`/`buildTransactionBody`、`fillTabSpecialFields` 等

### 8.4 安全机制

- 交易类 Tab 提交前弹窗二次确认（无安全开关/复选框）
- 查询类 Tab 无安全限制，直接提交
- 交易类 Tab 每次提交前重新生成 `bizTransactionId`/`bizRequestNo`/`bizOrderNo`/`bizSubOrderNo`
  及 businessDate/businessTime（参数表单隐藏、无法手改，防止重复订单号触发 front 重复交易校验）