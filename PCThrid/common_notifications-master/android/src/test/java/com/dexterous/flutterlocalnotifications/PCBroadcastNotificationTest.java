package com.dexterous.flutterlocalnotifications;

import static org.junit.Assert.*;

import android.content.Context;
import android.content.Intent;
import androidx.test.core.app.ApplicationProvider;
import com.dexterous.flutterlocalnotifications.broadcast.BroadcastNotificationReceiver;
import com.dexterous.flutterlocalnotifications.broadcast.FlutterBroadcastNotificationPlugin;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.dexterous.flutterlocalnotifications.models.styles.BeautyStyleInformation;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.lang.reflect.Field;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 28)
public class PCBroadcastNotificationTest {
  private Context context;
  private FlutterLocalNotificationsPlugin plugin;

  @Before public void setUp() throws Exception {
    context = ApplicationProvider.getApplicationContext();
    BroadcastNotificationReceiver.removeAll(context);
    context.getSharedPreferences(FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE).edit().clear().commit();
    plugin = new FlutterLocalNotificationsPlugin();
    Field field = FlutterLocalNotificationsPlugin.class.getDeclaredField("applicationContext");
    field.setAccessible(true);
    field.set(plugin, context);
  }

  @After public void tearDown() { BroadcastNotificationReceiver.removeAll(context); }

  private Map<String, String> copy(String title, String body) {
    Map<String, String> value = new HashMap<>();
    value.put("title", title);
    value.put("body", body);
    return value;
  }

  private Map<String, Object> arguments(String action) {
    Map<String, Object> style = new HashMap<>();
    style.put("title", "Registration title");
    style.put("body", "Registration body");
    style.put("button", "Withdraw");
    style.put("image", "");
    style.put("appIcon", "pc_notice_app_icon");
    style.put("template", "goal");
    style.put("htmlFormatTitle", false);
    style.put("htmlFormatContent", false);
    Map<String, Object> platform = new HashMap<>();
    platform.put("style", 6);
    platform.put("styleInformation", style);
    platform.put("channelId", "fixed_one");
    platform.put("channelName", "Fixed reminder one");
    platform.put("channelAction", 0);
    platform.put("icon", "pc_notification_small");
    platform.put("importance", 4);
    platform.put("priority", 1);
    Map<String, Object> arguments = new HashMap<>();
    arguments.put("id", 2829);
    arguments.put("title", "Registration title");
    arguments.put("body", "Registration body");
    arguments.put("payload", "screenoff");
    arguments.put("interval", 30);
    arguments.put("broadcast", action);
    arguments.put("platformSpecifics", platform);
    arguments.put("randomMessages", Arrays.asList(copy("Pool title", "Pool body")));
    return arguments;
  }

  private void call(String method, Map<String, Object> arguments) {
    plugin.onMethodCall(new MethodCall(method, arguments), new MethodChannel.Result() {
      @Override public void success(Object value) {}
      @Override public void error(String code, String message, Object details) { fail(code + ": " + message); }
      @Override public void notImplemented() { fail("Not implemented: " + method); }
    });
  }

  @Test public void replacingSameIdRemovesOldActionAndCancelRemovesCurrentReceiverState() {
    call("showBroadcastNotification", arguments(Intent.ACTION_USER_PRESENT));
    assertNotNull(FlutterBroadcastNotificationPlugin.extractNotificationDetails(context, Intent.ACTION_USER_PRESENT));
    call("showBroadcastNotification", arguments(Intent.ACTION_SCREEN_OFF));
    assertNull(FlutterBroadcastNotificationPlugin.extractNotificationDetails(context, Intent.ACTION_USER_PRESENT));
    assertNotNull(FlutterBroadcastNotificationPlugin.extractNotificationDetails(context, Intent.ACTION_SCREEN_OFF));
    Map<String, Object> cancel = new HashMap<>();
    cancel.put("id", 2829);
    call("cancel", cancel);
    assertNull(FlutterBroadcastNotificationPlugin.extractNotificationDetails(context, Intent.ACTION_SCREEN_OFF));
    assertEquals(-1, FlutterBroadcastNotificationPlugin.extractInterval(context, Intent.ACTION_SCREEN_OFF));
    assertFalse(context.getSharedPreferences(FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE)
        .contains("broadcastNotificationRandomMessages" + Intent.ACTION_SCREEN_OFF.hashCode()));
  }

  @Test public void deliveryReadsLatestRandomPoolAndUpdatesBothSystemAndBeautyCopy() {
    call("showBroadcastNotification", arguments(Intent.ACTION_SCREEN_OFF));
    NotificationDetails details = FlutterBroadcastNotificationPlugin.extractNotificationDetails(context, Intent.ACTION_SCREEN_OFF);
    FlutterBroadcastNotificationPlugin.applyRandomMessage(context, Intent.ACTION_SCREEN_OFF, details);
    assertEquals("Pool title", details.title);
    assertEquals("Pool body", ((BeautyStyleInformation) details.styleInformation).body);
    FlutterBroadcastNotificationPlugin.saveRandomMessages(context, Intent.ACTION_SCREEN_OFF, Arrays.asList(copy("New title", "New body")));
    NotificationDetails next = FlutterBroadcastNotificationPlugin.extractNotificationDetails(context, Intent.ACTION_SCREEN_OFF);
    FlutterBroadcastNotificationPlugin.applyRandomMessage(context, Intent.ACTION_SCREEN_OFF, next);
    assertEquals("New title", ((BeautyStyleInformation) next.styleInformation).title);
    assertEquals("New body", next.body);
  }
}
