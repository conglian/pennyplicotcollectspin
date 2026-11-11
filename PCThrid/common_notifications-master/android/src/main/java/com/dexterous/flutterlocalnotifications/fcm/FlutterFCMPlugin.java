package com.dexterous.flutterlocalnotifications.fcm;

import android.content.Context;
import android.content.SharedPreferences;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.dexterous.flutterlocalnotifications.models.styles.BeautyStyleInformation;
import com.google.gson.Gson;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

public class FlutterFCMPlugin {
    private static final String TOPICS_KEY = "fcm_topics_v2";
    private static final String DETAILS_PREFIX = "fcm_topic_details_v2_";

    @Nullable
    public static String normalizeTopic(@Nullable String topic) {
        if (topic == null) return null;
        String value = topic.startsWith("/topics/") ? topic.substring(8) : topic;
        return value.matches("[a-zA-Z0-9\\-_.~%]{1,900}") ? value : null;
    }

    /** Each FCM channel owns its template; subscribing to channel two never replaces channel one. */
    public static void saveNotificationDetails(Context context, String topic, NotificationDetails details) {
        SharedPreferences preferences = context.getSharedPreferences(FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE);
        Set<String> topics = new HashSet<>(preferences.getStringSet(TOPICS_KEY, Collections.emptySet()));
        topics.add(topic);
        preferences.edit()
                .putString(DETAILS_PREFIX + topic, FlutterLocalNotificationsPlugin.buildGson().toJson(details))
                .putStringSet(TOPICS_KEY, topics)
                .apply();
    }

    public static void removeNotificationDetails(Context context, String topic) {
        SharedPreferences preferences = context.getSharedPreferences(FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE);
        Set<String> topics = new HashSet<>(preferences.getStringSet(TOPICS_KEY, Collections.emptySet()));
        topics.remove(topic);
        preferences.edit().remove(DETAILS_PREFIX + topic).putStringSet(TOPICS_KEY, topics).apply();
    }

    @Nullable
    public static NotificationDetails extractNotificationDetails(Context context, @Nullable String topic, @Nullable String payload) {
        SharedPreferences preferences = context.getSharedPreferences(FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE);
        if (topic != null) return decode(preferences.getString(DETAILS_PREFIX + topic, ""));
        Set<String> topics = preferences.getStringSet(TOPICS_KEY, Collections.emptySet());
        NotificationDetails only = null;
        for (String configuredTopic : topics) {
            NotificationDetails details = decode(preferences.getString(DETAILS_PREFIX + configuredTopic, ""));
            if (details == null) continue;
            if (payload != null && (payload.equals(details.payload) || payload.equals(details.channelId))) return details;
            only = details;
        }
        if (payload == null && topics.size() == 1) return only;
        // A token-targeted message must name its topic/payload when two channels are configured.
        if (!topics.isEmpty()) return null;
        return extractNotificationDetails(context);
    }

    @Nullable
    private static NotificationDetails decode(@Nullable String json) {
        if (json == null || json.isEmpty()) return null;
        try {
            NotificationDetails details = FlutterLocalNotificationsPlugin.buildGson().fromJson(json, NotificationDetails.class);
            if (details != null && details.styleInformation instanceof BeautyStyleInformation) {
                ((BeautyStyleInformation) details.styleInformation).normalizeTemplate();
            }
            return details;
        } catch (RuntimeException ignored) {
            return null;
        }
    }

    public static void setMessageReceivedNum(final Context context, @NonNull final String payload, int num) {
        if (context == null) return;
        SharedPreferences sharedPreferences = context.getSharedPreferences(FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = sharedPreferences.edit();
        editor.putInt("message_received_num" + payload, num);
        editor.apply();
    }

    public static int getMessageReceivedNum(final Context context, @NonNull final String payload) {
        if (context == null) return 0;
        SharedPreferences sharedPreferences = context.getSharedPreferences(FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE);
        return sharedPreferences.getInt("message_received_num" + payload, 0);
    }

    public static void saveNotificationDetails(Context context, NotificationDetails details) {
        SharedPreferences sharedPreferences = context.getSharedPreferences(FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = sharedPreferences.edit();
        Gson gson = FlutterLocalNotificationsPlugin.buildGson();
        editor.putString("fcmNotificationDetails", gson.toJson(details));
        editor.apply();
    }

    public static NotificationDetails extractNotificationDetails(Context context) {
        SharedPreferences sharedPreferences = context.getSharedPreferences(FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE);
        String detailsJson = sharedPreferences.getString("fcmNotificationDetails", "");
        return decode(detailsJson);
    }
}
