package com.dexterous.flutterlocalnotifications;

import static org.junit.Assert.*;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.os.Looper;
import android.view.View;
import android.widget.FrameLayout;
import androidx.test.core.app.ApplicationProvider;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import java.util.HashMap;
import java.util.Map;
import java.time.Duration;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.Shadows;
import org.robolectric.android.controller.ServiceController;
import org.robolectric.annotation.Config;
import org.robolectric.annotation.LooperMode;
import org.robolectric.shadows.ShadowService;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 28)
@LooperMode(LooperMode.Mode.PAUSED)
public class PCForegroundServiceTest {
  private NotificationDetails details(String amount) {
    Map<String, Object> style = new HashMap<>();
    style.put("title", "My Cash Account");
    style.put("body", "Your piggy bank balance is " + amount);
    style.put("image", "");
    style.put("button", "Withdraw");
    style.put("appIcon", "pc_notice_account_icon");
    style.put("template", "account");
    style.put("amount", amount);
    style.put("htmlFormatTitle", false);
    style.put("htmlFormatContent", false);
    Map<String, Object> platform = new HashMap<>();
    platform.put("style", 6);
    platform.put("styleInformation", style);
    platform.put("channelId", "pc_balance_service_v1");
    platform.put("channelName", "Piggy Bank Balance");
    platform.put("channelAction", 0);
    platform.put("importance", 2);
    platform.put("priority", -1);
    platform.put("icon", "pc_notification_small");
    platform.put("ongoing", true);
    platform.put("autoCancel", false);
    platform.put("onlyAlertOnce", true);
    platform.put("playSound", false);
    platform.put("enableVibration", false);
    Map<String, Object> arguments = new HashMap<>();
    arguments.put("id", 17759);
    arguments.put("title", "My Cash Account");
    arguments.put("body", "Balance " + amount);
    arguments.put("payload", "{\"pcNotice\":1,\"action\":\"withdraw\"}");
    arguments.put("platformSpecifics", platform);
    return NotificationDetails.from(arguments);
  }

  @Test public void serviceStartsWithBothLayoutsAndUpdatesSameNotificationThenCleansUp() {
    Context context = ApplicationProvider.getApplicationContext();
    FlutterForePlugin.saveNotificationDetails(context, details("$59"));
    ServiceController<ForegroundService> controller = Robolectric.buildService(ForegroundService.class).create();
    ForegroundService service = controller.get();
    ShadowService shadow = Shadows.shadowOf(service);
    try {
      assertEquals(Service.START_NOT_STICKY, service.onStartCommand(new Intent(), 0, 1));
      assertEquals(17759, shadow.getLastForegroundNotificationId());
      Notification first = shadow.getLastForegroundNotification();
      assertNotNull(first);
      assertTrue((first.flags & Notification.FLAG_ONGOING_EVENT) != 0);
      assertFalse((first.flags & Notification.FLAG_AUTO_CANCEL) != 0);
      View small = first.contentView.apply(context, new FrameLayout(context));
      View big = first.bigContentView.apply(context, new FrameLayout(context));
      assertEquals("$59", small.findViewById(R.id.pc_notice_amount).getContentDescription());
      assertEquals("$59", big.findViewById(R.id.pc_notice_amount).getContentDescription());
      FlutterForePlugin.saveNotificationDetails(context, details("$106.25"));
      service.onStartCommand(new Intent(), 0, 2);
      Notification updated = shadow.getLastForegroundNotification();
      assertEquals(17759, shadow.getLastForegroundNotificationId());
      View current = updated.contentView.apply(context, new FrameLayout(context));
      assertEquals("$106.25", current.findViewById(R.id.pc_notice_amount).getContentDescription());
      assertEquals(1, Shadows.shadowOf((NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE)).size());
    } finally {
      controller.destroy();
    }
    assertTrue(shadow.isForegroundStopped());
    assertTrue(shadow.getNotificationShouldRemoved());
  }

  @Test public void missingStoredDetailsStopsWithoutStartingAnEmptyForegroundService() {
    Context context = ApplicationProvider.getApplicationContext();
    context.getSharedPreferences(FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE)
        .edit().remove("foreNotificationDetails").commit();
    ServiceController<ForegroundService> controller = Robolectric.buildService(ForegroundService.class).create();
    ForegroundService service = controller.get();
    try {
      assertEquals(Service.START_NOT_STICKY, service.onStartCommand(new Intent(), 0, 1));
      assertTrue(Shadows.shadowOf(service).isStoppedBySelf());
      assertNull(Shadows.shadowOf(service).getLastForegroundNotification());
    } finally {
      controller.destroy();
    }
  }

