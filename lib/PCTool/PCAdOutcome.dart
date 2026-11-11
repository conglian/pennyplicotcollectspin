/// 每次广告请求自己的结果；正常取消不等于播放失败，也不能作为领奖成功。
enum PCAdOutcome {
  success,
  cancelled,
  failed;

  bool get isSuccess => this == success;
}
