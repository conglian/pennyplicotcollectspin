package com.dexterous.flutterlocalnotifications;

import android.app.ActivityManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Shader;
import android.graphics.Typeface;
import android.view.View;
import android.widget.RemoteViews;
import androidx.core.app.NotificationCompat;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.dexterous.flutterlocalnotifications.models.styles.BeautyStyleInformation;

/** PennyPilot 分层通知模板，保留旧 BeautyStyleInformation 调用兼容。 */
final class PennyNotificationStyle {
  private PennyNotificationStyle() {}

  static boolean isPenny(NotificationDetails details) {
    if (!(details.styleInformation instanceof BeautyStyleInformation)) return false;
    BeautyStyleInformation info = (BeautyStyleInformation) details.styleInformation;
    info.normalizeTemplate();
    return "account".equals(info.template) || "goal".equals(info.template);
  }

  static boolean suppressWhileForeground(NotificationDetails details) {
    if (!isPenny(details)) return false;
    ActivityManager.RunningAppProcessInfo process = new ActivityManager.RunningAppProcessInfo();
    ActivityManager.getMyMemoryState(process);
    return process.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND;
  }

  static boolean apply(Context context, NotificationDetails details, NotificationCompat.Builder builder) {
    if (!isPenny(details)) return false;
    BeautyStyleInformation info = (BeautyStyleInformation) details.styleInformation;
    boolean account = "account".equals(info.template);
    RemoteViews small = new RemoteViews(context.getPackageName(),
        account ? R.layout.pc_notice_account_compact : R.layout.pc_notice_compact);
    small.setImageViewResource(R.id.pc_notice_icon,
        account ? R.drawable.pc_notice_account_icon : R.drawable.pc_notice_app_icon);
    small.setImageViewResource(R.id.pc_notice_watermark, R.drawable.pc_notice_paypal);
    small.setViewVisibility(R.id.pc_notice_watermark, account ? View.VISIBLE : View.GONE);
    small.setTextViewText(R.id.pc_notice_title, info.title);
    small.setViewVisibility(R.id.pc_notice_amount, account ? View.VISIBLE : View.GONE);
    if (account) bindAmount(context, small, info.amount);
    else small.setTextViewText(R.id.pc_notice_amount, "");
    small.setTextViewText(R.id.pc_notice_button, info.button);

    int bigLayout = account ? R.layout.pc_notice_account : R.layout.pc_notice_goal;
    RemoteViews big = new RemoteViews(context.getPackageName(), bigLayout);
    if (account) {
      big.setTextViewText(R.id.pc_notice_title, info.title + "=");
      bindAmount(context, big, info.amount);
      big.setImageViewResource(R.id.pc_notice_icon, R.drawable.pc_notice_account_icon);
      big.setImageViewResource(R.id.pc_notice_watermark, R.drawable.pc_notice_paypal);
    } else {
      big.setImageViewResource(R.id.pc_notice_background, R.drawable.pc_notice_goal_bg);
      big.setTextViewText(R.id.pc_notice_title, info.title);
      big.setTextViewText(R.id.pc_notice_body, info.body);
    }
    big.setTextViewText(R.id.pc_notice_button, info.button);
    // 整张卡片和按钮均复用系统已有的点击 Intent，冷启动也能带回 payload。
    PendingIntent contentIntent = builder.build().contentIntent;
    if (contentIntent != null) {
      PendingIntent compactIntent = contentIntent;
      small.setOnClickPendingIntent(R.id.pc_notice_button, compactIntent);
      small.setOnClickPendingIntent(R.id.pc_notice_root, compactIntent);
      big.setOnClickPendingIntent(R.id.pc_notice_button, contentIntent);
      big.setOnClickPendingIntent(R.id.pc_notice_root, contentIntent);
    }
    builder.setStyle(new NotificationCompat.DecoratedCustomViewStyle());
    builder.setCustomContentView(small);
    builder.setCustomHeadsUpContentView(small);
    builder.setCustomBigContentView(big);
    return true;
  }

  /** RemoteViews不支持自定义文字View；仅金额用Canvas绘制渐变描边，并保留无障碍文本。 */
  private static void bindAmount(Context context, RemoteViews view, String value) {
    String amount = value == null ? "" : value;
    float density = context.getResources().getDisplayMetrics().density;
    Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    paint.setTypeface(Typeface.create("sans-serif", Typeface.BOLD));
    paint.setTextSize(20 * density);
    Paint.FontMetrics metrics = paint.getFontMetrics();
    float padding = 1.5f * density;
    int width = Math.max(1, (int) Math.ceil(paint.measureText(amount) + 2 * padding));
    int height = Math.max(1, (int) Math.ceil(metrics.descent - metrics.ascent + 2 * padding));
    Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
    Canvas canvas = new Canvas(bitmap);
    float baseline = padding - metrics.ascent;
    paint.setStyle(Paint.Style.STROKE);
    paint.setStrokeWidth(density);
    paint.setStrokeJoin(Paint.Join.ROUND);
    paint.setColor(Color.rgb(126, 57, 0));
    canvas.drawText(amount, padding, baseline, paint);
    paint.setStyle(Paint.Style.FILL);
    paint.setShader(new LinearGradient(0, padding, 0, height - padding,
        Color.rgb(255, 218, 80), Color.rgb(255, 175, 0), Shader.TileMode.CLAMP));
    canvas.drawText(amount, padding, baseline, paint);
    view.setImageViewBitmap(R.id.pc_notice_amount, bitmap);
    view.setContentDescription(R.id.pc_notice_amount, amount);
  }
}
