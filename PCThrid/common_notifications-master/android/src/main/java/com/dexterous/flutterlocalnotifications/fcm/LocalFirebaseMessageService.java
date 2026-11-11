package com.dexterous.flutterlocalnotifications.fcm;

import android.annotation.SuppressLint;
import android.content.Context;
import android.text.TextUtils;
import android.util.Log;

import androidx.annotation.Keep;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.app.NotificationManagerCompat;

import com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.dexterous.flutterlocalnotifications.models.NotificationStyle;
import com.dexterous.flutterlocalnotifications.models.styles.BeautyStyleInformation;
import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

import java.util.Map;

@SuppressLint("MissingFirebaseInstanceTokenRefresh")
@Keep
public class LocalFirebaseMessageService extends FirebaseMessagingService {
    private static final String TAG = "PCFirebaseNotifications";

    @Override
    public void onMessageReceived(@NonNull RemoteMessage remoteMessage) {
        super.onMessageReceived(remoteMessage);
        try {
            final Context context = getApplicationContext();
            if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return;
            NotificationDetails notificationDetails = buildNotificationDetails(context, remoteMessage);
            if (notificationDetails == null) return;
            FlutterLocalNotificationsPlugin.showNotification(context, notificationDetails);
        } catch (RuntimeException error) {
            Log.e(TAG, "Could not display a received message", error);
        }
    }

    @Nullable
    static NotificationDetails buildNotificationDetails(Context context, RemoteMessage remoteMessage) {
        final Map<String, String> data = remoteMessage.getData();
        String from = remoteMessage.getFrom();
        String topic = FlutterFCMPlugin.normalizeTopic(from != null && from.startsWith("/topics/") ? from : data.get("topic"));
        String selector = firstValue(data.get("payload"), data.get("channelId"));
        NotificationDetails details = FlutterFCMPlugin.extractNotificationDetails(context, topic, selector);
        if (details == null) {
            Log.w(TAG, "No configured FCM channel matched the received message");
            return null;
        }
        RemoteMessage.Notification notification = remoteMessage.getNotification();
        // FCM copy belongs to the server; never substitute a local motivation message.
        details.title = firstValue(data.get("title"), notification == null ? null : notification.getTitle());
        details.body = firstValue(data.get("body"), notification == null ? null : notification.getBody());
        if (TextUtils.isEmpty(details.title) && TextUtils.isEmpty(details.body)) return null;
        if (TextUtils.isEmpty(details.payload)) details.payload = firstValue(selector, "fcm");
        String id = data.get("id");
        try {
            details.id = Integer.parseInt(id);
        } catch (NumberFormatException ignored) {
            String identity = firstValue(remoteMessage.getMessageId(), String.valueOf(details.channelId) + details.title + details.body);
            details.id = identity.hashCode() & Integer.MAX_VALUE;
        }
        String image = firstValue(data.get("imageUrl"), data.get("image"),
                notification == null || notification.getImageUrl() == null ? null : notification.getImageUrl().toString());
        if (details.style == NotificationStyle.Beauty && details.styleInformation instanceof BeautyStyleInformation) {
            BeautyStyleInformation style = (BeautyStyleInformation) details.styleInformation;
            style.title = details.title;
            style.body = details.body;
            if (image != null) style.image = image;
            if (!TextUtils.isEmpty(data.get("amount"))) style.amount = data.get("amount");
        }
        return details;
    }

    @Nullable
    private static String firstValue(String... values) {
        for (String value : values) if (!TextUtils.isEmpty(value)) return value;
        return null;
    }
}
