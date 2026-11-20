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
  static final int MAX_VISIBLE_NOTIFICATIONS = 20;
  private static final int FIRST_DISPLAY_ID = 20_000;
  private static final String DISPLAY_CURSOR = "penny_notification_display_cursor_v1";
  private static final String DISPLAY_SOURCE = "penny_notification_display_source_";
  private static final String DISPLAY_TAG = "penny_notification_display_tag_";
  private static final String DISPLAY_DISMISS_TOKEN = "penny_notification_display_dismiss_";
  private static final String LAST_SCENE_TRIGGER = "penny_notification_last_scene_v1";
  private static final String LOCAL_COPY_POOL = "penny_local_notification_copy_pool_v1";
  private static final String LOCAL_COPY_CURSOR = "penny_local_notification_copy_cursor_v1";

  private PennyNotificationAnalytics() {}

  static String typeFor(String payload, String broadcastAction) {
    String value = payload == null ? "" : payload.trim().toLowerCase(Locale.ROOT);
    if (value.startsWith("{")) {
      try {
        String type = new JSONObject(value).optString("type", "").trim();
        if (validType(type)) return canonicalType(type);
      } catch (JSONException ignored) {
        // Continue with legacy payload handling.
      }
    }
    if (Intent.ACTION_USER_PRESENT.equals(broadcastAction)) return "unlock";
    if (Intent.ACTION_SCREEN_ON.equals(broadcastAction)) return "screen_on";
    if (Intent.ACTION_SCREEN_OFF.equals(broadcastAction)) return "screen_off";
    if (Intent.ACTION_POWER_CONNECTED.equals(broadcastAction)) return "power_connected";
    if (Intent.ACTION_POWER_DISCONNECTED.equals(broadcastAction)) return "power_disconnected";
    if (Intent.ACTION_CLOSE_SYSTEM_DIALOGS.equals(broadcastAction)) return "background";
    if (Intent.ACTION_TIME_CHANGED.equals(broadcastAction)) return "system_time_changed";
    if (Intent.ACTION_TIMEZONE_CHANGED.equals(broadcastAction)) return "system_timezone_changed";
    if (Intent.ACTION_DATE_CHANGED.equals(broadcastAction)) return "system_date_changed";
    if (value.startsWith("fcm")) return "fcm";
    if (value.equals("foreground")) return "foreground_service";
    if (value.equals("screenon")) return "screen_on";
    if (value.equals("screenoff")) return "screen_off";
    if (value.equals("unlock")) return "unlock";
    if (value.equals("home_key") || value.equals("background")) return "background";
    return "local";
  }

  private static String canonicalType(String type) {
    return "home_key".equals(type) ? "background" : type;
  }

  private static boolean validType(String type) {
    return type != null && type.matches("[a-zA-Z0-9_]{1,40}");
  }

  private static SharedPreferences preferences(Context context) {
    return context.getSharedPreferences(
        FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE);
  }

  static boolean allowed(Context context, NotificationDetails details) {
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

  /** Applies the warm-version scene throttle and a shared 20-slot notification ring. */
  static int prepareDispatch(
      Context context, NotificationDetails details, String broadcastAction) {
    return prepareDispatch(context, details, broadcastAction, null);
  }

  static synchronized int prepareDispatch(
      Context context, NotificationDetails details, String broadcastAction, String dismissToken) {
    try {
      if (!allowed(context, details)) return -1;
      String type = typeFor(details.payload, broadcastAction);
      if (isSceneType(type)) {
        SharedPreferences preferences = preferences(context);
        long now = System.currentTimeMillis();
        long last = preferences.getLong(LAST_SCENE_TRIGGER, 0L);
        if (now - last < 12_000L) return -1;
        if (!preferences.edit().putLong(LAST_SCENE_TRIGGER, now).commit()) return -1;
      }
      SharedPreferences preferences = preferences(context);
      int slot = preferences.getInt(DISPLAY_CURSOR, 0) % MAX_VISIBLE_NOTIFICATIONS;
      int displayId = FIRST_DISPLAY_ID + slot;
      NotificationManagerCompat.from(context).cancel(
          preferences.getString(DISPLAY_TAG + slot, null), displayId);
      preferences.edit()
          .putInt(DISPLAY_CURSOR, (slot + 1) % MAX_VISIBLE_NOTIFICATIONS)
          .putInt(DISPLAY_SOURCE + slot, details.id)
          .putString(DISPLAY_TAG + slot, details.tag)
          .putString(DISPLAY_DISMISS_TOKEN + slot, dismissToken)
          .commit();
      return displayId;
    } catch (RuntimeException ignored) {
      return details.id;
    }
  }

  static boolean isSceneType(String type) {
    return type.equals("background") || type.equals("unlock")
        || type.equals("screen_on") || type.equals("screen_off")
        || type.equals("power_connected") || type.equals("power_disconnected")
        || type.startsWith("system_")
        || type.startsWith("package_");
  }

  static synchronized void cancelSource(Context context, int sourceId) {
    SharedPreferences preferences = preferences(context);
    NotificationManagerCompat manager = NotificationManagerCompat.from(context);
    SharedPreferences.Editor editor = preferences.edit();
    for (int slot = 0; slot < MAX_VISIBLE_NOTIFICATIONS; slot++) {
      String key = DISPLAY_SOURCE + slot;
      if (!preferences.contains(key) || preferences.getInt(key, 0) != sourceId) continue;
      cancelSlot(manager, preferences, editor, slot);
    }
    editor.apply();
  }

  static synchronized void cancelClicked(Context context, String dismissToken) {
    SharedPreferences preferences = preferences(context);
    for (int slot = 0; slot < MAX_VISIBLE_NOTIFICATIONS; slot++) {
      if (!dismissToken.equals(preferences.getString(DISPLAY_DISMISS_TOKEN + slot, null))) continue;
      SharedPreferences.Editor editor = preferences.edit();
      cancelSlot(NotificationManagerCompat.from(context), preferences, editor, slot);
      editor.apply();
      return;
    }
  }

  static synchronized void clearDisplaySlots(Context context) {
    NotificationManagerCompat manager = NotificationManagerCompat.from(context);
    SharedPreferences preferences = preferences(context);
    SharedPreferences.Editor editor = preferences.edit().remove(DISPLAY_CURSOR);
    for (int slot = 0; slot < MAX_VISIBLE_NOTIFICATIONS; slot++) {
      cancelSlot(manager, preferences, editor, slot);
    }
    editor.commit();
  }

  private static void cancelSlot(NotificationManagerCompat manager, SharedPreferences preferences,
                                 SharedPreferences.Editor editor, int slot) {
    manager.cancel(preferences.getString(DISPLAY_TAG + slot, null), FIRST_DISPLAY_ID + slot);
    editor.remove(DISPLAY_SOURCE + slot)
        .remove(DISPLAY_TAG + slot)
        .remove(DISPLAY_DISMISS_TOKEN + slot);
  }

  static synchronized void configureLocalCopies(Context context, JSONArray copies) {
    String value = copies == null ? "[]" : copies.toString();
    SharedPreferences preferences = preferences(context);
    if (value.equals(preferences.getString(LOCAL_COPY_POOL, null))) return;
    SharedPreferences.Editor editor = preferences.edit().putString(LOCAL_COPY_POOL, value);
    if (!preferences.contains(LOCAL_COPY_CURSOR)) editor.putInt(LOCAL_COPY_CURSOR, 0);
    editor.commit();
  }

  static synchronized void applyNextLocalCopy(Context context, NotificationDetails details) {
    if (!"local".equals(typeFor(details.payload, null))) return;
    SharedPreferences preferences = preferences(context);
    try {
      JSONArray copies = new JSONArray(preferences.getString(LOCAL_COPY_POOL, "[]"));
      if (copies.length() == 0) return;
      int index = Math.floorMod(preferences.getInt(LOCAL_COPY_CURSOR, 0), copies.length());
      JSONObject copy = copies.optJSONObject(index);
      if (copy == null) return;
      details.title = copy.optString("title", details.title);
      details.body = copy.optString("body", details.body);
      if (details.styleInformation instanceof com.dexterous.flutterlocalnotifications.models.styles.BeautyStyleInformation) {
        com.dexterous.flutterlocalnotifications.models.styles.BeautyStyleInformation style =
            (com.dexterous.flutterlocalnotifications.models.styles.BeautyStyleInformation) details.styleInformation;
        style.title = details.title;
        style.body = details.body;
      }
      preferences.edit().putInt(LOCAL_COPY_CURSOR, (index + 1) % copies.length()).commit();
    } catch (JSONException | RuntimeException ignored) {
      // Keep the already scheduled copy if the local pool is not available.
    }
  }

  /** 只能在notify/startForeground正常返回后调用，权限或渠道关闭时不记录。 */
  static boolean recordShown(Context context, NotificationDetails details, String action) {
    try {
      if (!allowed(context, details)) return false;
      String type = typeFor(details.payload, action);
      return append(context, type);
    } catch (RuntimeException ignored) {
      return false; // 统计存储失败不能阻止通知或前台服务。
    }
  }

  static boolean recordForegroundShown(Context context, NotificationDetails details) {
    try {
      if (!allowed(context, details)) return false;
      return append(context, "foreground_service");
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
        if (id.isEmpty() || !validType(type)) {
          continue;
        }
        Map<String, String> event = new HashMap<>();
        event.put("eventId", id);
        event.put("type", canonicalType(type));
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
