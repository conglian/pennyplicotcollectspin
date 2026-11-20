package com.dexterous.flutterlocalnotifications;

import static org.junit.Assert.*;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.support.v4.media.session.MediaSessionCompat;
import android.service.notification.StatusBarNotification;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.TextView;

import androidx.test.core.app.ApplicationProvider;

import com.dexterous.flutterlocalnotifications.models.NotificationChannelAction;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.dexterous.flutterlocalnotifications.models.NotificationStyle;
import com.dexterous.flutterlocalnotifications.models.styles.BeautyStyleInformation;

import java.util.Arrays;
import java.util.List;
import java.util.Map;

import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.Shadows;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 28)
public class PennyMediaNotificationTest {
  private Context context;
  private NotificationManager manager;

  @Before public void setUp() {
    context = ApplicationProvider.getApplicationContext();
    context.getSharedPreferences(FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE)
        .edit().clear().commit();
    manager = context.getSystemService(NotificationManager.class);
    Shadows.shadowOf(manager).setNotificationsEnabled(true);
  }

  @Test public void hostAndMediaCardHaveIndependentAnalyticsAndMatchingRoutes() {
    FlutterLocalNotificationsPlugin.showNotification(context, details(1, "local"));
    FlutterLocalNotificationsPlugin.showNotification(context, details(2, "fcm1"));
    assertEquals(Arrays.asList("local", "media", "fcm", "media"), exposureTypes());
    Notification first = mediaNotification(0);
    Notification second = mediaNotification(1);
    assertNotNull(first);
    assertNotNull(second);
    assertEquals("android.app.Notification$DecoratedCustomViewStyle", first.extras.getString(Notification.EXTRA_TEMPLATE));
    assertMediaColors(first.contentView.apply(context, new FrameLayout(context)));
    assertMediaColors(first.bigContentView.apply(context, new FrameLayout(context)));
    assertNotEquals(first.extras.getCharSequence(Notification.EXTRA_TITLE),
        second.extras.getCharSequence(Notification.EXTRA_TITLE));
    Intent firstClick = Shadows.shadowOf(first.contentIntent).getSavedIntent();
    Intent secondClick = Shadows.shadowOf(second.contentIntent).getSavedIntent();
    assertEquals(FlutterLocalNotificationsPlugin.SELECT_NOTIFICATION, firstClick.getAction());
    assertEquals("{\"pcNotice\":1,\"type\":\"media\",\"action\":\"earn\"}", firstClick.getStringExtra("payload"));
    assertEquals("{\"pcNotice\":1,\"type\":\"media\",\"action\":\"withdraw\"}", secondClick.getStringExtra("payload"));
  }

  private void assertMediaColors(View view) {
    View card = view.findViewById(R.id.pc_notice_media_card);
    GradientDrawable surface = (GradientDrawable) card.getBackground();
    TextView title = card.findViewById(R.id.pc_notice_media_title);
    TextView body = card.findViewById(R.id.pc_notice_media_body);
    assertEquals(0xCC000000, surface.getColor().getDefaultColor());
    assertEquals(Color.WHITE, title.getCurrentTextColor());
    assertEquals(Color.WHITE, body.getCurrentTextColor());
    assertEquals("Your Piggy Bank Is Waiting", title.getText());
    assertEquals("Open PennyPilot to check your progress.", body.getText());
  }

  @Test @Config(sdk = 35)
  public void systemMediaCardsKeepIndependentSessionsAndClickTargets() {
    FlutterLocalNotificationsPlugin.showNotification(context, details(1, "local"));
    Notification first = mediaNotification(0);
    assertNotNull(first);
    assertEquals("android.app.Notification$MediaStyle", first.extras.getString(Notification.EXTRA_TEMPLATE));
    MediaSessionCompat.Token token = androidx.media.app.NotificationCompat.MediaStyle.getMediaSession(first);
    assertNotNull(token);
    assertNull(first.actions);

    FlutterLocalNotificationsPlugin.showNotification(context, details(2, "fcm1"));
    Notification second = mediaNotification(1);
    assertNotNull(second);
    MediaSessionCompat.Token secondToken = androidx.media.app.NotificationCompat.MediaStyle.getMediaSession(second);
    assertNotNull(secondToken);
    assertNotEquals(token, secondToken);
    Notification stillFirst = mediaNotification(0);
    assertEquals(token, androidx.media.app.NotificationCompat.MediaStyle.getMediaSession(stillFirst));
    assertEquals("Your Piggy Bank Is Waiting", stillFirst.extras.getCharSequence(Notification.EXTRA_TITLE));
    assertEquals("Ready For Another Round?", second.extras.getCharSequence(Notification.EXTRA_TITLE));
    assertEquals("{\"pcNotice\":1,\"type\":\"media\",\"action\":\"earn\"}",
        Shadows.shadowOf(stillFirst.contentIntent).getSavedIntent().getStringExtra("payload"));
    assertEquals("{\"pcNotice\":1,\"type\":\"media\",\"action\":\"withdraw\"}",
        Shadows.shadowOf(second.contentIntent).getSavedIntent().getStringExtra("payload"));
    assertEquals(Arrays.asList("local", "media", "fcm", "media"), exposureTypes());
    FlutterLocalNotificationsPlugin.dismissClickedNotification(
        context, Shadows.shadowOf(first.contentIntent).getSavedIntent());
    assertNull(mediaNotification(0));
    assertNotNull(activeNotification(20_000));
    assertNotNull(mediaNotification(1));
    PennyMediaNotification.cancelSource(context, 2);
    assertNull(mediaNotification(1));
  }

