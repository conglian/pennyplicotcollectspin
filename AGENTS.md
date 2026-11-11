# PennyPilot 项目工作约定

这是 Flutter 项目 `pennypilotcollectspin`。

## 按任务使用项目 Skill

- 实现或调整页面、弹窗、引导、布局和 UI 交互时，读取并使用 [.agents/skills/pennypilot-ui/SKILL.md](.agents/skills/pennypilot-ui/SKILL.md)。
- 下载、替换或导入 Figma 图片资源时，读取并使用 [.agents/skills/pennypilot-assets/SKILL.md](.agents/skills/pennypilot-assets/SKILL.md)。UI 任务涉及新图片时，同时使用资源 Skill。
- 单纯讨论方案、查询 Git 或修改业务逻辑时，无需强制加载这两个 Skill。

## 固定规范

- 默认设计来源和图片导出规范见 [README.md 的设计资源部分](README.md#设计资源)：使用指定 Figma，导出 3 倍 PNG，下载后自动无损压缩并校验。
- `lib/PCDialog/` 内每个具体弹窗使用独立的同名 Dart 文件；类前使用中文 `///` 注释说明对应界面、用途及主要按钮行为。
- 引导页面及共用组件放在 `lib/PCDialog/PCGuide/`，新用户引导控制器放在 `lib/PCTool/`。真正的前三步对应 Figma「引导页1、2、3」，后续按飞书 3.1 新用户流程执行；已搭建的页面和弹窗复用。2026-10-27 用户最新更新：首次和普通签到均先播放激励且按钮显示 AD 角标，真实激励成功才发奖、记签到，不再由 new_ad_console 控制。新用户激励失败先显示同路由广告失败面板，关闭后退出签到，跳过未到账的动画/佣金并保存到答题引导；失败不发奖、不记签到。普通签到失败同样提示且允许下次重新点击。
- UI 使用本地文字、渐变数字滚动、图片和按钮封装；弹窗显示使用 `pc_extension_help.dart` 中的 `context.tipShow(...)`（带毛玻璃）或 `context.tipShow2(...)`（不带毛玻璃），具体规则见 UI Skill。
- 所有弹窗共用 `PCDialogCoordinator` 串行展示，完整退场后才显示下一项；到账动画、答题横幅和站内通知也须持有并释放展示权，不能覆盖显示。3.7 答题横幅允许重复触发、同一时刻一条，从侧边平移进入并原路退出；流程触发及防重见 UI Skill 的 `references/process-prompts.md`。
- 2026-10-26 答题横幅仅按 `quiz_console` 真实答题次数达标触发；取消无操作若干秒自动弹出，展示结束不循环定时重弹。切页/后台取消已达门槛的旧提示，返回不补弹；答对仍等领奖及到账结束后1秒，答错仍等对错反馈结束后1秒，不能覆盖其他弹窗。
- 延续现有 `PC` 命名、资源引用和目录结构；复用项目组件，维护拆分后的导出与调用兼容。
- 普通答题按飞书 3.4 执行；2026-10-27 更新：普通答题 Claim 仅在真实激励成功后领奖；新用户三题引导仍免广告并去掉 AD 角标，关闭也不出插屏。2026-10-28移除答题页右上宝箱；H5仅从转盘宝箱进入本地PCWebkitview，title=Games，url=https://tinyurl.com/dfr3jy4u。普通答题进度与待领奖励放在 `PCQuizController`，与三题新用户引导分开记录；领取和恢复不得重复发奖。
- 新用户有效提交后立即将脱敏收款账号和渠道写入通用本地缓存，再推进引导，并同步 3.7 账号确认状态；答题时不得再要求已确认用户填写账号，兼容同次运行及旧存档冷启动。

- 数值统一由 `PCNumberHelpers` 读取 `assets/File/gp177_pig_number.json`，模型生成文件为 `PCNumbserModel.g.dart`。`pc_pig_level`：0 粉猪、1 钻石猪、2 金猪；现金达到 `eq_range` 首档升级钻石猪；2026-10-31更新：钻石未满20不启动倒计时、不因跨天升级，收满20时才持久化倒计时起点与当天下一个本地午夜截止时间，届时升级金猪；钻石仍可超过20；10 金砖后进入排队，再按 `tixian_task` 循环执行提现任务。2026-10-26 用户澄清：10仅是提现触发目标，后续首页气泡、答题和转盘仍继续获得金砖，超过10按 `gold_prize` 末档取奖，实际数量不封顶且不能重置排队/任务。数量保持两位小数，奖励按对应 JSON 区间取得，不能将钻石和金砖加到美元余额。

- 提现全流程由 `PCWithdrawalController/PCWithdrawalFlowHost` 管理，规则见 UI Skill 的 `references/withdrawal-flow.md`；钻石礼包按当前钻石数量从diamond_prize首次生成并持久化，展示与领取同一笔且只结算1次，Collect Now页不显示关闭按钮，队列广告成功才按配置独立减少总人数与当前排名，quiz/spin/video按真实动作防重计数。排队和最后一步任务每次冷启动主动恢复，同次关闭不循环弹出。
- 排队广告成功后保留排队弹窗，用户可关闭或等排名反馈结束后继续看广告；到第一名时自动退出并串行显示提现任务，提现页同样立即刷新为任务状态且反馈结束后主动拉起任务框。通知二次召回每次冷启动检查系统权限，未授权显示一次通知引导，已授权恢复原通知计划；副标题为“Keep your earnings safe—get notified when it’s time to cash out”，同次运行关闭后不重复提醒。
- 提现页浏览渠道用 `pc_cash_view_payment_index_v1` 独立缓存，不能覆盖实际填写账号的 `pc_account_seled_index`。审核/收集/排队/最后一步任务仅在账号非空且浏览渠道等于收款渠道时显示；其他渠道显示普通提现档位，按钮不能拉起已绑定渠道任务，切回原渠道恢复进度。

- 广告失败弹窗的 Try Again 和关闭按钮均只关闭，不立即播放或重新请求；下次由用户再次点击原入口尝试展示，缓存由后台独立持续维护。TopOn/CloudX统一检查SDK缓存及在途状态：有缓存不重复load，正常在途不重复请求，超时按下述规则自动重试；加载成功或新请求开始时取消旧重试计时器。
- 2026-10-30 广告取消本地A/B与eCPM比价。TopOn/CloudX按模型中的有效唯一ID独立并行预加载，不固定四条；同类型有多个可用缓存时按wdzqbsbt数值从大到小优先播放，只有一个已缓存位时立即播放，不等待另一家补量。优先缓存失效或检查异常须尝试同类型另一家；仅全部无可用缓存时返回无缓存失败。Loaded立即记录缓存，不再依赖TopOn价格明细查询。
- 2026-10-30 每个配置ID持续维护一份缓存：9秒加载超时后自动继续请求，失败后自动重试直到缓存；TopOn超时重新派发load，原生SDK合并仍在途的同ID请求，CloudX超时无缓存时先完成旧实例销毁再补量。缓存成功后每9秒独立核对是否失效，失效即补；正在播放且未关闭的ID不检查/加载/销毁，其他ID继续维护。真实关闭或播放失败后立即补量，不等待业务回调Future。配置增删保留匹配缓存及在播owner，被移除的在播ID等关闭后退役，其余移除ID立即取消维护。SDK首次初始化失败也按平台去重自动重试。用户最新确认：FB配置获取/初始化与广告管理器及聚合SDK初始化并行互不等待，不能用FB完成作为广告初始化门槛；广告管理器就位后即可独立初始化广告平台。Try Again/X不触发加载、播放或旧奖励恢复。计时器和旧异步请求按ID及token隔离，日志统一[ad-load]。
- 2026-10-30 TopOn原生show接口不返回MethodChannel result，展示命令只派发并观察异常，不能await其完成后才释放缓存检查锁。交给SDK时释放检查锁，仍由原生展示状态阻止并发；展示、收入、激励成功及关闭均只认真实SDK回调。检查锁和展示命令各带唯一token，旧finally或迟到命令异常不能清除下一笔广告的owner、回调或BGM持有权；CloudX命令同样捕获原生异步异常。
- 广告收益仅在本次广告真实显示成功的位置统一上报TBA、Adjust和FB；CloudX使用onAdDisplayed，TopOn使用插屏显示成功/激励开始播放。同次重复显示或RevenuePaid回调不重复报，预加载、显示失败、取消及跳过广告不记收益。CloudX的Adjust来源保持publisher_sdk。
- 调试开启PCPigAds.skipAd时，激励和插屏均直接回调成功，继续原有领奖/到账流程；跳过模式不调用原生展示，不计真实广告展示与收入。关闭跳过模式后仍只有SDK真实激励成功才领奖。
- FB Android桥接沿用`PCFacebookAnalytics`既有MethodChannel，先获取Firebase `c177pig_android_fb`（app_id/client_token/name）再初始化；获取失败、为空或字段不完整时整组使用用户提供的默认配置（见PCFacebookConfig），不能混搭凭据或继续使用旧固定AppID。其他数值配置异常不能覆盖已生效的远程FB配置。
- 通知统一由 `PCNoticeHelp` 管理：媒体4通道在29/59/119/159分钟各发送一次，固定4通道在26/62/117/162分钟各发送一次；绝对触发时间及已发送项持久化，余额刷新和冷启动不得重置或重复发送。前台服务1通道、同ID1200，原生每15分钟刷新，美元余额变化立即更新且不顺延周期；撤权停止。媒体、固定、亮屏及锁屏文案从用户提供的5组标题/正文成对随机，含金额文案读取缓存美元两位小数。FCM2独立通道分别订阅 `c177fcm_piggy` / `c177fcm_piggy_two`，使用后台文案；后台自定义样式发送data-only消息。具体渠道和恢复规则见 UI Skill 的 `references/notifications.md`。
- 2026-10-28最新：真正后台返回前台且无原生广告展示时，直接请求一次nkmdl_launch插屏，不在外层判断缓存；权限窗口、广告回切、通知导航及引导/弹窗占用仍跳过。未就绪/无缓存/检查在途由pc_showAd上报chance及失败原因，不定时补播、不重复请求。
- 冷启动插屏按启动时完整新用户流程状态判断，不能使用pc_install_status替代。未完成引导不播放，同次完成不补播；已完成用户在Launch进度结束后请求nkmdl_launch，等待真实关闭或静默失败再进入首页，失败不显示广告失败弹窗。
- 答题和转盘的奖励弹窗激励失败、取消、X、系统返回或外部关闭，均按捕获的rewardId持久化放弃该笔待奖；不发奖、不返还已消耗次数，答题进入下一题。成功领取同样校验rewardId，旧回调不能领取/删除新一笔。页面加载清理旧版本遗留待奖，取消Tab激活和冷启动自动补弹，反馈/转动过程中切离也放弃该次结果。
- 2026-10-27最新：所有模态弹窗和领奖到账效果使用非透明深色背景，默认pcDialogBackdrop=90%黑色，来自Figma64:274的65:463遮罩；覆盖之前首页/转盘透明背景约定。tipShow2仅由wrapper绘制一次遮罩，不能同时给RawDialogRoute再叠色；弹窗内容底板与图片透明留白保持分层。站内横幅、tips和Toast保持局部背景。 2026-10-31更新：到账动画主展示阶段保留暗底，开始向上收缩时立即移除全屏遮罩及黑色卡底；主体继续上飞，透明点击拦截与展示权仍保留到动画结束。

- 2026-10-27 首页奖励气泡先播放激励，成功后打开 PCAwardDialog；普通首页/答题/转盘奖励 Claim 再播放激励，成功才结算，失败不发奖且同路由切换失败面板；答题和转盘按最新规则清除待奖。关闭按 PCNumberHelpers.pc_checkProbability 决定插屏，false直接关闭；领取和关闭互斥、连点防重。placeID含int走插屏、含rv走激励，冷启动/回前台统一使用nkmdl_launch插屏；比价不能跨类型。远程Firebase gp177_pig_number有效时覆盖本地默认模型，缺失/失败/非法时回到打包JSON。

- 转盘每天按设备本地自然日额外赠送3次，首次进入、隔天冷启动、前台午夜和回前台均检查；同日不重复，保留未使用和答题赠送次数。PCWheelOpportunityStore统一串行处理每日加次、答题里程碑和转动扣次，账本为准、pc_wheel_number仅兼容镜像；日志恢复及待领奖励不能重复扣次或补回已消耗次数。

- 2026-10-27 新版首页为7个依次出现的气泡：Quiz、Wheel、Gold Apple、Daily Claim及3个阶段奖励气泡。免费奖励无AD，点击打开奖励框即置灰并开始本地持久化60秒冷却；另两个带AD，分别明文/???，先真实激励成功再开框。2026-10-28金苹果改为入口必出nkmdl_applebub_int插屏；2026-10-31更新：入口成功先结算首笔且不播放到账框，按新余额和阶段打开第二笔获得框；Claim带AD并播放asd_rv激励，成功后结算第二笔并播放到账动画，失败或关闭保留首笔，关闭按概率出nkmdl_applebub_getpop_int；其他首页阶段奖励框Claim无AD，仍按配置概率插屏后结算，插屏失败不阻碍已满足入口条件的奖励。普通答题/转盘及新用户策略不变。首页bonus tips仅冷启动进入首页、切回首页展示2秒，重建/余额变化不续期。新规范优先于此前“3个气泡均带AD且Claim再看激励”的约定。
- 2026-10-27最新：首页Daily Claim签到气泡不显示AD，签到弹窗内部的领奖按钮保留AD与真实激励规则。
- 首页7个气泡不能共用处理中状态禁用，只有免费气泡在60秒冷却时置灰不可点。签到、领奖各自防重复提交，不能阻止Quiz/Wheel等其他入口；关闭、失败或成功退出签到后同步释放自身请求状态。
- 首页两个相同且带AD角标的阶段奖励气泡（slot1/2）2026-10-31更新：入口rv成功立即按预生成rewardId结算第一笔并刷新气泡，不显示首笔到账动画，直接按更新后的余额/猪阶段重新取同slot奖励并显示获得弹窗。Claim不带AD，按配置概率插屏结束后结算第二笔并播放到账；关闭同样走概率插屏但不结算第二笔，第一笔保留。两笔分别防重并各自刷新三气泡。两个带AD气泡的入口激励placeID为nkmdl_moneybub_getpop_rv；入口失败不发奖。免费气泡规则不变；金苹果遵循2026-10-28插屏入口/激励Claim规则。切离首页即结束本次后续展示，快速返回也不补旧框。
- 审核验证页Speed Up Your Payout（223:409）的圆环和百分比用3秒从0分段变速到40%，不修改实际钻石及本地审核基线。首次验证和后续3.7同样式审核弹窗均取消自动关闭，只通过Continue/X手动退出，动画中也可退出；前一Advertiser Review Pending仍按原流程自动结束。 2026-10-31清单状态按真实展示共享记录：首次1个对号+2个转圈，后续2个对号+1个转圈；组件重建和排队取消不消耗次数。

- 2026-10-28打点统一通过PCAnalytics.event，底层pc_event_fire仅在PCAnalytics默认上报器中保留，pc_ad_fire继续独立处理广告展示。Adjust真实归因回调trackerName等于Organic记adjust_suc.adjust_user=0（A），其余记1（B）。钻石升级同一弹窗曝光分别记diamond_pig_getpop、collect_diamond_pop，确认按钮分别记diamond_pig_getpop_c、collect_diamond_pop_c；每个事件同次动作只记一次。priority_user_pop对应优质用户开箱页，priority_user_pop_c对应随后真实领取配置钻石奖励的Collect。答题右上宝箱已移除；转盘新版宝箱呼吸气泡点击记h5_c，打开本地PCWebkitview（title=Games，url=https://tinyurl.com/dfr3jy4u），页面真实首帧记h5_page。ad_limit_pop只保留组件打点，暂不新增业务触发。2026-10-28最新冷/热启动场景统一为nkmdl_launch，直接走正常插屏展示入口，不在外层检查缓存；提现video场景保留withdrawal_task_video。通知实际发送除FCM均记inform_p（含前台服务首次、余额和15分钟刷新），FCM曝光不记；inform_c继续按local/unlock/fcm区分。完整对应见docs/analytics/pc_analytics_audit.json。

- 2026-10-28 session冷热启动统一由PCSessionLifecycleController管理：冷启动一次，首次真实hidden/paused进入后台立即一次，返回resumed再一次；同次hidden+paused及重复resumed不重报，inactive权限窗口不报；广告回切仅看离开时已交给原生展示的广告，不能使用含缓存检查/加载/业务回调的isAdBusy过滤session，不能让返回时新开的回流插屏吞掉热启动上报。日志[session] trigger=cold_start/background_enter/foreground_return，随后走pc_session_fire标准协议（fritz=lemon），不额外发送同名自定义事件。

- Android启动时须在Adjust/FB远程配置的首次await之前绑定PCPigAds.bindServices()，只接通业务handler、不提前初始化原生聚合SDK，保证冷启动与激励在SDK未初始化时也由pc_showAd记录chance/uninitialized。初始化前后的绑定幂等；真实广告在播时不能抢占owner，缓存检查/业务回调在途的拒绝记录chance/notPrepared，不覆盖原请求。

- 2026-10-29通知权限：每次冷启动由PCNoticeHelp.initializeForStartup检查，未授权时主动向系统申请一次，已授权不再申请；通用initialize、回前台及余额刷新不自动重复申请。系统申请期间持有弹窗展示权，权限召回等待申请结束再判定。仍未授权时每次冷启动显示一次既有权限引导，PCNotificationPermissionSession在同次运行共享消费状态，宿主暖重建或关闭后回前台不重弹；新用户及提现等既有流程优先。用户之后在设置中开启权限，回前台重新检查并恢复前台服务、FCM及未过期通知计划，已发送通知不重发、不重置排期。

- 2026-10-30转盘h5_c仍打开PCWebkitview（Games、既有URL），Android通过useNativeH5Client启用本地penyplicotcollectspinsH5原生WebView并绑定WKSHuhs，真实加载开始/完成由该类打印完整URL并转发到Flutter控制台，统一前缀[H5]。网页关闭仅释放自身WebView，不调用清空宿主窗口的SDK clear；原SDK create仍只在主SDK初始化处调用，SDK clear仍只在宿主Activity正常卸载时调用。其他PCWebkitview入口默认沿用webview_flutter。

- 2026-10-31：移除绿色金猪payout通知样式及余额跨首档自动弹出逻辑。PCNoticeKind仅保留account/goal；固定117分钟、媒体119分钟和FCM1改用goal，原8项定时计划、11通道和两topic保留。旧原生缓存template:payout降级goal/Claim，FCM样式签名包含kind以刷新旧元数据；用户5组随机文案池保留。

- 2026-10-31整体字号适配：页面与弹窗使用`PCAdaptiveLayout`按局部可用宽高统一缩放容器、字号、图标和间距，固定画布倍率上限1.6；正文可滚动时按宽度放大，完整弹窗仍受可用高度约束，小屏主按钮保留至少44逻辑像素命中。底部导航倍率上限1.3。已用局部倍率或FittedBox缩放的文字不再叠加全局宽比或.sp，避免重复放大；长题、长账号、键盘及320/430/768宽度须核对。

- 2026-10-31界面约定：Claim共用轻呼吸且原点击框不变；站内通知在用户触碰页面时立即收起并释放展示权，不吞首次点击。主猪共用PCPigMotion.hero，已有Lottie保留；首页紫色底座粉猪美元/钻石数量加钻石icon/金猪数量加金砖icon，三奖励气泡基础字号18、冷却倒计时15，文字槽位同步增高。Show Pig上下统计均持续弹幕移动，紫色底座始终取该榜单用户的美元总收益。引导第一步App名称为PennyPilot。优质用户礼盒先抖动等3秒再开箱，按钮和礼盒全程点击直接继续，不自动跳转或发奖。提现答题任务统一Answer current/target Question Right，Cash任务描述及进度数为金色描边；具体设计文案见withdrawal-flow.md。

- 2026-10-31广告结果改为请求独立PCAdOutcome（success/cancelled/failed），仅真实failed显示广告失败；正常取消/忙碌拒绝不报播放失败、不发奖，保存异常显示保存提示。成功展示/奖励后的迟到命令错误不覆盖结果。开箱页倒计时结束仅从Click To Open(3s)去掉时间后缀，保留Click To Open。Official Notice账号采用黄色加粗，基础字号16→18，前缀和冒号保留原样。

- 2026-10-31最终UI澄清：Claim只做94%到106%的明显放大缩小循环，2.2秒一轮，无上下位移，点击框固定。PCAwardDialog的Only提示在粉猪/钻石猪/金猪三阶段统一使用Only $xx Left To Withdraw句式；xx为配置首档提现目标减当前美元余额，最低为0，金额动态而非固定4，不使用钻石或金砖数量。顶部My Cash余额和实际奖品数值继续动态，余额不足弹窗的动态差额规则不变。
