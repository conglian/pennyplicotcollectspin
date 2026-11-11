import 'package:adjust_sdk/adjust_ad_revenue.dart';
import 'package:cloudx_flutter/models/cloudx_ad.dart';

/// 聚合收入映射：CloudX 当前必须使用 Adjust 支持的 publisher_sdk 来源。
/// 收入为单次展示的美元原值，不能使用 eCPM 或再次除以1000。
class PCAdRevenue {
  static const cloudXSource = 'publisher_sdk';
  static const topOnSource = 'topon_sdk';

  static double? amount(Object? value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    return number != null && number.isFinite && number >= 0 ? number : null;
  }

  static AdjustAdRevenue? cloudX(CloudXAd ad, {String? placement}) {
    final revenue = amount(ad.revenue);
    if (revenue == null) return null;
    // 本次调用的业务场景优先，SDK缓存可能仍携带上一次展示的placement。
    final actualPlacement = placement?.isNotEmpty == true
        ? placement!
        : ad.placement;
    return AdjustAdRevenue(cloudXSource)
      ..setRevenue(revenue, 'USD')
      ..adRevenueNetwork = ad.networkName
      ..adRevenueUnit = ad.adUnitId
      ..adRevenuePlacement = actualPlacement
      ..addCallbackParameter('mediation_platform', 'cloudx')
      ..addCallbackParameter('ad_type', ad.adFormat.value)
      ..addCallbackParameter('ad_unit_id', ad.adUnitId);
  }

  static AdjustAdRevenue? topOn(
    Map extra, {
    String? placement,
    String? adUnitId,
  }) {
    final revenue = amount(extra['publisher_revenue']);
    if (revenue == null) return null;
    final currency = extra['currency']?.toString().trim();
    return AdjustAdRevenue(topOnSource)
      ..setRevenue(revenue, currency?.isNotEmpty == true ? currency! : 'USD')
      ..adRevenueNetwork = extra['network_name']?.toString()
      ..adRevenueUnit = (extra['adunit_id'] ?? adUnitId)?.toString()
      ..adRevenuePlacement = placement;
  }
}
