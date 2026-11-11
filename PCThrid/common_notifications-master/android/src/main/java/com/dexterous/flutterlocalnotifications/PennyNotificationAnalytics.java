package com.dexterous.flutterlocalnotifications;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;

import androidx.core.app.NotificationManagerCompat;

import com.dexterous.flutterlocalnotifications.models.NotificationDetails;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/** 通知真正分发后的本地事件队列；仅保存类型与随机ID，不保存通知正文或账号。 */
public final class PennyNotificationAnalytics {
  static final String QUEUE_KEY = "penny_notification_analytics_v1";
  static final int MAX_PENDING = 256;

  private PennyNotificationAnalytics() {}

  static String typeFor(String payload, String broadcastAction) {
    if (Intent.ACTION_SCREEN_ON.equals(broadcastAction)
        || Intent.ACTION_SCREEN_OFF.equals(broadcastAction)
        || Intent.ACTION_USER_PRESENT.equals(broadcastAction)) {
      return "unlock";
    }
    String value = payload == null ? "" : payload.trim().toLowerCase(Locale.ROOT);
    if (value.startsWith("fcm")) return "fcm";
    if (value.equals("screenon") || value.equals("screenoff")
        || value.equals("turnon") || value.equals("turnoff") || value.equals("unlock")) {
      return "unlock";
    }
    return "local";
  }

  private static SharedPreferences preferences(Context context) {
    return context.getSharedPreferences(
        FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE);
  }

  private static boolean allowed(Context context, NotificationDetails details) {
    if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return false;
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && details.channelId != null) {
      NotificationManager manager =
          (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
      NotificationChannel channel = manager.getNotificationChannel(details.channelId);
      if (channel != null && channel.getImportance() == NotificationManager.IMPORTANCE_NONE) {
        return false;
      }
    }
    return true;
  }

  /** 只能在notify/startForeground正常返回后调用，权限或渠道关闭时不记录。 */
  static boolean recordShown(Context context, NotificationDetails details, String action) {
    try {
      if (!allowed(context, details)) return false;
      String type = typeFor(details.payload, action);
      // FCM曝光由后台口径统计，本地只记录其余真正分发的通知。
      if (type.equals("fcm")) return false;
      return append(context, type);
    } catch (RuntimeException ignored) {
      return false; // 统计存储失败不能阻止通知或前台服务。
    }
  }

  static boolean recordForegroundShown(Context context, NotificationDetails details) {
    try {
      if (!allowed(context, details)) return false;
      return append(context, "local");
    } catch (RuntimeException ignored) {
      return false;
    }
  }

  private static synchronized boolean append(Context context, String type) {
    List<Map<String, String>> pending = read(context);
    Map<String, String> event = new HashMap<>();
    event.put("eventId", UUID.randomUUID().toString());
    event.put("type", type);
    pending.add(event);
    while (pending.size() > MAX_PENDING) pending.remove(0);
    return save(context, pending);
  }

  public static synchronized List<Map<String, String>> getPending(Context context) {
    return read(context);
  }

  /** 仅删除Flutter确认已上报的ID，读取后新加入的通知必须保留。 */
  public static synchronized boolean acknowledge(Context context, Collection<String> eventIds) {
    Set<String> acknowledged = new HashSet<>(eventIds);
    List<Map<String, String>> pending = read(context);
    pending.removeIf(event -> acknowledged.contains(event.get("eventId")));
    return save(context, pending);
  }

  private static List<Map<String, String>> read(Context context) {
    List<Map<String, String>> pending = new ArrayList<>();
    try {
      JSONArray array = new JSONArray(preferences(context).getString(QUEUE_KEY, "[]"));
      for (int index = 0; index < array.length(); index++) {
        JSONObject item = array.optJSONObject(index);
        if (item == null) continue;
        String id = item.optString("eventId", "");
        String type = item.optString("type", "");
        if (id.isEmpty() || !(type.equals("local") || type.equals("unlock") || type.equals("fcm"))) {
          continue;
        }
        Map<String, String> event = new HashMap<>();
        event.put("eventId", id);
        event.put("type", type);
        pending.add(event);
      }
    } catch (JSONException | RuntimeException ignored) {
      // 损坏的旧队列不能阻止真实通知发送，也不能把未知内容当作事件上报。
    }
    return pending;
  }

  private static boolean save(Context context, List<Map<String, String>> pending) {
    JSONArray array = new JSONArray();
    for (Map<String, String> event : pending) array.put(new JSONObject(event));
    // 广播/FCM可能在进程退出前触发，使用commit保证事件先落盘。
    return preferences(context).edit().putString(QUEUE_KEY, array.toString()).commit();
  }
}
