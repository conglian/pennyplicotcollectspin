---
name: pennypilot-ui
description: "实现和调整 PennyPilot（pennypilotcollectspin）Flutter 项目的页面、弹窗、新手引导、布局和 UI 交互，按项目 Figma 对照开发。适用于本项目 UI 编码和重构；仅下载图片时使用 pennypilot-assets，纯业务逻辑或 Git 操作不触发。"
---

# PennyPilot UI 开发

## 设计来源与任务定位

- 默认 Figma 为 [177](https://www.figma.com/design/i4Xsv9T30MQY7ySoExu4Fi/177?node-id=0-1)，file key 为 `i4Xsv9T30MQY7ySoExu4Fi`。先定位任务对应节点；`0:1` 是页面入口，不把整页当成单张 UI 素材。
- 先检查目标页面、调用入口和现有组件，再读取需要的 Figma 节点；用户本次给出的节点或明确要求优先。
- 从 Figma 实现代码时，使用当前环境已有的 `figma-design-to-code` 指导；调用 `get_design_context` 前先读取该技能。仅在确需文件内 JavaScript 检查时使用 `use_figma`，并先读取 `figma-use`。
- 若需要下载或更新图片，使用同级 [pennypilot-assets](../pennypilot-assets/SKILL.md)，完成 3× 导出、无损压缩和校验后再引用。

## 项目中的实现方式

- 页面位于 `lib/PCMainVC/`，弹窗位于 `lib/PCDialog/`，通用组件和扩展位于 `lib/PCTool/`。沿用目标模块的 `PC` 类名和同名 Dart 文件风格。
- 引导页面和共用组件统一放在 `lib/PCDialog/PCGuide/`，引导控制器位于 `lib/PCTool/PCNewUserGuideController.dart`。前三步是 Figma「引导页1」`261:470`、「引导页2」`261:541`、「引导页3」`263:793`，对应 `PCGuide1Page`、`PCGuide2Page`、`PCGuide3Page`；旧 `PCGuide*Dialog` 是后续首页遮罩流程，不能按其文件编号当作前三步。前三页和后续业务引导均记录本地进度、冷启动恢复。后续顺序按 [新用户流程对照](references/new-user-flow.md) 执行，复用已完成页面。
- 搭建 UI 时使用项目本地封装：普通文字使用 `PCText`，描边文字使用 `PCStrokeText`，渐变文字使用 `PCGradientText`，需要渐变数字滚动效果时使用 `PCGradientNumberRoller`；图片使用 `PCImg`，装饰背景图使用 `PCDImg`；对应点击效果使用 `ParticleButton`，并复用现有颜色、资源路径等扩展。
- 这些封装位于 `lib/PCTool/pc_text.dart`、`pc_stroke_text.dart`、`pc_GradientText.dart`、`pc_GradientNumber.dart`、`pc_img.dart` 和 `pc_extension_help.dart`。先核对组件参数及字体等默认值；现有能力无法表达设计时，优先作最小扩展，特殊富文本等场景再局部使用底层组件。
- `PCGradientNumberRoller` 的 `value` 为目标数字，`currentValue` 为初始动画数值，`duration` 单位为毫秒，`decimalPlaces` 控制小数位；字重使用 `fontWeight`，渐变和描边通过 `gradientColors`、`borderColor`、`borderWidth` 设置，`borderWidth: 0` 关闭描边。`showDolas` 默认为 `true`，添加美元符号；纯数字显示时设为 `false`。
- 2026-10-27 用户最新更新：首次和普通每日签到均先播放激励，底部按钮显示 AD 角标，真实激励成功才通过原日志发奖、记签到；不再由 new_ad_console 控制。激励失败在签到原路由显示 PCAdLoadingFailedDialog，用户关闭后退出签到；新用户保存到答题引导，跳过未发生的到账动画和佣金说明，不发奖、不记签到，不能卡住。普通签到失败保留可领取状态。存储异常仍保留原签到提示重试，不能当作广告失败跳过。新用户三题答题奖励同样免广告：PCAwardDialog传adsEnabled:false、showAdBadge:false，Claim直接领取，关闭不播放插屏。普通首页/答题/转盘奖励按下述广告规则处理。
- 页面数值统一经 `PCNumberHelpers` 获取，配置与阶段约定见 [数值配置对照](references/number-config.md)；不得再读取旧 `gp152_pig_number`。
- 首页、答题、转盘的钻石/金猪顶部统一复用 `PCBalanceHeader`（设计 `198:445` / `203:819`）；粉猪保留首页余额样式，转盘粉猪顶部与答题页相同。粉猪美元进度读取 `pc_dollar_number` 和配置首档门槛；钻石、金砖的进度数字及填充比例必须分别为本地已收集量/20、已收集量/10，不能显示美元100。Collected 读取 `PCPigProgress.sync` 镜像后的精确 `pc_pig_level_index`，Left 为阶段目标减去已收集量且最低为0；钻石超过20仍显示真实数量，填充最高100%，不能使用转盘次数或已取整的旧数量。右侧收款角标继续显示首档美元目标。答题到账动画锚点指向当前阶段数字；顶部文字、数字、进度和背景独立搭建。
- 2026-10-26 阶段顶部栏按页面真实宽高约束适配，背板铺满，猪、游标和文字使用同一等比尺寸，轨道利用横向剩余空间。零进度及满档时，游标必须留在轨道内，与主猪、支付角标各保留8设计像素间距；不能非等比拉伸328×112画布，或让两只猪重叠。首页、答题、转盘及本地0/0.01/满档均需检查。
- 转盘每日按本地日期加3次免费机会，保留剩余及答题额外次数，同日切页/冷启动不重复送；常驻页午夜、回前台及激活时刷新。机会统一由PCWheelOpportunityStore串行落盘，每日/答题加次及扣次不能互相覆盖，日志重放不补回已消耗次数。转盘由 `PCWheelController` 保存机会和待领奖励。粉猪仅落金额分区，按当前美元余额从 `money_prize` 取奖；钻石/金猪仅落 Cash Bag，按精确的已收集钻石/金砖数量从 `diamond_prize` / `gold_prize` 取奖，不能拿美元100匹配资源奖励。金额区标签读取 `wheel_range`，文字和独立图案、底图分层绘制。一次转动先保存落点、金额并扣一次机会；动画结束弹 `PCAwardDialog`，Claim仅在真实激励成功后入账当前奖励类型并播放本地到账动画。广告失败或关闭奖励框均按ID丢弃当前待奖，不发奖、不退机会；进入页面时清理旧版本遗留待奖，Tab激活不再自动恢复弹奖。扣次数及领取日志支持中断恢复，连点不重复发奖，答题常驻页读取最新收集缓存。机会不足显示 `PCWheelNoChanceDialog`（设计 `207:482`），Get By Quiz关闭并切答题，关闭按钮仅关闭；集满10金砖后进入Cash排队/任务，答题和转盘仍可继续计次；2026-10-26 用户澄清：金砖10仅触发提现排队，之后仍可获得金砖，按gold_prize末档继续发奖且数量不封顶；待领奖励与提现任务分别防重，不重置排队/任务。
- 2026-10-27用户最新要求覆盖此前透明规则：所有模态弹窗及首页/答题/转盘到账动画均有深色背景。Figma领奖`64:274`遮罩`65:463`为rgba(0,0,0,0.9)，统一`pcDialogBackdrop=Color(0xE6000000)`；奖励框自身底板仍独立绘制。`tipShow2`的RawDialogRoute保持透明，仅wrapper绘制一层遮罩，不能双叠。站内通知、tips及Toast是局部轻提示，保留自己的卡片底色。 2026-10-31更新：PCQuizRewardAnimation在收缩上飞开始（总时长65%）立即移除全屏暗色遮罩和黑卡底，保留主体动画、透明点击拦截及展示锁直至结束；首页/答题/转盘共用这一时序。
- 共用领奖弹窗 `PCAwardDialog` 的默认激励Claim右上角显示本地 `pc_ad_icon`。普通答题、转盘保持该策略；2026-10-27新版首页阶段气泡为概率插屏Claim且隐藏AD，2026-10-28金苹果Claim改回激励并显示AD；新用户三题引导关闭广告并隐藏角标。
- 2026-10-26 领奖弹窗说明文案按 Figma `64:274` 的三行原文、16px 中等字重和统一左对齐呈现，对勾与文字起点固定。2026-10-31最新：三阶段获得框统一使用`Only $xx Left To Withdraw`句式，xx按配置首档提现目标减当前美元余额动态计算，最低为0；不再显示钻石/金砖剩余量或兑换说明，顶部现金及实际奖励仍动态。中间100×100逻辑槽位使用 `pc_award_diamond` / `pc_award_gold` 的300×300透明PNG，与旋转光圈分层；不能放大48px顶部小图标充当主图，现金图保持200×92比例。
- 首页三个奖励气泡保留原位置，粉猪用原纸钞气泡，底部一个显示 `$???`，另外两个显示配置金额；钻石/金猪分别使用 `613:289` / `613:283`，同一位置一个显示 `×???`，另外两个显示 `×数量`。`PCHomeRewardController` 按当前阶段数量从 `money_prize` / `diamond_prize` / `gold_prize` 预生成并缓存三个奖励，实际领取使用预生成的金额，未知气泡仅隐藏数量，不能到点击时另抽一笔。领取成功后按新余额、阶段和配置刷新全部三个值；普通重建、关闭领奖和同状态冷启动保留金额。三种奖励分别入账美元/钻石/金砖，带领取日志和代数防重；其他入口改变余额或配置时刷新，达到阶段门槛同步换图和奖励类型。原Quiz、签到、Wheel三个入口继续保留。
- 新版首页三个阶段奖励气泡中免费槽位0不显示AD，槽位1/2显示本地 `pc_ad_icon`，随气泡等比缩放；Gold Apple显示AD，Quiz/Wheel不显示。用户最新更新：Daily Claim签到气泡去掉外部AD，内部领奖按钮保留AD与激励规则。角标绘制在最上层并忽略点击，免费灰显和倒计时仅影响免费槽位。
- 首页7个气泡的enabled只受免费槽位60秒冷却影响，不能使用_openingCheckIn、_openingReward、动画或控制器处理中状态把整组禁用。签到/领奖内部防重复提交分别保留，Quiz/Wheel等入口不能被其他入口的请求锁拦截；签到关闭、失败或成功后同步释放自身状态。
- 普通答题按 [3.4 答题流程对照](references/quiz-flow.md) 实现，由 `PCQuizController` 保存进度与待领奖励。2026-10-27普通答题 Claim 需要真实激励成功后领取；新用户三题引导免广告且去角标。2026-10-28答题右上宝箱已移除；H5仅从转盘呼吸宝箱进入本地PCWebkitview，title=Games、url=https://tinyurl.com/dfr3jy4u，点击h5_c、页面真实首帧h5_page各一次。2026-10-22 用户最新约定：题目立即可答，正确答案手势独立等待 2 秒后显示，不参与按钮锁定；每题只接受第一次点击，正确/错误状态统一展示 1 秒，正确后弹奖励、错误后换题，期间两个选项都锁定。答错后改点正确不能领奖，答对后再点旧答案也不能重复弹奖；关闭或广告失败后清除该笔待奖并恢复下一题，不再显示Claim Reward恢复入口。控制器校验提交题号，拒绝旧题请求。切换 Tab、前后台恢复、升级关闭后立即重建可点击状态，禁用的 `ParticleButton` 不播放点击特效。现金、钻石、金砖分阶段累计；钻石20和金砖10仅是流程目标，资源可继续超额累计，不能把钻石、金砖直接计入美元余额。
- 3.7 按 [流程性弹窗对照](references/process-prompts.md) 实现：`PCProcessFlowController/Host` 记录账号、答题排行、审核和钻石提醒；所有本地弹窗经 `PCDialogCoordinator` 串行显示，到账动画、横幅及站内通知同样互斥。2026-10-26 用户更新：新用户已有效提交账号时，同步脱敏账号缓存并完成两个账号提示触发点，答题 3 题及超过 80% 后不再重复填写；兼容旧引导存档，同一次运行及冷启动均识别。答题横幅仅按 `quiz_console` 真实答题次数触发，删除无操作自动弹出，切页/后台取消旧提示且返回不补弹；允许多轮触发、同一时刻一条，从右侧进入并原路退出，不能沿用每次领奖随机横幅规则。
- 首页排行榜统一读取 `PCUserDataManager` 的本地每日榜单，人数固定 56；本地零点、跨天回前台和隔天冷启动均按日期检查，同日不重复生成。前三名及列表头像取 `PCUserData.avatarName`，使用 Figma 专用头像，不能按名次固定三张头像或截断后面的用户。
- 飞书3.2老用户流程：完成新用户引导后，隔天冷启动或回前台显示 `PCGrowBonusDialog`（Figma `gba 178:106`），Go Earn关闭后切Quiz，关闭按钮仅收起。通过 `PCReturningUserController` 按设备本地自然日持久化，一天只展示一次，兼容旧 `pc_day_date`；未展示记录可冷启动恢复。启动时必须先读取历史日期再更新今日日期，新用户当日及未完成引导不弹出。共用 `PCGrowBonusContent` 复用新用户Grow Bonus外观，老用户固定Go Earn；金额读取当前缓存，成长比例读取 `PCNumberHelpers` 的 `grow_point`，展示本身不自动发奖。弹窗经 `tipShow2` 显示，等待现有弹窗并暂缓升级提示，避免重叠。
- 前三名头像、数字台座和列表 Show Pig 打开同一 `PCPigShowDialog`，传入被点用户。`totalEarning > 100` 为金猪，100 整及以下为粉猪；收益、广告次数读取该用户。上方 `PCPigBarrage` 每次打开随机生成三行头像和文案，分别匀速向左无缝滚动；关闭后释放动画，减少动画设置下静止展示。使用 `tipShow2` 的深色遮罩显示；Go Earn 关闭展示后切换 Quiz 答题页，顶部关闭按钮仅关闭。
- 收款信息页 `PCWithdrawPage` 同时展示 PayPal、Cash App、PiX、PagBank 四个渠道，按两行排列；地区仅控制默认选中项，不隐藏渠道。切换时使用各渠道独立表单和原有校验。
- 答题引导 `PCGuideQuizDialog` 读取 `pcQuizContentTargetKey` 的真实位置，与普通答题页共用 `PCQuizContentPanel`；不要另按 360×700 画布重画题板。通过 `tipShow2(..., scaleContent: false)` 展示，避免入场缩放造成背景和高亮重叠；说明卡按题板上方的剩余空间适配。答题页的垂直布局按实际 body 可用高度收紧，不能直接使用分屏模式下会设置最小屏高的 `.h` 撑出底部导航。
- `PCImg(name: 'pc_example')` 对应 `assets/images/pc_example.png`，沿用此引用方式。
- 2026-10-30 设置入口来自首页`1:5`的`795:598`：齿轮32×32，命中至少44×44，位于余额卡上方，不能覆盖Withdraw。`PCSettingsDialog`按`786:262`的360×389独立面板居中，音效和BGM图标分别显示真实开关；Privacy Policy与新增Terms of Use通过`PCSettingsLinks`打开本地`PCWebkitview`，Contact Us暂未配置。音频统一用`PCAudioUtils`，资源为`File/bgm.mp3`、`File/quiz_option.mp3`、`File/reward_collect.mp3`；背景及音效默认开启，分别缓存`pc_bg_music`/`pc_sound_music`，启动先读缓存再循环BGM，关闭立即停播，退后台暂停；真实广告SDK show前须先持有BGM恢复禁令并await严格暂停，关闭、失败或抛错统一释放，缓存检查/跳过广告不暂停；回前台或广告结束仅在音乐开关开启且无广告持有时恢复。普通及引导答题每题第一次有效点击不分对错播放选项音效；2026-10-30最新纠正：领取前`PCAwardDialog`获得框不播放加钱音效；实际到账的`PCQuizRewardAnimation`首次出现时，现金/钻石/金砖均播放一次奖励音效；新用户签到到账`PCGuide1Dialog`同样播放一次，重建不重播，不在余额刷新时播放。
- 领奖弹窗的本地动画记录见 [local-reward-animations.json](references/local-reward-animations.json)：`PCQuizRewardAnimation` 已按奖励阶段接入 `home_pig_fen.zip` / `home_domand.json.zip` / `home_huangjin.zip` 的 1 秒小猪扫光，504×420 对应 168×140 槽位。保留独立的绿色底板、标题、动态金额及收缩到账动画，总时长 1.8 秒；加载中或加载失败回退原静态猪图，系统减少动画时使用静态图并缩短为 0.3 秒。飞美元可复用 `guide_1.zip` 的钞票层，钻石/金砖飞出层可取自 `wallter_open.zip`，这两组粒子尚未接入该领奖效果。
- 提现完整生命周期遵循 [提现流程与六态页面](references/withdrawal-flow.md)。首档美元门槛达到后经 `PCWithdrawalFlowHost` 串行展示钻石升级、审核0→40%、验证40%、通道激活、优质用户自动开箱、领取配置钻石奖励。2026-10-31更新：礼包后未满20继续收集，不显示或启动倒计时；达到20才启动到当天下个本地午夜的倒计时并主动显示，冷启动同样检查。旧未达标存档不能沿用入钻deadline跨天升级，旧已满20无新起点标记时从本次检查启动倒计时；到期沿用金猪升级流程，已有金猪不降级。钻石仍可超额累计。10金砖进入配置排队，第一名后按配置循环任务。具体弹窗均独立文件，使用 `tipShow2` 等待引导/反馈/奖励及动画退出，禁止覆盖；旧 `PCPigUpgradeController` 继续提供动画展示锁和兼容已确认缓存。
- 2026-10-27审核验证页223:409进度视觉用3秒从0分段变速到40%，带短暂停顿，圆环和数字同步；不改变真实钻石数量及本地审核40%基线。首次验证与后续3.7同样式审核弹窗均只由Continue/X关闭，取消定时自动退出，动画途中可立即退出，dispose释放动画。减少动画直接到目标但不自动关；前一Advertiser Review Pending页面的自动流程保持原规则。 2026-10-31清单首次为对号/转圈/转圈，后续为对号/对号/转圈，共享实际展示记录，详见流程性弹窗对照。
- 2026-10-26 金猪升级标题的对勾、弧形文案和丝带按用户要求整体使用 Figma `231:456` 的 `pc_gold_upgrade_header` 3×透明图，保留语义标题，不再叠emoji和手绘文字。上部资料内容在短屏可滚动，底部主按钮64高、Maybe Later实际命中44高，均在安全区内；大屏内容与底部按自然总高居中，不能留下过大间距。金额、账号、日期、金砖进度仍由代码绘制。
- 引导1的小猪使用 `PCGuidePig` 播放本地 `assets/File/guide_1.zip` Lottie，仅保留小猪和钞票区域，避免动画包自带的箭头、文字和人物与页面独立组件重复；不要叠加原来的小猪摇摆动画。
- 引导3底部 AD、美元、金币底座及收益文案使用本地 `assets/File/guide_3.zip` Lottie，由 `PCGuide3Artwork` 等比显示；上方三行品牌继续使用 `PCGuideBrandMarquee`，不要重复叠加旧底部图片或摇摆动效。
- 首笔签到到账弹窗 `PCGuide1Dialog` 使用 `PCGuideDepositCash` 单独播放本地 `assets/File/guide_1.zip` 的飞钞票层，从广告图标左上方沿左侧弧线飞入存钱罐；底部用 `pc_bottom_money` 显示完整现金堆，不叠加光圈，保留两秒自动关闭。`guide_2.zip` 是蓝色提现说明卡片，不用于到账奖励背景；金额继续由 `depositAmount` 传入。
- 启动页等其他小猪的呼吸、摇摆、蓄力起跳和落地回弹复用 `lib/PCTool/PCPigMotion.dart`，通过 `child` 接收本地图片或光晕组件；`jumpHeight` 控制跳高，`showShadow` 控制固定脚底阴影。保留系统减少动画设置的静止展示。
- 应用的 `ScreenUtilInit` 设计尺寸为 `375 × 812`；部分弹窗有自己的 `360` 宽设计坐标。沿用目标组件已有的缩放方式，检查小屏、安全区域和长文本。图片的 3× 像素倍率不改变 Flutter 布局逻辑尺寸。
- 对齐设计中的布局、字体、描边、图标、阴影和按钮状态；保留用户未要求修改的回调、导航、金额处理和权限逻辑。

## 奖励广告规则（2026-10-27）

- 2026-10-31广告结果统一使用每次请求独立的`PCAdOutcome`（success/cancelled/failed）。业务仅在failed时显示广告失败面板；正常关闭未获激励、重复入口忙碌、提现任务不适用或阶段变化不显示该面板，也不能发奖或推进。SDK真实展示/激励成功后，迟到show命令异常不能覆盖成功；收入仍只在真实展示处上报。成功广告后的本地保存/同步异常使用保存提示，不伪装为广告失败。旧bool接口仅为兼容，生产领奖/签到/提现使用typed结果。

- 2026-10-31界面更新：所有可领取的Claim按钮共用`ParticleButton.breathing`，仅在94%到106%之间纯缩放，2.2秒一轮，没有上下位移，不缩放点击框；禁用、隐藏页及减少动画时保持静态，不能改变广告、领取防重或到账时机。PCAward获得框三种猪阶段均使用固定句式`Only $xx Left To Withdraw`，xx为配置首档提现目标减当前美元余额，最低为0，不能固定金额或改用钻石/金砖数量；顶部My Cash继续读取真实美元缓存，奖品数值仍按配置。提示整句20px Bold、32px行高，美元差额为纵向金色渐变，整句共用基线。此规则只适用于获得框，不改变余额不足弹窗的动态差额。
- 首页紫色主猪底座按缓存阶段显示：粉猪为美元，钻石为数量及钻石图标，金猪为数量及金砖图标。三同款阶段奖励气泡字幕基础字号为18，冷却倒计时15（各比上版增加2设计像素），文字槽位同步增高，避免FittedBox按高度缩回；冷却及奖励来源不变。静态主猪统一使用`PCPigMotion.hero`复用金猪升级页动效，已有Guide/Launch及到账Lottie不叠加重复动画；微小进度图标保持原布局。
- 排行榜Show Pig页底部收益来源、广告次数、总收益均像顶部弹幕持续左移，三项数据同次打开保持稳定；收益来源仍随机二选一并匹配quiz/wheel图标。猪下复用紫色金额底座，粉猪及金猪都显示被选榜单用户生成的美元`totalEarning`，不读取本人钻石/金砖余额。
- 引导1的App名称固定显示`PennyPilot`；首页Try It Now引导不再显示View My Ranking黄色文字。

- 2026-10-27新版首页（Figma earn `1:5`）：共7个气泡，Quiz/Wheel/签到沿用原事件，Gold Apple遵循2026-10-28确认规则：入口必出nkmdl_applebub_int插屏；2026-10-31金苹果同样入口成功先结算第一笔、不播放首笔到账动画，再按更新后的余额/阶段打开第二笔获得框；Claim带右上角AD并播放asd_rv激励，成功结算第二笔并播放到账动画，失败或关闭保留首笔；关闭按概率播放nkmdl_applebub_getpop_int。3个阶段奖励气泡中第0个免费无AD，点击打开框时置灰并开始持久化60秒冷却；第1个AD显示???，第2个AD显示明文。用户最新更新：2026-10-31更新：这两个相同AD气泡入口nkmdl_moneybub_getpop_rv激励成功先按预生成rewardId结算第一笔并刷新三个值，不显示首笔PCQuizRewardAnimation，直接按更新后的余额、配置与猪阶段取同slot第二笔并显示PCAwardDialog；入账持有的展示权须在获得框入队前释放，不能阻塞自己的弹窗。两笔分别按ID防重；Claim无AD，按pc_checkProbability插屏结束后结算第二笔并播放到账；关闭仍走概率插屏，只保留第一笔、不结算第二笔。入口失败不发奖、不重抽。免费气泡仍按原流程。首页阶段奖励框传 `PCAwardClaimAdPolicy.probabilityInterstitial`；Gold Apple传rewarded并showAdBadge:true，不能把金苹果Claim改成概率插屏。阶段气泡Claim插屏失败不扣留已满足条件的奖励。普通答题/转盘继续默认Claim激励，新用户免广告策略不变。
- 首页到账动画通过Future等到其移除帧完成后再继续后续弹窗；整段奖励流程持续持有升级锁，动画持有并释放PCDialogCoordinator展示权，禁止到账动画与获得框叠加。切离首页即终止这次后续展示，已到账第一笔保留；即使同帧切回也不补第二框。dispose必须完成等待并释放展示锁。
- 首页按360逻辑宽等比布局，短屏整体收紧并给排行榜保留滚动空间；七个气泡继续320ms间隔依次出现和呼吸，放在最上层，不能被公告/排行覆盖。顶部粉猪蓝色余额卡与设计一致，钻石/金猪继续共用PCBalanceHeader。独立PCHomeBonusTipController监听首页Tab状态，冷启动初入和从其他Tab切回时展示2秒，切离取消；普通重建或余额刷新不重播。tips背板/尾巴独立3×素材，文字原生绘制。
- 普通答题和转盘的PCAwardDialog同样由Claim播放激励；关闭调用PCNumberHelpers.pc_checkProbability，true请求插屏，false直接关闭，不结算且清除同一笔待奖。关闭/领奖各自全程防重，原生广告结束前保留弹窗展示权。新用户三题的adsEnabled:false同时跳过领取激励和关闭插屏。
- 已定义广告场景使用表格及最新确认的placeID：两个AD气泡入口nkmdl_moneybub_getpop_rv、金苹果入口nkmdl_applebub_int/Claim asd_rv/关闭nkmdl_applebub_getpop_int；其他claimAdPlacement/closeAdPlacement沿用各场景配置。pc_showAd按placeID含int/rv选择类型，冷/热启动统一nkmdl_launch插屏；比价只比较同类型，不能把插屏当作激励成功。用户2026-10-27更新：开启PCPigAds.skipAd的调试跳过模式时，激励/插屏均模拟成功并继续正常领奖；不调用原生展示、不计广告展示和收入，关闭跳过模式后仍按SDK真实结果发奖。
- 冷启动插屏通过PCLaunchAdController在启动时快照完整guide进度，未完成引导跳过且同次完成不补播；不能以安装过与否判断。已完成用户等Launch结束请求nkmdl_launch，完整等待关闭/静默失败后才构建首页；期间持有PCDialogCoordinator，失败不弹业务失败面板。
- 答题和转盘统一传PCAwardDialog.onAbandon：激励失败、X、系统返回、失败面板退出，均在路由退出/关闭插屏前await按rewardId持久化放弃；页面finally和dispose兜底清理。Quiz调用discardPendingReward，Wheel调用discardPending；Claim均传expectedRewardId防旧回调误领新奖。两页_load清旧待奖，取消Tab激活自动弹奖；反馈/转动期间切离后即使快速返回也放弃本次结果。正确题号/次数、每日及答题赠转盘机会保留，不发奖、不退已转次数。首页及新用户未传onAbandon，保持各自策略。
- pc_checkProbability使用当前现金余额匹配intad_point；Firebase gp177_pig_number有效对象按字段覆盖打包模型，远程缺失/失败/非法时恢复本地默认，非法概率字段单独回退本地。

## 通知界面

- 通知二次召回：`PCNotificationPermissionHost` 每次冷启动及回前台查询系统通知权限；未授权每次冷启动显示一次 `PCPushNotificationDialog`，等待新用户和提现等已有流程，关闭后同次运行不重复提示。副标题固定为 `Keep your earnings safe—get notified when it’s time to cash out`，完整分行显示。Go And Open由用户点击才打开系统通知设置；授权返回关闭自己的引导并恢复通知服务/计划，已授权启动不再显示权限引导。
- 用户最新约定：Figma固定通知 `250:1192` 上方两张为同一条Android前台服务的展开/收起态（`250:1217` / `250:1269`）。`PCNoticeHelp` 在首页引导完成、通知已授权且App前台时启动单一ID1200、通道pigwalletForeground，美元余额变化立即更新；原生服务每15分钟刷新同一通知，余额更新不顺延周期，后台保留已启动服务，撤权/停服取消周期。金额由本地现金余额动态绘制为金色渐变描边，保留头像、水印、蓝色Withdraw及Cash导航。Android12+收起内容按48dp适配；头像为`250:1430`原生3×透明PNG，见资源Skill的[记录](../pennypilot-assets/references/foreground-notification-assets.json)。
- 2026-10-27 通知共媒体4、前台1、固定4、FCM2独立通道。媒体分别29/59/119/159分钟，固定分别26/62/117/162分钟单次发送。计划锚点、已排项和随机文案索引持久化，刷新余额及冷启动不推迟、不重发；撤权取消，恢复授权仅恢复尚未到期项。媒体、固定、亮屏和锁屏从用户5组文案成对随机；FCM仅用后台文案，两个topic分别为c177fcm_piggy/c177fcm_piggy_two。初始化临时失败可在后续刷新重试。完整表及FCM格式见[通知规则](references/notifications.md)。
- 2026-10-28最新：真正后台返回前台时，无原生广告展示且路由、引导、任务和弹窗均允许，直接请求一次nkmdl_launch正常插屏；不在外层判断缓存，无缓存/未初始化/检查在途由管理器记录chance及失败原因，不定时补播。原生广告回切、权限窗口和通知点击导航必须跳过，使用PCForegroundAdController及PCDialogCoordinator展示锁，不从通知计时触发广告。
- App 前台使用 `PCInAppNotificationHost` 顶部账户或目标样式通知，支持关闭、上滑和 8 秒自动收起，无全屏遮罩；后台系统提醒与前台横幅分开显示。通知点击提现跳 Cash，Claim 跳 Quiz；未达目标不能显示可提现，冷启动点击等引导及首页就绪后处理。
- `PCNotificationCard` 复用本地文字、图片、描边和 `ParticleButton`，背景与文字分层。通知背景资源来自 `250:1192`，不要整张卡片截图或写死截图金额。

## 使用本地方法显示弹窗

- 弹窗显示入口统一使用 `lib/PCTool/pc_extension_help.dart` 的 `BuildContext` 扩展，由本地方法处理遮罩、动画和背景效果。
- **带毛玻璃**：`context.tipShow(dialog)`，默认 `blurSigma: 8`，需要时通过该参数调整模糊强度。
- **不带毛玻璃**：`context.tipShow2(dialog)`；按设计或同类弹窗选择是否需要毛玻璃效果，遮罩颜色可用 `bc` 参数设置。
- 已有 `context.tipShow(dialog, blurSigma: 0)` 调用同样不产生模糊，但其遮罩和动画仍属于 `tipShow`。维护这些调用时核对原有交互，不机械切换方法。
- 弹窗类负责内容布局，背景效果交给上述显示方法，避免在内容中重复叠加遮罩、模糊或入场动画。新入口不另写 `showDialog` / `showGeneralDialog` 来复制项目已有的显示流程。

## 弹窗独立文件与中文注释

- 每个具体弹窗放在 `lib/PCDialog/` 对应业务目录的同名文件，例如 `PCOther/PCNoNetworkDialog.dart`；一个文件只实现一个具体弹窗。
- 该弹窗的 `State` 和专属私有组件可留在同一文件。多个弹窗共用的基础组件提取到明确命名的公共组件文件，避免复制实现。
- 类前添加中文 `///` 文档注释，注明弹窗的用途或引导步骤、界面上可识别的标题或按钮，以及点击后关闭、重试、跳转或回调的行为。说明应与实际代码一致。

```dart
/// 广告加载失败弹窗（Try Again）。
///
/// Try Again和关闭按钮均仅关闭当前弹窗，不立即播放或重新请求广告。
```

- `PCCashDialog.dart` 和 `PCOtherDialog.dart` 是兼容导出入口；`PCGuideDialog.dart` 保留欢迎弹窗并导出各步骤，`PCAwardDialog.dart` 保留领奖弹窗并导出开罐奖励弹窗。拆分时维护原有导出 API，调用处可以直接导入具体弹窗文件。
- 核实遮罩、返回键、关闭按钮和主按钮行为；引导步骤继续保持原有顺序、计时器释放和弹窗关闭后的回调时机。

## 打点约定

- 使用PCAnalytics.event及真实曝光回调，重建不重复记点；已有事件不能再绕过统一入口调用pc_event_fire。2026-10-28确认的钻石同框双事件、优质用户两阶段、非FCM通知及场景对应见[逐行打点明细](../../../docs/analytics/pc_analytics_audit.json)。仅相关流程修改时查阅。

## 验证与交付

- 仅对修改的 Dart 文件运行 `dart format`，对相关文件及调用处运行 `dart analyze`。区分本次新增问题和已有警告。
- UI 发生变化时，在可用的设备、模拟器或预览上对照 Figma 检查布局和关键交互；无法运行时说明静态检查结果及尚未验证的视觉范围。
- 交付时列出主要改动、弹窗对应关系或资源路径，以及实际完成的验证。

- 广告请求未就绪、播放失败或异常时显示现有 PCAdLoadingFailedDialog；2026-10-26 用户更新：Try Again只关闭弹窗，不立即播放或重试广告，下次由用户再次点击原业务入口。排队/视频任务弹窗在同一路由切换失败面板，避免覆盖展示；Cash页失败前释放自己的排名反馈展示权，再串行显示失败弹窗。失败/取消不推进名次、任务或发奖。预加载先检查SDK缓存，已有缓存不重复load；检查缓存/加载中/展示中共用在途锁，不重复请求；手动触发和自动重试共用入口，成功及新请求开始时取消旧重试计时器。新用户首次签到失败仍按已有约定跳过签到继续引导。

- 2026-10-31：移除绿色金猪payout通知样式及余额跨首档自动弹出逻辑。PCNoticeKind仅保留account/goal；固定117分钟、媒体119分钟和FCM1改用goal，原8项定时计划、11通道和两topic保留。旧原生缓存template:payout降级goal/Claim，FCM样式签名包含kind以刷新旧元数据；用户5组随机文案池保留。

- 2026-10-31整体字号适配：页面与弹窗使用`PCAdaptiveLayout`按局部可用宽高统一缩放容器、字号、图标和间距，固定画布倍率上限1.6；正文可滚动时按宽度放大，完整弹窗仍受可用高度约束，小屏主按钮保留至少44逻辑像素命中。底部导航倍率上限1.3。已用局部倍率或FittedBox缩放的文字不再叠加全局宽比或.sp，避免重复放大；长题、长账号、键盘及320/430/768宽度须核对。
