package com.dexterous.flutterlocalnotifications;

import android.app.Notification;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import androidx.annotation.Keep;
import androidx.core.app.NotificationManagerCompat;

import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.dexterous.flutterlocalnotifications.utils.StringUtils;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;

import java.lang.reflect.Type;

/** Created by michaelbui on 24/3/18. */
@Keep
public class ScheduledNotificationReceiver extends BroadcastReceiver {

  private static final String TAG = "ScheduledNotifReceiver";

  @Override
  @SuppressWarnings("deprecation")
  public void onReceive(final Context context, Intent intent) {
    boolean notificationsEnabled = NotificationManagerCompat.from(context).areNotificationsEnabled();
    String notificationDetailsJson =
        intent.getStringExtra(FlutterLocalNotificationsPlugin.NOTIFICATION_DETAILS);
    if (StringUtils.isNullOrEmpty(notificationDetailsJson)) {
      if (!notificationsEnabled) return;
      // This logic is needed for apps that used the plugin prior to 0.3.4

      Notification notification;
      int notificationId = intent.getIntExtra("notification_id", 0);

      if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
        notification = intent.getParcelableExtra("notification", Notification.class);
      } else {
        notification = intent.getParcelableExtra("notification");
      }

      if (notification == null) {
        // This means the notification is corrupt
        FlutterLocalNotificationsPlugin.removeNotificationFromCache(context, notificationId);
        Log.e(TAG, "Failed to parse a notification from  Intent. ID: " + notificationId);
        return;
      }

      notification.when = System.currentTimeMillis();
      NotificationManagerCompat notificationManager = NotificationManagerCompat.from(context);
      notificationManager.notify(notificationId, notification);
      // 兼容插件早期直接携带Notification的存档，同样在真实分发后记录一次。
      NotificationDetails delivered = new NotificationDetails();
      delivered.id = notificationId;
      delivered.payload = intent.getStringExtra("payload");
      if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
        delivered.channelId = notification.getChannelId();
      }
      PennyNotificationAnalytics.recordShown(context, delivered, null);
      boolean repeat = intent.getBooleanExtra("repeat", false);
      if (!repeat) {
        FlutterLocalNotificationsPlugin.removeNotificationFromCache(context, notificationId);
      }
    } else {
      Gson gson = FlutterLocalNotificationsPlugin.buildGson();
      Type type = new TypeToken<NotificationDetails>() {}.getType();
      NotificationDetails notificationDetails = gson.fromJson(notificationDetailsJson, type);
      if (notificationDetails == null) return;
      if (!notificationsEnabled) {
        // 只保留本项目的周期链，用户恢复权限后仍能收到下一轮提醒。
        if (PennyNotificationStyle.isPenny(notificationDetails)) {
          FlutterLocalNotificationsPlugin.scheduleNextNotification(context, notificationDetails);
        }
        return;
      }
      // 前台由 Flutter 站内横幅展示；仍继续安排下一次后台提醒。
      if (!PennyNotificationStyle.suppressWhileForeground(notificationDetails)) {
        FlutterLocalNotificationsPlugin.showNotification(context, notificationDetails);
      }
      FlutterLocalNotificationsPlugin.scheduleNextNotification(context, notificationDetails);
    }
  }
}
