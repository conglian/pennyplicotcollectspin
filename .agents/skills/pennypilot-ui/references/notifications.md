# 通知规则（1.0.0 温和版，2026-11-16）

统一入口为 `lib/PCTool/PCNoticeHelp.dart`；Android 原生实现位于 `PCThrid/common_notifications-master`。本次只实现 1.0.0 温和版，不实现 1.0.1 的 2 秒通知刷新、2 分钟前台服务心跳、JobScheduler 兜底重启或 YouTube 拉活。

## 类型与频控

| 类型 | ID / Channel | 触发与行为 |
| --- | --- | --- |
| T1 权限引导 | 应用内弹窗 | 每次冷启动检查权限；已授权不弹；未授权且引导就绪时显示。只有用户点击 Enable Notifications 才请求系统权限；系统不再显示权限框时打开通知设置。Later 仅本次运行关闭，下次冷启动仍可展示。 |
| T2 本地定时 | 5590 / 177notice1；4562 / 177notice2；7552 / 177notice3；9475 / 177notice4 | 安装后分别按 30、39、59、79 分钟开始循环；每次从本地 4 条文案池顺序取下一条，文案金额取当前缓存。 |
| T3 场景通知 | 动态注册独立 ID | 退出后台立即一次；解锁、亮/熄屏、电源连接/断开、Home、系统日期/时区设置及应用包安装/移除/更新变化触发。场景通知全局间隔至少 12 秒。 |
| T4 FCM 数据消息 | topic `c177fcm_piggy` | 由客户端接收数据消息并按服务端字段展示自定义通知；服务端控制频次。 |
| T5 FCM 通知消息 | topic `c177fcm_piggy_two` | 由系统显示单行标题及折叠正文；服务端控制频次。 |
| T6 前台服务通知 | ID 1200 / pigwalletForeground | 常驻且不可滑除，启动时显示；美元金额变化时更新同一条通知；点击进入提现页。撤权时停止。温和版不增加定时心跳或 Job 重启。 |
| T7 媒体通知 | `pc_notice_media_v1`，21000–21019 | T2/T3/T4/T5 通知发布后另发一张静默媒体卡片，使用 80% 不透明度的黑色背景和白字，本地 4 条文案按序轮换。点击沿用对应的提现或赚取入口，曝光和点击单独记录 `type=media`。 |

场景通知任意两次派发间隔不少于 12 秒。本地、FCM 与场景通知共用 20 个展示槽，超过 20 条后循环覆盖最早槽位。计划注册本身不算展示。Android 通知权限或渠道关闭时，系统可能阻止通知显示，应用不得绕过系统限制。

## 通知打点

实际分发记 `inform_p`，点击记 `inform_c`，参数名为 `type`。按截图优先使用 `local`（本地定时）、`unlock`（解锁场景）、`fcm`（FCM）。其他功能的值使用 `background`、`media`、`foreground_service`、`screen_on`、`screen_off`、`power_connected`、`power_disconnected`、`system_*` 和 `package_*`。Home 键退出的曝光和点击统一使用 `background`，旧 payload 中的 `home_key` 也按 `background` 上报。曝光仅在系统实际分发通知后入本地队列；FCM 也按实际客户端展示入队。Flutter 恢复后统一提交并按事件ID确认，不能重复提交。

## 文案与样式

本地定时池和媒体池分别按序轮换。T4 使用服务端标题、正文及媒体字段，不以本地文案替换。T5 使用系统弱样式。T6 使用现有前台服务 RemoteViews，金额和点击目标动态更新。T7 使用本地猪猪插画和自定义收起、展开布局。

## FCM 与导航

`configureFcmTopics` 可分别替换 `fcm1` / `fcm2` 的 topic，替换时取消旧订阅；客户端不保存服务端密钥。后台 data-only 内容由本地原生服务渲染。通知点击先保存 action，等引导及首页可导航后再打开 Cash / Quiz；通知点击导航优先于回前台插屏。

Android 的 WorkManager、JobScheduler 和 AlarmManager 会受省电策略影响，不能承诺固定分钟数准时触发。温和版不增加更密集的轮询、后台拉活或保活重启。
