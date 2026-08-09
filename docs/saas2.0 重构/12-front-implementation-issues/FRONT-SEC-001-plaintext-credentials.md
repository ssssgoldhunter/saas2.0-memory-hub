# FRONT-SEC-001 Front 配置存在明文凭据和密钥

- 状态：DEFERRED
- 类型：安全治理
- 影响：ShardingSphere 环境配置和 Front Nacos 配置中的敏感凭据进入当前提交及 Git 历史。

## 已确认范围

- `shardingsphere-config-dev.yaml`
- `shardingsphere-config-uat.yaml`
- `shardingsphere-config-prod.yaml`
- `script/config/nacos/catering-front.yml`

## 后续处理

1. 识别所有已暴露数据库密码、SM2 私钥及其他凭据，过程中不在日志或文档复制真实值。
2. 先完成凭据轮换，再把配置改为环境变量、密钥管理服务或部署平台安全注入。
3. 制定 Git 历史清理方案并评估对现有分支、标签和协作者的影响。
4. 历史重写、强制推送和远端凭据操作必须获得用户单独明确授权。
5. 本安全事项不与当前 Front 功能 issue 混改。
