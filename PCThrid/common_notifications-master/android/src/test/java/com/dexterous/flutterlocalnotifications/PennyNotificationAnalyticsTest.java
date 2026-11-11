package com.dexterous.flutterlocalnotifications;

import static org.junit.Assert.*;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.os.Looper;
import androidx.test.core.app.ApplicationProvider;
import com.dexterous.flutterlocalnotifications.broadcast.BroadcastNotificationReceiver;
import com.dexterous.flutterlocalnotifications.broadcast.FlutterBroadcastNotificationPlugin;
import com.dexterous.flutterlocalnotifications.models.NotificationChannelAction;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.dexterous.flutterlocalnotifications.models.NotificationStyle;
import com.dexterous.flutterlocalnotifications.models.styles.DefaultStyleInformation;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.lang.reflect.Field;
import java.time.Duration;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.Shadows;
import org.robolectric.android.controller.ServiceController;
import org.robolectric.annotation.Config;
import org.robolectric.annotation.LooperMode;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 28)
@LooperMode(LooperMode.Mode.PAUSED)
public class PennyNotificationAnalyticsTest {
  private Context context;
  private NotificationManager manager;
  private FlutterLocalNotificationsPlugin plugin;

  @Before public void setUp() throws Exception {
    context = ApplicationProvider.getApplicationContext();
    context.getSharedPreferences(FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE)
        .edit().clear().commit();
    manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
    manager.cancelAll();
    Shadows.shadowOf(manager).setNotificationsEnabled(true);
    plugin = new FlutterLocalNotificationsPlugin();
    Field field = FlutterLocalNotificationsPlugin.class.getDeclaredField("applicationContext");
    field.setAccessible(true);
    field.set(plugin, context);
  }

  private NotificationDetails details(int id, String payload) {
    NotificationDetails details = new NotificationDetails();
    details.id = id;
    details.title = "Private title is never included in analytics";
    details.body = "Private account is never included in analytics";
    details.payload = payload;
    details.icon = "pc_notification_small";
    details.channelId = "analytics_test_channel";
    details.channelName = "Analytics test";
    details.channelAction = NotificationChannelAction.CreateIfNotExists;
    details.importance = NotificationManager.IMPORTANCE_DEFAULT;
    details.priority = 0;
    details.style = NotificationStyle.Default;
    details.styleInformation = new DefaultStyleInformation(false, false);
    return details;
  }

  private Object call(String method, Map<String, Object> arguments) {
    final Object[] result = {null};
    plugin.onMethodCall(new MethodCall(method, arguments), new MethodChannel.Result() {
      @Override public void success(Object value) { result[0] = value; }
      @Override public void error(String code, String message, Object data) { fail(code + ": " + message); }
      @Override public void notImplemented() { fail("Missing method: " + method); }
    });
    return result[0];
  }

  @Test public void realDispatchQueuesOnlyTypeAndUuidAndCanBeReadAfterPluginRecreation() throws Exception {
    assertTrue(PennyNotificationAnalytics.getPending(context).isEmpty());
    FlutterLocalNotificationsPlugin.showNotification(context, details(1, "Media1"));
    FlutterLocalNotificationsPlugin.showNotification(context, details(2, "fcm2"));
    FlutterLocalNotificationsPlugin.showNotification(context, details(3, "noti2"));
    assertEquals(3, Shadows.shadowOf(manager).size());
    List<Map<String, String>> pending = PennyNotificationAnalytics.getPending(context);
    assertEquals(2, pending.size());
    assertEquals("local", pending.get(0).get("type"));
    assertEquals("local", pending.get(1).get("type"));
    assertNotEquals(pending.get(0).get("eventId"), pending.get(1).get("eventId"));
    assertEquals(new HashSet<>(Arrays.asList("eventId", "type")), pending.get(0).keySet());
    assertEquals(36, pending.get(0).get("eventId").length());
    plugin = new FlutterLocalNotificationsPlugin();
    Field field = FlutterLocalNotificationsPlugin.class.getDeclaredField("applicationContext");
    field.setAccessible(true);
    field.set(plugin, context);
    assertEquals(pending, call("getPendingNotificationAnalytics", null));
  }

  @Test public void acknowledgmentRemovesOnlyItsSnapshotAndPreservesNewDeliveries() {
    FlutterLocalNotificationsPlugin.showNotification(context, details(1, "noti1"));
    String firstId = PennyNotificationAnalytics.getPending(context).get(0).get("eventId");
    FlutterLocalNotificationsPlugin.showNotification(context, details(2, "Media2"));
    Map<String, Object> arguments = new HashMap<>();
    arguments.put("eventIds", Collections.singletonList(firstId));
    assertEquals(true, call("ackNotificationAnalytics", arguments));
    List<Map<String, String>> remaining = PennyNotificationAnalytics.getPending(context);
    assertEquals(1, remaining.size());
    assertEquals("local", remaining.get(0).get("type"));
    assertEquals(true, call("ackNotificationAnalytics", arguments));
    assertEquals(remaining, PennyNotificationAnalytics.getPending(context));
  }

