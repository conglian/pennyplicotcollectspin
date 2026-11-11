# 新用户流程对照

来源：[飞书需求 3.1/3.8](https://stayfoolish.feishu.cn/docx/VAQTdIesDoGcC3xayN2cPyOrnNd)。设计使用项目固定 Figma `i4Xsv9T30MQY7ySoExu4Fi`。

| 文档步骤 | Figma | 复用或新增界面 |
| --- | --- | --- |
| 引导1–3 | 261:470 / 261:541 / 263:793 | PCGuide1Page / PCGuide2Page / PCGuide3Page |
| 引导4 榜首对白 | 37:409 / 42:135 | PCGuideDialog，两段对白，仅保留Try It Now继续；不显示View My Ranking额外入口 |
| 引导5 签到入口及弹窗 | 389:255 / 390:299 | PCGuide0Dialog / PCCheckInDialog |
| 引导7 到账动画 | 130:209 | PCGuide1Dialog |
| 引导8 首笔佣金 | 44:299 | PCGuide2Dialog |
| 引导9 固定三题及领奖 | 64:202 / 64:274 | PCGuideQuizDialog / PCAwardDialog |
| 引导10 提现资格 | 145:110 | PCCongsDialog |
| 引导11 收款信息 | 166:118 / 169:278 / 169:376 | PCWithdrawPage |
| 引导12 官方通知 | 172:487 | PCAccountFeedbackDialog |
| 引导13 成长奖励 | 178:106 | PCGuide3Dialog |
| 引导14 转盘入口 | 184:205 | PCWheelGuideDialog，然后切换 Wheel |

- 所有引导专属界面及共用布局放 `lib/PCDialog/PCGuide/`；既有收款页、奖励弹窗继续复用原路径。
- 控制器为 `lib/PCTool/PCNewUserGuideController.dart`，首页调度器为 `PCNewUserHomeFlow`。界面不硬编码弹窗互相跳转。
- 前三页兼容 `pc_intro_completed_steps_v1`，后续步骤、答题正确位图、待领奖金额和签到日期保存为 `pc_new_user_flow_v2`；全流程完成后才设置 `pc_new_guide_end`。旧完成安装直接迁移。
- 普通提示关闭或点击空白继续下一步；答题只允许点击答案，收款表单必须校验通过。签到新用户不显示关闭按钮。
- 正确选项手势等待 2 秒后显示，按钮从开始即可点击；每题只接受一次点击，锁定两个选项并显示对错状态 1 秒；答对后领奖、答错后继续下一题，期间改点另一选项不生效。之后只重试未答对的题。三题正确且三个奖励均领取完毕，才进入提现资格。
- 新用户三题的PCAwardDialog传adsEnabled:false、showAdBadge:false，领取及关闭均不请求广告；普通奖励仍按激励及概率插屏规则执行。
- 领奖写入恢复日志后更新余额及进度，处理重复点击和进程中断，禁止用页面展示次数判断发奖。
- **2026-10-27 用户最新更新：新用户首次签到和普通每日签到均播放真实激励广告（placeID暂用rv），底部显示AD角标，覆盖旧new_ad_console签到策略。** 成功后才通过原奖励日志到账，首次仍按签到、到账动画、首笔佣金、答题顺序执行。首次广告失败、取消、未就绪或异常均不发奖、不记签到，保存quiz续接点并在同一路由显示广告失败面板；Try Again与关闭均仅退出失败签到，然后继续答题引导，跳过到账及佣金说明。普通签到失败同样显示失败面板并退出，保留当日未签到状态，可再次点击入口。持久化异常保留签到并提示重试，不视为广告失败。
- 参数来源为 `PCNumberHelpers` 读取的本地 `gp177_pig_number`：首档门槛默认 100、首笔奖励默认 6、成长百分比取 `grow_point`、答题奖励使用 `money_prize` 区间；读取异常使用文档默认值。
- 收款信息页始终以两行展示 PayPal、Cash App、PiX、PagBank 四个渠道，不再按地区隐藏；美国默认 PayPal，巴西默认 PagBank。邮箱、10 位美国手机、11 位 CPF、无 @ 的姓名、+55 开头 12/13 位号码和 36 字符含连字符 EVP 分别校验。完整账号和 CPF 不存入引导进度。2026-10-26 用户更新：有效提交的脱敏账号须与通用账号缓存及 3.7 账号确认状态同步，完成引导后答题不再触发 3 题或 80% 的重复信息填写；旧存档也需自动识别，不能要求用户重填。
- 通知未开启显示 Reminder Me，并在用户点击后请求权限；已开启显示 Go Earn。拒绝权限不阻断引导。
- 转盘引导读取 `pcWheelNavigationTargetKey` 的真实位置，并复用 `PCNavBarItemView`；不得按 360×780 绝对坐标再画一套底部按钮。
- 引导2保留用户指定的 1900ms 左右分阶段平移；引导3保留三行无限滚动与 AD/美元动画。
