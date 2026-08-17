# 交易额外数据标准化执行计划

> 前置阅读：[15-交易额外数据标准化-spec.md](15-交易额外数据标准化-spec.md)（契约与矩阵的唯一事实来源，本计划只排顺序，不重复定义）
> 纪律：每阶段结束跑一次编译，红了先修再进下一阶段；除标注外不新增测试；所有新代码注释密度与现有 Handle 一致

## Phase 0 基线确认（只读）

1. `mvn compile -pl catering-api/catering-api-front,catering-modules/catering-front -am -DskipTests` → BUILD SUCCESS（2026-08-17 已验证）；
2. `cd catering-modules/catering-web-test && mvn compile -DskipTests` → BUILD SUCCESS；
3. 通读 spec §3/§4/§5，确认理解 pay/rec 命名红线与 13 转换器矩阵。

## Phase 1 api-front 模型层（无行为变更，纯增量+改名）

1. 新建 `catering-api/catering-api-front/src/main/java/com/chinaums/front/api/model/request/FrontAccountInfo.java`、`FrontBankCard.java`（字段见 spec §3.1，@Data + @Schema 注解风格对齐同包）；
2. 新建 `AuthInfo.java`（authOrderNo/authCode）；`BaseTransactionBusinessData` 加可选字段 `private AuthInfo auth;`；
3. `RefundBusinessData` 加 `originalBusinessDate`（yyyyMMdd，@Schema 说明与 originalBizOrderNo 成组必填）；
4. `PlatformTransferBusinessData` 加 `contractId`（选填）；
5. `AuthTransferBusinessData` 改名 `AuthBusinessData`：改类名 + 文件名，全库更新引用（grep `AuthTransferBusinessData`：PingAnTransactionHandle、CiticTransactionHandle 的 UNSUPPORTED 注释如有、FrontTransactionApi/Controller/ApplicationService、FrontRequestValidateNode、FrontInvocationLogAspect、web-test 若有）；
6. 编译。

## Phase 2 转换器层（新增，不改存量）

1. 新建包 `com.chinaums.front.channel.assemble`：`SpecialDataAssembler` 接口、`SpecialDataAssemblerRegistry`（注册/查找不到的行为对齐 `TransactionHandleRegistry`，复用 `BankCapabilityKey`）；
2. 按 spec §4 矩阵逐个实现 13 个转换器（建议先中信转账作为样板，再横向铺开）：
   - `CiticTransferAssembler`（TRANSFER+CONSUME 共用一个类内部两 capability？**否**——每 capability 一个类，TRANSFER/CONSUME 映射相同可共用一个抽象父类）；
   - 中信：Transfer、Consume、Withdraw、Refund、PlatformPay、PlatformReceive；
   - 平安：Transfer、Consume、TransferAuth、TransferAuthCodeResend、Withdraw、Refund（空实现）；
   - 全部键名走 `*ContractKeys` 常量；缺字段抛 `FrontException(INVALID_REQUEST)`，消息格式 `specialData.pay.bankEAccountId不能为空`；
3. `BankRequestContext` 增加 `assembledSpecialData` 字段与访问器（不动既有 `specialData()`）；
4. 编译。

## Phase 3 LiteFlow 节点接入

1. 新建公共节点 `SpecialDataAssembleNode`（对齐现有 7 节点的写法：取 flow context 中已解析的 bankCode+capability → registry.get(...).assemble(request) → 写入 BankRequestContext）；未注册 capability（中信 TRANSFER_AUTH 等不支持组合）走既有 `CAPABILITY_NOT_SUPPORTED` 错误路径；
2. `catering-modules/catering-front/src/main/resources/liteflow/front-flow.xml`：**仅 8 条交易链**在 route 后插入 `THEN(..., specialDataAssemble, ...)`；查询 5 链不动；
3. 同步更新 classes 下重复的 front-flow.xml（如 target/classes 有副本以 src 为准）；
4. 编译。

## Phase 4 Handle 改造（先中信后平安，逐能力小步提交）

1. 中信 `CiticTransactionHandle` 六个方法：删除 `requireSpecialData` 逐键校验；`context.specialData().getString(...)` 全部改 `context.assembledSpecialData().getString(...)`；加密调用不变；
   - refund：`ORI_USER_TRANS_DT` 来源从 specialData 改为 assembled（值由转换器从 baseData.originalBusinessDate 写入）；yyyyMMdd 校验移入转换器；
   - platformPay/Receive：`contractId` 来源改 assembled（转换器从 baseData.contractId 写入）；
2. 平安 `PingAnTransactionHandle` 六个方法：同上；transferAuth 的 messageOrderNo/messageCheckCode、resend 的 intAcctNo 注意拼写常量；refund 不改（本来就查表）；
3. 每改完一个银行编译一次；
4. 自检：`grep -n "requireSpecialData\|specialData().getString" *TransactionHandle.java` 交易类应为 0（查询 Handle 不动）。

## Phase 5 web-test 改造

1. `static/js/app.js`：
   - `fillTabSpecialFields(prefix, acct, role)` 重写：产出 `pay`/`rec`/`oriPay`/`oriRec` 标准对象（accountNo→bankEAccountId、name→bankAccountName、bankCardNo→pay.bankCard.bankCardNo）；平台付款只填 rec、平台收款只填 pay；提现填 pay+bankCard；
   - `buildTransactionBody`：鉴权 Tab 附 `baseData.auth={authOrderNo,authCode}`；退款 Tab 附 `baseData.originalBusinessDate`；平台收付附 `baseData.contractId`（可空）；
2. `static/index.html`：鉴权 Tab 加 authOrderNo/authCode 两个输入；退款 Tab 加 originalBusinessDate（date picker，yyyyMMdd）；平台收付 Tab 加 contractId（选填）；各 Tab specialData 说明文案更新；
3. `FrontTestController`：`setupContext` 的 acctNo 自动补全逻辑仅服务查询接口，交易接口不再依赖，确认无干扰即可；
4. web-test 单独编译 + 启动冒烟（13 个 Tab 逐个构造请求，浏览器 Network 面板确认 specialData 为标准结构）。

## Phase 6 文档同步（按 spec §8 清单逐项）

05（约束改写）、06/07/08（契约 specialData 章节重写为标准结构+矩阵引用）、13（API 示例）、
14（web-test §4.3 联动表）、WIKI-START（注册 15/16 号文档）、12-issues P1-002 补充关闭注记
（散装校验由 15 号 spec 转换器取代，非重开）。

## Phase 7 终验（spec §10 全量自检）

1. 三模块编译绿；
2. 四条 grep 验收（requireSpecialData 清零 / payer|payee 清零 / 转换器数 13 / 交易链含节点查询链不含）；
3. 输出执行报告：每个 Phase 的实际改动文件清单 + 自检结果，交用户复核。

## 回滚策略

Phase 1-3 均为纯新增（除改名），可整体 revert；Phase 4 是行为切换点——若中途放弃，revert Handle 改动即可恢复协议键直传（转换器与节点留存无害）。
