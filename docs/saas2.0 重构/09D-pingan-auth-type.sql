-- 09D-pingan-auth-type.sql
-- 存量库加列：平安授权类型 auth_type（用户裁决 2026-08-21：后续需支持 SMS/APP 区分，现在就加）
-- 目标表：front_pingan_transfer_transaction（共表承载 TRANSFER / TRANSFER_AUTH / TRANSFER_AUTH_CODE_RESEND）
-- 语义：仅授权两能力行写入（AuthType 枚举名 SMS/APP）；普通转账行为 NULL；
--       存量历史行不回填（NULL 即代表 SMS-only 历史时期）；APP 开放前新行恒为 'SMS'。
-- 字符集跟随表（utf8mb4/utf8mb4_unicode_ci），仅执行一次。
ALTER TABLE `front_pingan_transfer_transaction`
    ADD COLUMN `auth_type` VARCHAR(8) DEFAULT NULL
    COMMENT '授权类型（AuthType枚举：SMS/APP；仅 TRANSFER_AUTH、TRANSFER_AUTH_CODE_RESEND 行写入，普通转账行与历史行为 NULL）'
    AFTER `capability`;
