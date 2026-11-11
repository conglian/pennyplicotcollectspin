---
name: pennypilot-assets
description: "为 PennyPilot（pennypilotcollectspin）Flutter 项目从指定 Figma 下载、替换和导入图片资源，按 3× 导出 PNG，自动无损压缩并校验图像数据和元数据。用于实际资源处理或 UI 开发中的素材获取；只讨论设计或不涉及素材的代码修改不触发。"
---

# PennyPilot 资源下载

## 来源和倍率

- 默认设计来源：[Figma · 177](https://www.figma.com/design/i4Xsv9T30MQY7ySoExu4Fi/177?node-id=0-1)，file key 为 `i4Xsv9T30MQY7ySoExu4Fi`；也可从项目根目录 [README.md](../../../README.md#设计资源) 查阅约定。
- 下载任务指定或实现所需的素材节点。页面入口 `0:1` 用于定位，未指定范围时结合当前 UI 任务寻找对应图层，不能据此批量替换整个项目的图片。
- 图片直接从 Figma 以 **3× PNG** 导出，保留透明背景。使用 `download_assets` 时明确传入 `fileKey`、目标 `nodeId`、`defaultFormat: "png"` 和 `defaultScale: 3`；这是用户已明确约定的格式与倍率。
- 使用节点的导出渲染结果。`rawImages` 是原始填充图片，不能据此宣称完成了 3× 导出；截图预览也不能作为正式素材。不能把低倍率图放大成 3 倍图。
- 导入透明素材后检查 Alpha 通道，并在实际页面背景上核对。若 `download_assets` 的导出意外出现白底，改用 `use_figma` 中节点的 `exportAsync({format: 'PNG', constraint: {type: 'SCALE', value: 3}, contentsOnly: true})` 原生导出，再交给同一无损压缩脚本；保留设计中本来存在的底色。`use_figma` 返回值有大小限制，大文件分段传回后必须校验完整 PNG 的 CRC 和图像流。
- 导出宽高依据节点实际导出边界核对，包括阴影或效果溢出。文件名里的 `_2x`、`_3x` 不作为倍率证据；下载临时 URL 后及时处理。

## 下载后自动无损压缩

执行本 Skill 附带的 [scripts/import_png.py](scripts/import_png.py)，将下载、压缩、校验和落盘串联完成。脚本只依赖 Python 3 标准库，不需要安装图片库或压缩软件。

在项目根目录运行，参数替换成真实导出 URL 和目标路径：

```sh
python3 .agents/skills/pennypilot-assets/scripts/import_png.py \
  'FIGMA_EXPORT_URL' --output assets/images/pc_feature_icon.png
```

也可处理已经下载到临时目录的 PNG。已知准确导出像素尺寸时追加 `--expected-size WIDTH HEIGHT`；更新已确认对应同一素材的现有文件时追加 `--replace`。所有路径和 URL 参数应按 shell 规则正确引用。

脚本执行以下保证：

- 校验 PNG 结构、各数据块 CRC 及完整 zlib 图像流；不接受伪装成 PNG 的文件。
- 仅重新压缩 `IDAT` 图像数据，不缩放、不量化、不抖动、不转换色彩空间，也不删除颜色配置或透明信息。
- 比较压缩前后解压得到的图像扫描线数据以及全部非 `IDAT` 数据块。它们逐字节相同，因此解码像素、尺寸、颜色和透明通道保持一致。
- 输出不大于原文件；压缩无收益时保留原字节。验证通过后原子写入目标文件；校验失败不覆盖现有文件。
- 输出 JSON，包含目标路径、像素宽高、前后字节数、节省比例和校验结果。只处理静态 PNG，动画素材保持其原有流程。

无损压缩不能替换为 `pngquant`、颜色量化、JPEG 转码或其他有损方案。导出、下载或校验失败时修正实际问题后再导入，不能跳过校验后声称完成。

## 项目资源接入

- 当前图片目录为 `assets/images/`，已经在 `pubspec.yaml` 注册。使用现有 `pc_` 等命名；新资源优先采用明确用途的 `pc_feature_name.png`，避免覆盖不同用途的同名素材。
- 设置页`786:262`、首页齿轮`795:598`的11张`pc_settings_*`透明3×切片及无损校验见[settings-assets.json](references/settings-assets.json)。面板、四种开关状态、列表底图及小图标分层导出；标题、条款文案和链接由Flutter绘制。音频使用用户提供的MP3原字节，以英文名`bgm.mp3`、`quiz_option.mp3`、`reward_collect.mp3`放入`assets/File/`，不做有损转码。
- `PCImg(name: 'pc_feature_name')` 和 `'pc_feature_name'.image()` 会查找 `assets/images/pc_feature_name.png`。保持这个路径契约，不擅自迁移现有资源目录或批量重命名 `_2x` 文件。
- 3× 是图像像素倍率，Flutter 组件仍按设计稿的逻辑尺寸设置 `width` / `height`。
- 新图片若需使用 Flutter 的 `3.0x/` 密度变体机制，先检查和正确接入对应逻辑资源路径；本项目现有根目录 PNG 引用方式不因本 Skill 自动改变。
- 只导入本次所需资源，并核对代码引用。交付时给出 Figma 节点、3× 倍率、目标文件、实际像素尺寸及压缩前后大小；若无压缩收益，明确说明保留原文件。
- 引导1–3已导入素材的节点、尺寸、压缩结果及透明通道记录见 [references/guide-intro-assets.json](references/guide-intro-assets.json)。
- 签到气泡及签到弹窗的分层 3× 素材见 [references/checkin-assets.json](references/checkin-assets.json)，底板、标题、树叶、纸钞分别导入，日期、金额和按钮使用原生组件。
- 引导3三行滚动卡片的独立3×素材记录见 [references/guide-brand-assets.json](references/guide-brand-assets.json)，按卡片重复排布实现循环，不裁切拼接整行截图。
- 排行榜的 54 张专用头像来自 Figma「头像」节点 `558:257`，3× 导出为 144×144 PNG，透明通道及无损压缩记录见 [references/ranking-avatar-assets.json](references/ranking-avatar-assets.json)；资源名为 `pc_rank_avatar_01` 至 `pc_rank_avatar_54`，由每日榜单绑定。
- 排行榜弹幕展示页为 `194:111`；金猪 `194:157` 和四个独立统计小图标的 3× 透明导出记录见 [references/pig-show-assets.json](references/pig-show-assets.json)，粉猪、按钮和关闭图标复用现有素材，不导入整页截图。
- 启动页和 Logo 的 3× 素材、透明通道及 Android/iOS 图标尺寸记录见 [references/launch-assets.json](references/launch-assets.json)。平台桌面图标从 3× 高清母图按各平台要求生成，PNG 编码继续无损压缩；iOS 图标保留不透明 RGB。

- 通知卡片 `250:1192` 的原3×PNG导出及无损校验历史见 [references/notification-assets.json](references/notification-assets.json)。2026-10-31用户删除绿色金猪payout通知样式：对应Flutter/Android专用图片及原生布局已移除，不再导入或使用；pc_notice_hand仍由Flutter账号确认弹窗复用。保留的账户/目标通知金额、文案和按钮行为继续由代码渲染。
- 账户余额前台服务的头像单独从 `250:1430` 原生3×导出为156×156透明PNG `pc_notice_account_icon`，见[前台服务资源记录](references/foreground-notification-assets.json)。Android展开/收起共用此图，PayPal水印复用`250:1285`的204×204原图；标题、实时金额和按钮由原生RemoteViews分层呈现，不能下载整张通知作背景。

- 普通答题钻石猪 `431:540`、金砖猪 `431:550` 的 3× 透明 PNG 均为 504×420；无损压缩及图像数据校验记录见 [references/quiz-assets.json](references/quiz-assets.json)。奖励底板、光效与小图标继续复用原有资源。美元纸钞堆使用 `127:96` 独立透明导出 `pc_quiz_cash_reward.png`（3× 600×276），与用户 2026-10-22 截图一致，不能再用横向铺开的 `pc_dollars_icon`。
- 领奖主图 `pc_award_diamond` / `pc_award_gold` 来自 Figma `431:389` / `431:391`，原始填充图片315×286 / 682×462，按100×100逻辑槽位原生导出300×300透明PNG并无损压缩，记录见 [references/award-artwork-assets.json](references/award-artwork-assets.json)。真实导出约束为WIDTH300，对应目标槽位3×，不是原48逻辑节点的SCALE3；没有将48px旧文件插值放大。图案与光圈独立，保留设计中的形状与透明边界。
- 三个页面钻石/金猪顶部的分层 3× PNG 见 [references/stage-balance-assets.json](references/stage-balance-assets.json)：底板、两种小猪、两种进度游标、两种收集图标和进度槽分别导出并无损压缩；文字与数量由 `PCBalanceHeader` 读取缓存后绘制，不导入整张顶部截图。
- 转盘机会不足弹窗 `207:482` 的标题、底板、轮盘图标及光效，和转盘 `201:677` 的底图及各分区图案，均以透明3×PNG分层导出，记录见 [references/wheel-assets.json](references/wheel-assets.json)。配置金额文字由代码绘制，不能继续把美元范围盖在Cash Bag或Try Again区域上。
- 2026-10-28新版转盘H5宝箱气泡来自 `197:413` 内 `772:286`，透明3×PNG `pc_wheel_bonus_chest` 为192×192、逻辑64×64；无损压缩77732→72247字节并校验，见 [references/wheel-h5-chest-assets.json](references/wheel-h5-chest-assets.json)。呼吸动画由PCWheelBonusChest实现，不能导入整张转盘。
- 首页金砖气泡 `613:283`、钻石气泡 `613:289` 均导出透明3×PNG（192×192），保留64×64逻辑尺寸；资源及无损压缩记录见 [references/home-bubble-assets.json](references/home-bubble-assets.json)。美元继续复用 `pc_doaller_icon`，底部金额/数量由 `PCHomeRewardBubble` 独立绘制。
- 2026-10-27新版首页 `1:5` 的Quiz/Wheel/Gold Apple气泡本体分别从 `15:173` / `15:185` / `15:181` 原生透明3×导出192×192；静态名称随各自气泡导出，AD独立绘制。tips背板 `15:143` 为600×120、尾巴 `15:149` 为36×24，提示文字独立使用PCText；顶部PayPal `196:245` 为156×156，不能再放大旧52×52图。无损压缩、透明及元数据记录见 [references/home-refresh-assets.json](references/home-refresh-assets.json)。
- 老用户回访 Grow Bonus 使用 Figma `gba 178:106`，底板、标题框、纹理、亮边、蝴蝶结、小猪和红色按钮分别以3×PNG导出并无损校验，见 [references/grow-bonus-assets.json](references/grow-bonus-assets.json)。标题、金额、成长比例和按钮文字由 `PCGrowBonusContent` 独立绘制，新用户权限弹窗复用同一布局。
- 美元满档和 20 钻石后的升级页分别为 `214:222`、`230:391`。分层丝带、金额牌、PayPal 标签以及猪内装美元的钻石猪/金猪，透明 3× 导出与无损压缩记录见 [references/pig-upgrade-assets.json](references/pig-upgrade-assets.json)。升级专用小猪与普通答题领奖的小猪内装物不同，不能混用。原生导出可通过 `figma.io.write(filename, bytes)` 返回 PNG image 内容，避免大尺寸 base64 文本超过返回限制。
- 2026-10-26 用户明确要求将金猪升级顶部对勾、文字和背景一起切图：`231:456` 标题子树整体3×原生导出为 `pc_gold_upgrade_header.png`（1080×240透明PNG），已自动无损压缩并校验，见 [references/gold-upgrade-header-assets.json](references/gold-upgrade-header-assets.json)。该合图仅用于静态标题，不能把动态金额、账号、日期和金砖进度一并烘焙。

- 3.7 账号邀请、资料确认横幅的分层图片见 [references/process-account-assets.json](references/process-account-assets.json)；排行烟花、审核钻石和状态图见 [references/process-review-ranking-assets.json](references/process-review-ranking-assets.json)。全部为透明 3× 原生导出并无损校验。账号邀请背后光圈直接复用本地 `assets/File/guang_bg.zip` 循环，不再次下载静态光代替动画。
- 确认成功与答题的倾斜红色横幅分别对应 `211:757`、`211:808`，共用的原图节点、复用关系和校验记录见 [references/process-banners-assets.json](references/process-banners-assets.json)。复用已核对的 `pc_process_account_*` 分层原图，不截用户截图或整个页面；动态文字和金额继续由 Flutter 绘制。

## 脚本验证

修改脚本后运行：

```sh
python3 -B -m unittest discover \
  -s .agents/skills/pennypilot-assets/scripts -p 'test_*.py' -v
```
