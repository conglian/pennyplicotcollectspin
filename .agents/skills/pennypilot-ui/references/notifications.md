# 通知规则（2026-10-27）

统一入口为 `lib/PCTool/PCNoticeHelp.dart`；Android原生在本地 `common_notifications-master` 插件。新用户未完成或未授权通知时不启用系统通知；权限只由用户点击申请。

| 类型 | ID | Channel | 首次启用后的时间 | payload |
| --- | --- | --- | --- | --- |
| 媒体1 | 4738 | 177notice0 | 29分钟，单次 | Media1 |
| 媒体2 | 2788 | 177notice21 | 59分钟，单次 | Media2 |
| 媒体3 | 2934 | 177notice31 | 119分钟，单次 | Media3 |
| 媒体4 | 1320 | 177notice41 | 159分钟，单次 | Media4 |
| 固定1 | 5590 | 177notice1 | 26分钟，单次 | noti1 |
| 固定2 | 4562 | 177notice2 | 62分钟，单次 | noti2 |
| 固定3 | 7552 | 177notice3 | 117分钟，单次 | noti3 |
| 固定4 | 9475 | 177notice4 | 162分钟，单次 | noti4 |
| 前台服务 | 1200 | pigwalletForeground | 启动立即、原生每15分钟、美元变化立即 | foreground |
| FCM1 | 后台提供/安全生成 | pc_fcm_withdraw_v1 | c177fcm_piggy后台推送 | fcm1 |
| FCM2 | 后台提供/安全生成 | pc_fcm_claim_v1 | c177fcm_piggy_two后台推送 | fcm2 |

亮屏为SCREEN_ON/ID1029，锁屏为SCREEN_OFF/ID2829，复用固定2/固定1通道；保留旧unlock点击兼容。重复事件节流30秒，每次真实事件重新成对抽文案，不设置自动重复计时。

## 本地文案

媒体、固定、亮屏、锁屏共用以下5组。媒体/固定排期时保存索引，余额刷新不重抽；亮屏/锁屏在实际广播触发时抽取。`{amount}` 为缓存美元金额，含$、两位小数。

| Title | Body |
| --- | --- |
| Piggy Almost Full! | You’ve saved {amount}—cash out before it spills! |
| Cash-Out Time 🎉 | Spin & play—your balance is ready to grab! |
| Your Payout Is Ready! 💰 | Piggy bank is full and ready to pop—open the app to collect your cash. |
| Advertiser Just Paid You! 🎁 | Tap to feed your piggy & claim today’s payout. |
| Balance Near Max 💵 | Almost full—withdraw before it’s gone! |

## 持久化与恢复

- `pc_notification_plan_v3` 保存锚点、issued、signatures、suspended及copyIndices。每项绝对时间=锚点+分钟，不使用periodicallyShow。
- 同日/隔天冷启动均复用原计划；已经发出的项不重排。权限撤回取消待发项并保留锚点，再授权只恢复仍未到期项，过期不补发。
- 使用inexactAllowWhileIdle，Android省电策略可能延后实际送达。
- 前台服务更新同ID；原生Handler计时，不依赖Dart前台Timer。重复启动只更新内容，不重置15分钟周期。停止、销毁及撤权移除回调，异步旧内容不能覆盖新余额或重建已停止的服务。
- 媒体每个channel使用独立MediaSession；两个FCM topic模板分别缓存，不能相互覆盖。
- 迁移移除旧服务17759及旧计划8852/1268/6722/1195，避免旧通知重复。

## FCM

默认topic已提供，不需要在客户端放FCM服务端密钥。`configureFcmTopics`可替换单个topic，空字符串禁用对应槽，替换先取消旧订阅；模板与订阅分别持久化。

自定义后台样式使用**data-only**消息。Firebase带notification字段的消息在后台由系统直接展示，会绕过本地service的样式与路由。参考[Firebase官方说明](https://firebase.google.com/docs/cloud-messaging/android/receive-messages)。HTTP v1消息示例：

```json
{
  "message": {
    "topic": "c177fcm_piggy",
    "data": {
      "title": "Your Payout Is Ready! 💰",
      "body": "Open the app to collect your cash.",
      "id": "6001",
      "amount": "100.00"
    },
    "android": { "priority": "high" }
  }
}
```

原生按`RemoteMessage.from`的topic路由，也接受data.topic/payload/channelId。title/body始终使用后台数据；空文案不展示，id缺失或非法时安全生成。FCM1点击去Cash，FCM2去Quiz，不使用本地随机文案替换后台内容。

## 前台与导航

App前台由既有PCInAppNotificationHost串行展示自定义横幅。通知点击先保留pendingAction，待引导和首页就绪再导航。PCForegroundAdController在消费通知导航前检查pending，防止同时出现回流广告。只有真实paused→resumed、没有广告/流程/路由占用且存在缓存时尝试一次插屏，无缓存不发起补请求、不设置重试计时。

- 2026-10-31：移除绿色金猪payout通知样式及余额跨首档自动弹出逻辑。PCNoticeKind仅保留account/goal；固定117分钟、媒体119分钟和FCM1改用goal，原8项定时计划、11通道和两topic保留。旧原生缓存template:payout降级goal/Claim，FCM样式签名包含kind以刷新旧元数据；用户5组随机文案池保留。

- 2026-10-31站内通知不阻断页面操作：用户在通知卡之外按下时，立即收起通知并在业务onTap之前释放展示权，第一次点击即可响应；通知正常展示仍与业务弹窗串行，关闭/上滑/8秒自动退场保留。通知卡自身操作不触发外部让位逻辑。
