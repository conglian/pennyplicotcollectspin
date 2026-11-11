package com.dexterous.flutterlocalnotifications;

import android.app.Service;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Intent;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.util.Log;

import androidx.core.app.NotificationManagerCompat;

import com.dexterous.flutterlocalnotifications.models.NotificationDetails;

public class ForegroundService extends Service {
    static boolean alive = false;
    static final long REFRESH_INTERVAL_MILLIS = 15 * 60 * 1000L;

    private final Handler refreshHandler = new Handler(Looper.getMainLooper());
    private boolean refreshScheduled = false;
    private boolean stopping = false;
    private long notificationVersion = 0;
    private final Runnable refreshNotification = new Runnable() {
        @Override
        public void run() {
            refreshScheduled = false;
            if (!stopping && updateFromStoredDetails()) scheduleRefresh();
        }
    };

    @Override
    public void onCreate() {
        super.onCreate();
        alive = true;
    }

    @Override
    public void onDestroy() {
        cancelRefresh();
        stopping = true;
        notificationVersion++;
        stopForeground(true);
        super.onDestroy();
        alive = false;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // Flutter 余额变动会立即再次 start 服务；只更新同一条通知，不能推迟原来的周期。
        if (!stopping && updateFromStoredDetails()) scheduleRefresh();
        return START_NOT_STICKY;
    }

    private void scheduleRefresh() {
        if (stopping || refreshScheduled) return;
        refreshScheduled = true;
        refreshHandler.postDelayed(refreshNotification, REFRESH_INTERVAL_MILLIS);
    }

    private void cancelRefresh() {
        refreshHandler.removeCallbacks(refreshNotification);
        refreshScheduled = false;
    }

    private void stopServiceAndRefresh() {
        stopping = true;
        notificationVersion++;
        cancelRefresh();
        stopForeground(true);
        stopSelf();
    }

    private boolean notificationsAllowed(NotificationDetails details) {
        if (!NotificationManagerCompat.from(this).areNotificationsEnabled()) return false;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationManager manager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
            NotificationChannel channel = manager.getNotificationChannel(details.channelId);
            if (channel != null && channel.getImportance() == NotificationManager.IMPORTANCE_NONE) {
                return false;
            }
        }
        return true;
    }

    private boolean updateFromStoredDetails() {
        try {
            // 每次从 FlutterForePlugin 读取最新文案及缓存余额，不持有启动时的旧快照。
            final NotificationDetails notificationData = FlutterForePlugin.extractNotificationDetails(getApplicationContext());
            if (notificationData == null || notificationData.id == 0 || !notificationsAllowed(notificationData)) {
                stopServiceAndRefresh();
                return false;
            }
            final long version = ++notificationVersion;
            FlutterLocalNotificationsPlugin.createNotification(
                getApplicationContext(), notificationData, notification -> {
                    // 下载远程图片等异步构建不能覆盖较新的余额或让已销毁服务复活。
                    if (stopping || version != notificationVersion) return;
                    if (!notificationsAllowed(notificationData)) {
                        stopServiceAndRefresh();
                        return;
                    }
                    try {
                        startForeground(notificationData.id, notification);
                        // 初次、余额更新、15分钟刷新都是真正分发；每次只记录这里一次。
                        PennyNotificationAnalytics.recordForegroundShown(
                                getApplicationContext(), notificationData);
                    } catch (Throwable e) {
                        Log.e("ForegroundService", "startForeground ex", e);
                        stopServiceAndRefresh();
                    }
                });
            return !stopping;
        } catch (Throwable error) {
            Log.e("ForegroundService", "refresh notification ex", error);
            stopServiceAndRefresh();
            return false;
        }
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