  @Test public void clickDismissesOnlyTheMatchingTaggedDeliveryForARepeatingSource() {
    NotificationDetails repeated = details(1, "local");
    repeated.autoCancel = true;
    repeated.tag = "reminder";
    FlutterLocalNotificationsPlugin.showNotification(context, repeated);
    FlutterLocalNotificationsPlugin.showNotification(context, repeated);

    Notification first = activeNotification(20_000);
    Notification second = activeNotification(20_001);
    assertNotNull(first);
    assertNotNull(second);
    assertNotEquals(first.contentIntent, second.contentIntent);
    Intent click = Shadows.shadowOf(first.contentIntent).getSavedIntent();
    FlutterLocalNotificationsPlugin.dismissClickedNotification(
        context, new Intent(click).addFlags(Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY));
    assertNotNull(activeNotification(20_000));

    FlutterLocalNotificationsPlugin.dismissClickedNotification(context, click);
    assertNull(activeNotification(20_000));
    assertNotNull(activeNotification(20_001));
    assertNotNull(mediaNotification(0));
    assertNotNull(mediaNotification(1));
  }

  @Test public void throttledSceneAndDisabledChannelsNeverPostCompanions() {
    NotificationDetails scene = details(1, "{\"pcNotice\":1,\"type\":\"unlock\",\"action\":\"withdraw\"}");
    FlutterLocalNotificationsPlugin.showNotification(context, scene);
    FlutterLocalNotificationsPlugin.showNotification(context, scene);
    assertEquals(Arrays.asList("unlock", "media"), exposureTypes());

    manager.createNotificationChannel(new NotificationChannel(
        "blocked_host", "Blocked host", NotificationManager.IMPORTANCE_NONE));
    NotificationDetails blocked = details(2, "local");
    blocked.channelId = "blocked_host";
    FlutterLocalNotificationsPlugin.showNotification(context, blocked);
    assertEquals(Arrays.asList("unlock", "media"), exposureTypes());

    NotificationChannel media = manager.getNotificationChannel(PennyMediaNotification.CHANNEL_ID);
    media.setImportance(NotificationManager.IMPORTANCE_NONE);
    manager.createNotificationChannel(media);
    FlutterLocalNotificationsPlugin.showNotification(context, details(3, "fcm2"));
    assertEquals(Arrays.asList("unlock", "media", "fcm"), exposureTypes());
    assertNull(mediaNotification(1));
  }

  @Test public void copiesAndSlotsCycleAndCancellationOnlyRemovesCurrentSource() {
    NotificationDetails first = details(100, "local");
    first.autoCancel = true;
    FlutterLocalNotificationsPlugin.showNotification(context, first);
    Intent oldHostClick = Shadows.shadowOf(activeNotification(20_000).contentIntent).getSavedIntent();
    Intent oldMediaClick = Shadows.shadowOf(mediaNotification(0).contentIntent).getSavedIntent();
    for (int index = 1; index <= PennyNotificationAnalytics.MAX_VISIBLE_NOTIFICATIONS; index++) {
      FlutterLocalNotificationsPlugin.showNotification(context, details(100 + index, "local"));
    }
    assertEquals(40, manager.getActiveNotifications().length);
    FlutterLocalNotificationsPlugin.dismissClickedNotification(context, oldHostClick);
    FlutterLocalNotificationsPlugin.dismissClickedNotification(context, oldMediaClick);
    assertNotNull(activeNotification(20_000));
    assertNotNull(mediaNotification(0));
    assertEquals(mediaNotification(0).extras.getCharSequence(Notification.EXTRA_TITLE),
        mediaNotification(4).extras.getCharSequence(Notification.EXTRA_TITLE));
    PennyMediaNotification.cancelSource(context, 100);
    assertNotNull(mediaNotification(0));
    PennyMediaNotification.cancelSource(context, 120);
    assertNull(mediaNotification(0));
    assertNotNull(mediaNotification(1));
  }

  @Test public void homeKeyAndBackgroundShareTheEventTypeAndThrottle() {
    FlutterLocalNotificationsPlugin.showNotification(context,
        details(1, "{\"pcNotice\":1,\"type\":\"home_key\",\"action\":\"withdraw\"}"),
        Intent.ACTION_CLOSE_SYSTEM_DIALOGS);
    FlutterLocalNotificationsPlugin.showNotification(context,
        details(2, "{\"pcNotice\":1,\"type\":\"background\",\"action\":\"withdraw\"}"));
    assertEquals(Arrays.asList("background", "media"), exposureTypes());
    assertEquals("background", PennyNotificationAnalytics.typeFor(null, Intent.ACTION_CLOSE_SYSTEM_DIALOGS));
  }

  private Notification mediaNotification(int slot) {
    return activeNotification(PennyMediaNotification.FIRST_DISPLAY_ID + slot);
  }

  private Notification activeNotification(int id) {
    for (StatusBarNotification item : manager.getActiveNotifications()) {
      if (item.getId() == id) return item.getNotification();
    }
    return null;
  }

  private List<String> exposureTypes() {
    List<String> types = new java.util.ArrayList<>();
    for (Map<String, String> event : PennyNotificationAnalytics.getPending(context)) {
      types.add(event.get("type"));
    }
    return types;
  }

  private NotificationDetails details(int id, String payload) {
    NotificationDetails details = new NotificationDetails();
    details.id = id;
    details.title = "Host title";
    details.body = "Host body";
    details.payload = payload;
    details.icon = "pc_notification_small";
    details.channelId = "penny_test";
    details.channelName = "Penny test";
    details.channelAction = NotificationChannelAction.CreateIfNotExists;
    details.importance = NotificationManager.IMPORTANCE_DEFAULT;
    details.priority = 0;
    details.style = NotificationStyle.Beauty;
    BeautyStyleInformation style = new BeautyStyleInformation(details.title, details.body, "", "Claim", "");
    style.template = "goal";
    details.styleInformation = style;
    return details;
  }
}
