# 数值配置与本地阶段

2026-10-22 用户约定：`assets/File/gp177_pig_number.json` 为本地默认值，统一由 `PCNumberHelpers` 初始化并读取；Firebase同名gp177_pig_number远程对象按有效字段覆盖并缓存；缺失、请求失败或非法JSON恢复打包默认值，每次从默认模型合并，避免旧远程字段残留。`PCNumbserModel.dart` 使用 json_serializable，生成 `PCNumbserModel.g.dart`，不得手写生成文件。

| 字段 | 用途 |
| --- | --- |
| eq_range | Cash 提现档位；第一档为粉猪升级门槛，页面进度和剩余金额共用该门槛 |
| new_ad_console | 保留模型兼容；2026-10-27最新更新后首次与普通签到统一需真实激励成功，不再受该开关控制 |
| queue_number | 提现排队的初始人数及递减区间；不是首页每日收益排行榜 |
| tixian_task | 保留类型化任务数据供后续提现任务接入 |
| intad_point | 当前美元余额对应的插屏概率，左闭右开，point 为0–100百分数；PCAwardDialog关闭时调用pc_checkProbability，true插屏、false直接关闭，新用户三题免广告 |
| wheel_range | 转盘现金区块显示的数值范围 |
| first_ad_prize | 新用户首笔签到奖励 |
| money_prize | pc_pig_level=0 的美元奖励 |
| diamond_prize | pc_pig_level=1 的钻石奖励 |
| gold_prize | pc_pig_level=2 的金砖奖励 |

- 用户确认补上本地 money_prize 缺失的 90–95 区间，奖励为 [1,2]。
- 2026-10-27新增：转盘每个本地自然日赠送3次机会，首次进入也赠送；当天切页、重建和冷启动不重复赠送，隔天在已有剩余次数上加3，不清空答题获得的额外次数。离线多日仅领取本次打开当天的3次，不补发未打开日期。此规则写死，不使用`wheel_range`。
- `PCWheelOpportunityStore`统一串行每日赠送、答题加次和转盘扣次，单JSON账本`pc_wheel_opportunities_v1`保存余额、赠送日期及答题/转动防重标识，`pc_wheel_number`为兼容镜像。先提交账本再写镜像，中断后修复镜像；旧`spinTarget`及扣次日志先迁移，不能覆盖新增机会或补回已用次数。转盘页初始化、本地午夜、回前台及激活时刷新，待奖跨天保留同一落点和金额、不再扣次。
- PCPigProgress 统一镜像 pc_pig_level、pc_pig_level_index、钻石/金砖双精度数量及旧整数数量。达到第一提现档位升级钻石猪；2026-10-31更新：20为钻石倒计时启动门槛，未满20跨天不升级，达到20才启动到当天下个本地午夜的倒计时并于到期升金猪；允许超额并按最后diamond_prize区间继续发奖；10金砖进入queue_number排队、再执行tixian_task循环；10只是触发目标，之后金砖继续按gold_prize末档累计，实际数量不封顶且提现进度不重置。20 和 10目标写死，不从 JSON 改动。升级后不因余额减少降级。
- 答题与三题引导的待领奖励保存原阶段和原金额，冷启动不重新随机；粉猪展示美元、钻石猪展示钻石、金猪展示金砖，只有美元奖励计入余额。
- PCRewardedAdService只接受真实激励结果，未接通SDK、加载失败、关闭未激励或SDK异常均返回失败。首次与普通签到统一使用rv并显示AD角标，成功才记签到及到账。首次失败保存quiz、跳过到账和佣金说明，失败面板与签到同路由，用户关闭后才继续引导；普通失败退出后仍可再签到。持久化失败不当广告失败吞掉。
