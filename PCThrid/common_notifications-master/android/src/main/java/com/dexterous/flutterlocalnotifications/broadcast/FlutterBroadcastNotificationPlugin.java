package com.dexterous.flutterlocalnotifications.broadcast;

import android.content.Context;
import android.content.SharedPreferences;

import androidx.annotation.Nullable;

import com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.dexterous.flutterlocalnotifications.models.styles.BeautyStyleInformation;
import com.dexterous.flutterlocalnotifications.utils.StringUtils;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;

import java.lang.reflect.Type;
import java.util.Objects;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ThreadLocalRandom;

public class FlutterBroadcastNotificationPlugin {
    public static void saveNotificationDetails(Context context, NotificationDetails details, String broadcast) {
        SharedPreferences sharedPreferences = context.getSharedPreferences(FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = sharedPreferences.edit();
        Gson gson = FlutterLocalNotificationsPlugin.buildGson();
        editor.putString("broadcastNotificationDetails" + Objects.hashCode(broadcast), gson.toJson(details));
        editor.putString("broadcastNotificationAction" + details.id, broadcast);
        editor.apply();
    }

    /** Remove persisted event state too, so a cancelled channel cannot resume later. */
    public static void removeNotificationDetails(Context context, int id) {
        SharedPreferences preferences = context.getSharedPreferences(FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = preferences.edit();
        for (Map.Entry<String, ?> entry : preferences.getAll().entrySet()) {
            if (!entry.getKey().startsWith("broadcastNotificationDetails") || !(entry.getValue() instanceof String)) continue;
            try {
                NotificationDetails details = FlutterLocalNotificationsPlugin.buildGson().fromJson((String) entry.getValue(), NotificationDetails.class);
                if (details == null || details.id != id) continue;
                String suffix = entry.getKey().substring("broadcastNotificationDetails".length());
                editor.remove(entry.getKey())
                        .remove("broadcastNotificationInterval" + suffix)
                        .remove("broadcastNotificationWhen" + suffix)
                        .remove("broadcastNotificationRandomMessages" + suffix);
            } catch (RuntimeException ignored) {
                // Skip malformed legacy entries without blocking cancellation.
            }
        }
        editor.remove("broadcastNotificationAction" + id).apply();
    }

    public static void saveRandomMessages(Context context, String broadcast, @Nullable List<Map<String, String>> messages) {
        SharedPreferences preferences = context.getSharedPreferences(FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = preferences.edit();
        String key = "broadcastNotificationRandomMessages" + Objects.hashCode(broadcast);
        if (messages == null || messages.isEmpty()) editor.remove(key);
        else editor.putString(key, FlutterLocalNotificationsPlugin.buildGson().toJson(messages));
        editor.apply();
    }

    /** Pick at delivery time, rather than freezing the copy selected during registration. */
    public static void applyRandomMessage(Context context, String broadcast, NotificationDetails details) {
        SharedPreferences preferences = context.getSharedPreferences(FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE);
        String json = preferences.getString("broadcastNotificationRandomMessages" + Objects.hashCode(broadcast), "");
        if (json == null || json.isEmpty()) return;
        try {
            Type type = new TypeToken<List<Map<String, String>>>() {}.getType();
            List<Map<String, String>> messages = FlutterLocalNotificationsPlugin.buildGson().fromJson(json, type);
            List<Map<String, String>> valid = new ArrayList<>();
            if (messages != null) for (Map<String, String> message : messages) {
                if (message != null && !StringUtils.isNullOrEmpty(message.get("title")) && !StringUtils.isNullOrEmpty(message.get("body"))) valid.add(message);
            }
            if (valid.isEmpty()) return;
            Map<String, String> selected = valid.get(ThreadLocalRandom.current().nextInt(valid.size()));
            details.title = selected.get("title");
            details.body = selected.get("body");
            if (details.styleInformation instanceof BeautyStyleInformation) {
                BeautyStyleInformation style = (BeautyStyleInformation) details.styleInformation;
                style.title = details.title;
                style.body = details.body;
            }
        } catch (RuntimeException ignored) {
            // Retain the registration's fallback copy when the stored pool is invalid.
        }
    }

    @Nullable
    public static NotificationDetails extractNotificationDetails(Context context, String broadcast) {
        SharedPreferences sharedPreferences = context.getSharedPreferences(FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE);
        String detailsJson = sharedPreferences.getString("broadcastNotificationDetails" + Objects.hashCode(broadcast), "");
        if (StringUtils.isNullOrEmpty(detailsJson)) return null;
        Gson gson = FlutterLocalNotificationsPlugin.buildGson();
        Type type = new TypeToken<NotificationDetails>() {
        }.getType();
        try {
            return gson.fromJson(detailsJson, type);
        } catch (RuntimeException ignored) {
            return null;
        }
    }

    public static void saveInterval(Context context, int interval, String broadcast) {
        SharedPreferences sharedPreferences = context.getSharedPreferences(FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = sharedPreferences.edit();
        editor.putInt("broadcastNotificationInterval" + Objects.hashCode(broadcast), interval);
        editor.apply();
    }

    public static int extractInterval(Context context, String broadcast) {
        SharedPreferences sharedPreferences = context.getSharedPreferences(FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE);
        return sharedPreferences.getInt("broadcastNotificationInterval" + Objects.hashCode(broadcast), -1);
    }

    public static void saveWhen(Context context, long when, String broadcast) {
        SharedPreferences sharedPreferences = context.getSharedPreferences(FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = sharedPreferences.edit();
        editor.putLong("broadcastNotificationWhen" + Objects.hashCode(broadcast), when);
        editor.apply();
    }

    public static long extractWhen(Context context, String broadcast) {
        SharedPreferences sharedPreferences = context.getSharedPreferences(FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE);
        return sharedPreferences.getLong("broadcastNotificationWhen" + Objects.hashCode(broadcast), -1L);
    }
}