  @Test public void refreshReadsLatestStoredDetailsEveryFifteenMinutesWithSameId() {
    Context context = ApplicationProvider.getApplicationContext();
    NotificationDetails initial = details("$59");
    initial.id = 1200;
    FlutterForePlugin.saveNotificationDetails(context, initial);
    ServiceController<ForegroundService> controller = Robolectric.buildService(ForegroundService.class).create();
    ForegroundService service = controller.get();
    ShadowService shadow = Shadows.shadowOf(service);
    try {
      service.onStartCommand(new Intent(), 0, 1);
      Notification first = shadow.getLastForegroundNotification();
      NotificationDetails latest = details("$70");
      latest.id = 1200;
      FlutterForePlugin.saveNotificationDetails(context, latest);
      Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMinutes(14));
      assertSame(first, shadow.getLastForegroundNotification());
      Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMinutes(1));
      Notification refreshed = shadow.getLastForegroundNotification();
      assertNotSame(first, refreshed);
      assertEquals(1200, shadow.getLastForegroundNotificationId());
      assertEquals("$70", amount(context, refreshed));
      Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMinutes(15));
      assertNotSame(refreshed, shadow.getLastForegroundNotification());
      assertEquals(1, Shadows.shadowOf((NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE)).size());
    } finally {
      controller.destroy();
    }
  }

  @Test public void immediateBalanceUpdateDoesNotPostponeTheOriginalFifteenMinuteTick() {
    Context context = ApplicationProvider.getApplicationContext();
    FlutterForePlugin.saveNotificationDetails(context, details("$59"));
    ServiceController<ForegroundService> controller = Robolectric.buildService(ForegroundService.class).create();
    ForegroundService service = controller.get();
    ShadowService shadow = Shadows.shadowOf(service);
    try {
      service.onStartCommand(new Intent(), 0, 1);
      Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMinutes(10));
      FlutterForePlugin.saveNotificationDetails(context, details("$106.25"));
      service.onStartCommand(new Intent(), 0, 2);
      Notification balanceUpdate = shadow.getLastForegroundNotification();
      assertEquals("$106.25", amount(context, balanceUpdate));
      FlutterForePlugin.saveNotificationDetails(context, details("$107"));
      Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMinutes(5));
      Notification scheduledUpdate = shadow.getLastForegroundNotification();
      assertNotSame(balanceUpdate, scheduledUpdate);
      assertEquals("$107", amount(context, scheduledUpdate));
      assertEquals(17759, shadow.getLastForegroundNotificationId());
      Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMinutes(10));
      assertSame(scheduledUpdate, shadow.getLastForegroundNotification());
    } finally {
      controller.destroy();
    }
  }

  @Test public void destructionCancelsTickerAndNeverRecreatesNotification() {
    Context context = ApplicationProvider.getApplicationContext();
    FlutterForePlugin.saveNotificationDetails(context, details("$59"));
    ServiceController<ForegroundService> controller = Robolectric.buildService(ForegroundService.class).create();
    ForegroundService service = controller.get();
    ShadowService shadow = Shadows.shadowOf(service);
    service.onStartCommand(new Intent(), 0, 1);
    assertNotNull(shadow.getLastForegroundNotification());
    controller.destroy();
    FlutterForePlugin.saveNotificationDetails(context, details("$99"));
    Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMinutes(45));
    assertNull(shadow.getLastForegroundNotification());
    assertTrue(shadow.isForegroundStopped());
    assertTrue(shadow.getNotificationShouldRemoved());
    assertEquals(0, Shadows.shadowOf((NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE)).size());
  }

  @Test public void revokedPermissionStopsTickerAndServiceWithoutRefreshingAgain() {
    Context context = ApplicationProvider.getApplicationContext();
    NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
    FlutterForePlugin.saveNotificationDetails(context, details("$59"));
    ServiceController<ForegroundService> controller = Robolectric.buildService(ForegroundService.class).create();
    ForegroundService service = controller.get();
    ShadowService shadow = Shadows.shadowOf(service);
    try {
      service.onStartCommand(new Intent(), 0, 1);
      assertNotNull(shadow.getLastForegroundNotification());
      Shadows.shadowOf(manager).setNotificationsEnabled(false);
      Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMinutes(15));
      assertTrue(shadow.isStoppedBySelf());
      assertTrue(shadow.isForegroundStopped());
      Shadows.shadowOf(manager).setNotificationsEnabled(true);
      FlutterForePlugin.saveNotificationDetails(context, details("$200"));
      Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMinutes(30));
      assertNull(shadow.getLastForegroundNotification());
      assertEquals(0, Shadows.shadowOf(manager).size());
    } finally {
      Shadows.shadowOf(manager).setNotificationsEnabled(true);
      controller.destroy();
    }
  }

  private String amount(Context context, Notification notification) {
    View content = notification.contentView.apply(context, new FrameLayout(context));
    return content.findViewById(R.id.pc_notice_amount).getContentDescription().toString();
  }
}
