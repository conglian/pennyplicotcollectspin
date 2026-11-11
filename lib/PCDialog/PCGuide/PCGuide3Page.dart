import 'package:flutter/material.dart';

import 'PCGuidePageLayout.dart';
import 'PCGuide3Artwork.dart';

/// Figma「引导页3」：展示广告品牌、广告电视与现金收益插画。
///
/// 点击 Let's Start Earning 保存前三页完成状态并交回启动流程。
/// 后续新用户业务引导由控制器预留的完成出口另行接入。
class PCGuide3Page extends StatelessWidget {
  const PCGuide3Page({super.key, required this.onNext, this.isBusy = false});

  final VoidCallback onNext;
  final bool isBusy;

  @override
  Widget build(BuildContext context) => PCGuidePageLayout(
    title: 'Advertisers Pay, And We Save\nWith You',
    buttonText: 'Let’s Start Earning',
    onNext: onNext,
    isBusy: isBusy,
    illustration: const PCGuide3Artwork(),
  );
}
