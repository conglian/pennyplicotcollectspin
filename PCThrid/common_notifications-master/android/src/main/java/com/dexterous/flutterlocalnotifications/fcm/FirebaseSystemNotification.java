package com.dexterous.flutterlocalnotifications.fcm;

import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.os.SystemClock;
import android.service.notification.StatusBarNotification;
import android.text.TextUtils;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.core.app.NotificationManagerCompat;

import com.dexterous.flutterlocalnotifications.PennyMediaNotification;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.google.firebase.messaging.RemoteMessage;

import java.util.HashMap;
import java.util.Map;

/** Confirms a notification posted by Firebase before dispatching its T7 companion. */
final class FirebaseSystemNotification {
    private static final String TAG = "PCFirebaseNotifications";
    private static final String SDK_TAG_PREFIX = "FCM-Notification:";

    private final Context context;
    private final NotificationManager manager;
    private final NotificationDetails details;
    private final String tag;
    private final Map<String, Long> previousPosts = new HashMap<>();

    private FirebaseSystemNotification(Context context, NotificationDetails details, String tag) {
        this.context = context;
        this.manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        this.details = details;
        this.tag = tag;
        for (StatusBarNotification item : manager.getActiveNotifications()) {
            if (matches(item)) previousPosts.put(item.getKey(), item.getPostTime());
        }
    }

    @Nullable
    static FirebaseSystemNotification watch(Context context, Intent intent) {
        try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M || intent == null
                    || !NotificationManagerCompat.from(context).areNotificationsEnabled()) return null;
            String action = intent.getAction();
            if (!"com.google.android.c2dm.intent.RECEIVE".equals(action)
                    && !"com.google.firebase.messaging.RECEIVE_DIRECT_BOOT".equals(action)) return null;
            Bundle extras = intent.getExtras();
            if (extras == null) return null;
            RemoteMessage message = new RemoteMessage(extras);
            RemoteMessage.Notification notification = message.getNotification();
            if (notification == null) return null;
            NotificationDetails details = LocalFirebaseMessageService.buildNotificationDetails(context, message, true);
            if (details == null || !("fcm2".equals(details.payload) || "fcm1".equals(details.payload))) return null;
            return new FirebaseSystemNotification(context, details, notification.getTag());
        } catch (RuntimeException error) {
            Log.w(TAG, "Could not observe a system FCM notification", error);
            return null;
        }
    }

    void showCompanion() {
        try {
            // NotificationManager enqueues asynchronously. Give its worker a short window
            // to publish the notification before deciding whether there was a system post.
            for (int attempt = 0; attempt < 4; attempt++) {
                if (attempt > 0) SystemClock.sleep(40);
                for (StatusBarNotification item : manager.getActiveNotifications()) {
                    if (!matches(item) || Long.valueOf(item.getPostTime()).equals(previousPosts.get(item.getKey()))) {
                        continue;
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        details.channelId = item.getNotification().getChannelId();
                    }
                    PennyMediaNotification.showForSystemFcm(context, details);
                    return;
                }
            }
        } catch (RuntimeException error) {
            Log.w(TAG, "Could not check the system FCM notification", error);
        }
    }

    private boolean matches(StatusBarNotification item) {
        if (item.getId() != 0 || item.getTag() == null) return false;
        return TextUtils.isEmpty(tag) ? item.getTag().startsWith(SDK_TAG_PREFIX) : tag.equals(item.getTag());
    }
}
