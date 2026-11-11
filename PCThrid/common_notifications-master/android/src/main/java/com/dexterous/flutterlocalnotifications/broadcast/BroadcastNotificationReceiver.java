package com.dexterous.flutterlocalnotifications.broadcast;

import android.annotation.SuppressLint;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;

import androidx.core.app.NotificationManagerCompat;

import com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.dexterous.flutterlocalnotifications.utils.StringUtils;

import java.util.HashMap;
import java.util.Map;

public class BroadcastNotificationReceiver extends BroadcastReceiver {
    private static final Map<Integer, BroadcastNotificationReceiver> sInstances = new HashMap<>();

    public static void add(Context context, String broadcast) {
        NotificationDetails details = FlutterBroadcastNotificationPlugin.extractNotificationDetails(context, broadcast);
        if (details == null) return;
        BroadcastNotificationReceiver previous = sInstances.remove(details.id);
        if (previous != null) unregister(context, previous);
        BroadcastNotificationReceiver receiver = new BroadcastNotificationReceiver();
        receiver.broadcast = broadcast;
        IntentFilter intentFilter = new IntentFilter();
        intentFilter.addAction(broadcast);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, intentFilter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            context.registerReceiver(receiver, intentFilter);
        }
        sInstances.put(details.id, receiver);
    }

    public static void remove(Context context, int id) {
        BroadcastNotificationReceiver receiver = sInstances.remove(id);
        if (receiver != null) unregister(context, receiver);
        FlutterBroadcastNotificationPlugin.removeNotificationDetails(context, id);
    }

    private static void unregister(Context context, BroadcastNotificationReceiver receiver) {
        try {
            context.unregisterReceiver(receiver);
        } catch (IllegalArgumentException ignored) {
            // The engine may already have released this context's receiver.
        }
    }

    public static void removeAll(Context context) {
        sInstances.values().forEach(receiver -> unregister(context, receiver));
        sInstances.clear();
    }

    public String broadcast;

    @SuppressLint("UnsafeProtectedBroadcastReceiver")
    @Override
    public void onReceive(Context context, Intent intent) {
        final String broadcast = this.broadcast;
        if (StringUtils.isNullOrEmpty(broadcast)) return;
        if (!broadcast.equals(intent.getAction())) return;
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return;
        final NotificationDetails notificationDetails = FlutterBroadcastNotificationPlugin.extractNotificationDetails(context, broadcast);
        if (notificationDetails == null) return;
        final int interval = FlutterBroadcastNotificationPlugin.extractInterval(context, broadcast);
        final long when = FlutterBroadcastNotificationPlugin.extractWhen(context, broadcast);
        if (when >= 0 && (System.currentTimeMillis() - when) <= interval * 1000L) return;
        FlutterBroadcastNotificationPlugin.applyRandomMessage(context, broadcast, notificationDetails);
        FlutterBroadcastNotificationPlugin.saveWhen(context, System.currentTimeMillis(), broadcast);
        FlutterLocalNotificationsPlugin.showNotification(context, notificationDetails, intent.getAction());
    }
}
