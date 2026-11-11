# penyplicotcollectspinsh5

Android 原生 H5 入口的 Flutter 桥接。宿主 SDK 初始化时调用：

```dart
import 'package:penyplicotcollectspinsh5/penyplicotcollectspinsh5.dart';

await Penyplicotcollectspinsh5().create();
```

宿主应仅在 Android 平台、Activity 已挂载后调用。插件通过 `ActivityAware` 获取当前宿主，将 `create` 转发给现有 `Penyplicotcollectspinsh5Class.create(activity)`；同一 Activity 重复调用不会重复创建。没有有效 Activity 时返回 `H5_NO_ACTIVITY`，桥接层捕获到的调用错误返回 `H5_CREATE_FAILED`。

Future 完成及日志 `create returned` 只表示原生入口已经返回。Java 入口保留原有内部异常处理，不能据此推断网页已经加载成功。

宿主 Activity 正常卸载时，在 `onDetachedFromActivity()` 调用现有 `Penyplicotcollectspinsh5Class.clear(activity)`，日志为 `clear invoked` / `clear returned`；清理异常会记录 `clear failed`，不会阻断宿主退出。清理前释放桥接引用，重复卸载或后续 Engine 卸载不会再次清理。配置变化的临时卸载和重新挂载只管理 Activity 引用，不执行 `create` 或 `clear`。进入后台、切换 Tab 或关闭普通 Flutter 网页不触发此清理。

`getPlatformVersion()` 保留原有兼容接口。原生 `create` / `clear`、JNI 及 `.so` 实现保持不变。

原生 `onPageStarted` / `onPageFinished` 的完整 URL 通过现有通道转发到 Flutter，调用 `create()` 时会先安装日志接收器，无需宿主额外订阅。在 Flutter Debug Console 或 `flutter run` 输出中搜索 `[H5]`：

```text
[H5] onPageStarted url=https://example.com/game?source=app
[H5] onPageFinished url=https://example.com/game?source=app
```

日志保留完整路径和查询参数；非法或未知回调不会打印。修改原生插件代码后需要重新构建并完整重启 App，Hot Reload 不会更新原生实现。

需要让实际网页使用原生 `WKSHuhs` 监听时，可在 Android 页面嵌入：

```dart
const Penyplicotcollectspinsh5WebView(
  url: 'https://example.com/game',
)
```

该组件通过 `penyplicotcollectspinsh5/webview` PlatformView 创建原生 WebView，URL 通过创建参数传入；URL 变化会重建视图。视图创建前会同步启用 Flutter 日志接收，不再调用原生 `create`。独立启用日志也可调用 `Penyplicotcollectspinsh5().startPageLogging()`。非 Android 平台显示可读占位，宿主可自行保留其他平台的网页组件。