  @Test public void permissionDeniedAndBlockedChannelNeverQueueAnExposure() {
    Shadows.shadowOf(manager).setNotificationsEnabled(false);
    FlutterLocalNotificationsPlugin.showNotification(context, details(1, "noti1"));
    assertTrue(PennyNotificationAnalytics.getPending(context).isEmpty());
    Shadows.shadowOf(manager).setNotificationsEnabled(true);
    NotificationDetails blocked = details(2, "noti1");
    blocked.channelId = "blocked_analytics";
    manager.createNotificationChannel(new NotificationChannel(
        blocked.channelId, "Blocked", NotificationManager.IMPORTANCE_NONE));
    FlutterLocalNotificationsPlugin.showNotification(context, blocked);
    assertTrue(PennyNotificationAnalytics.getPending(context).isEmpty());
  }

  @Test public void failedConstructionAndRegistrationAreNotNotificationExposures() {
    NotificationDetails stored = details(1, "noti1");
    FlutterForePlugin.saveNotificationDetails(context, stored);
    FlutterBroadcastNotificationPlugin.saveNotificationDetails(context, stored, Intent.ACTION_SCREEN_OFF);
    assertTrue(PennyNotificationAnalytics.getPending(context).isEmpty());
    NotificationDetails invalid = details(2, "fcm1");
    invalid.styleInformation = null;
    try {
      FlutterLocalNotificationsPlugin.showNotification(context, invalid);
      fail("Invalid notification construction must fail");
    } catch (NullPointerException expected) {}
    assertEquals(0, Shadows.shadowOf(manager).size());
    assertTrue(PennyNotificationAnalytics.getPending(context).isEmpty());
  }

  @Test public void broadcastDeliveryRecordsUnlockOnceAndHonorsItsExistingInterval() {
    String action = Intent.ACTION_SCREEN_OFF;
    FlutterBroadcastNotificationPlugin.saveNotificationDetails(context, details(1, "noti1"), action);
    FlutterBroadcastNotificationPlugin.saveInterval(context, 30, action);
    BroadcastNotificationReceiver receiver = new BroadcastNotificationReceiver();
    receiver.broadcast = action;
    receiver.onReceive(context, new Intent(action));
    receiver.onReceive(context, new Intent(action));
    List<Map<String, String>> pending = PennyNotificationAnalytics.getPending(context);
    assertEquals(1, pending.size());
    assertEquals("unlock", pending.get(0).get("type"));
    for (String payload : Arrays.asList("turnon", "turnoff", "unlock", "screenon", "screenoff")) {
      assertEquals("unlock", PennyNotificationAnalytics.typeFor(payload, null));
    }
    assertEquals("unlock", PennyNotificationAnalytics.typeFor("noti1", Intent.ACTION_USER_PRESENT));
  }

  @Test public void foregroundInitialBalanceAndPeriodicDispatchesEachCountOnce() {
    NotificationDetails details = details(1200, "foreground");
    FlutterForePlugin.saveNotificationDetails(context, details);
    ServiceController<ForegroundService> controller = Robolectric.buildService(ForegroundService.class).create();
    try {
      controller.get().onStartCommand(new Intent(), 0, 1);
      assertEquals(1, PennyNotificationAnalytics.getPending(context).size());
      controller.get().onStartCommand(new Intent(), 0, 2);
      assertEquals(2, PennyNotificationAnalytics.getPending(context).size());
      Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMinutes(15));
      assertEquals(3, PennyNotificationAnalytics.getPending(context).size());
      Shadows.shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMinutes(15));
      List<Map<String, String>> pending = PennyNotificationAnalytics.getPending(context);
      assertEquals(4, pending.size());
      Set<String> ids = new HashSet<>();
      for (Map<String, String> event : pending) {
        assertEquals("local", event.get("type"));
        assertTrue(ids.add(event.get("eventId")));
      }
    } finally {
      controller.destroy();
    }
  }

  @Test public void legacyScheduledNotificationDispatchCountsOnceAndHonorsPermission() {
    String channel = "legacy_analytics";
    manager.createNotificationChannel(new NotificationChannel(
        channel, "Legacy", NotificationManager.IMPORTANCE_DEFAULT));
    Notification notification = new Notification.Builder(context, channel)
        .setSmallIcon(android.R.drawable.ic_dialog_info).setContentTitle("Legacy").build();
    Intent intent = new Intent().putExtra("notification_id", 19)
        .putExtra("notification", notification);
    ScheduledNotificationReceiver receiver = new ScheduledNotificationReceiver();
    receiver.onReceive(context, intent);
    assertEquals(1, PennyNotificationAnalytics.getPending(context).size());
    Shadows.shadowOf(manager).setNotificationsEnabled(false);
    receiver.onReceive(context, intent);
    assertEquals(1, PennyNotificationAnalytics.getPending(context).size());
  }

  @Test public void boundedQueueKeepsLatestEventsAndRecoversFromMalformedStorage() {
    context.getSharedPreferences(FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE)
        .edit().putString(PennyNotificationAnalytics.QUEUE_KEY, "broken").commit();
    assertTrue(PennyNotificationAnalytics.getPending(context).isEmpty());
    String firstId = null;
    for (int index = 0; index <= PennyNotificationAnalytics.MAX_PENDING; index++) {
      assertTrue(PennyNotificationAnalytics.recordShown(context, details(index + 1, "Media1"), null));
      if (index == 0) firstId = PennyNotificationAnalytics.getPending(context).get(0).get("eventId");
    }
    List<Map<String, String>> pending = PennyNotificationAnalytics.getPending(context);
    assertEquals(PennyNotificationAnalytics.MAX_PENDING, pending.size());
    for (Map<String, String> event : pending) assertNotEquals(firstId, event.get("eventId"));
  }
}
