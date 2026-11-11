package com.dexterous.flutterlocalnotifications.fcm;

import static org.junit.Assert.*;

import android.content.Context;
import android.os.Bundle;
import androidx.test.core.app.ApplicationProvider;
import com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.dexterous.flutterlocalnotifications.models.NotificationStyle;
import com.dexterous.flutterlocalnotifications.models.styles.BeautyStyleInformation;
import com.google.firebase.messaging.RemoteMessage;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 28)
public class PCFirebaseNotificationChannelsTest {
  private Context context;

  @Before public void setUp() {
    context = ApplicationProvider.getApplicationContext();
    context.getSharedPreferences(FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE).edit().clear().commit();
    FlutterFCMPlugin.saveNotificationDetails(context, "c177fcm_piggy", template("pc_fcm_withdraw_v1", "fcm1", "goal"));
    FlutterFCMPlugin.saveNotificationDetails(context, "c177fcm_piggy_two", template("pc_fcm_claim_v1", "fcm2", "goal"));
  }

  private NotificationDetails template(String channel, String payload, String design) {
    NotificationDetails details = new NotificationDetails();
    details.id = 0;
    details.channelId = channel;
    details.payload = payload;
    details.title = "Local title must not replace the server";
    details.body = "Local body must not replace the server";
    details.style = NotificationStyle.Beauty;
    BeautyStyleInformation style = new BeautyStyleInformation("", "", "", "Withdraw", "");
    style.template = design;
    style.amount = "$106";
    details.styleInformation = style;
    return details;
  }

  private RemoteMessage message(String topic, String title, String body) {
    Bundle bundle = new Bundle();
    bundle.putString("from", "/topics/" + topic);
    bundle.putString("google.message_id", "test-message-" + topic);
    if (title != null) bundle.putString("title", title);
    if (body != null) bundle.putString("body", body);
    return new RemoteMessage(bundle);
  }

  @Test public void twoTopicsRetainIndependentTemplatesAndServerCopy() {
    NotificationDetails first = LocalFirebaseMessageService.buildNotificationDetails(context, message("c177fcm_piggy", "Server one", "Body one"));
    NotificationDetails second = LocalFirebaseMessageService.buildNotificationDetails(context, message("c177fcm_piggy_two", "Server two", "Body two"));
    assertNotNull(first);
    assertNotNull(second);
    assertEquals("pc_fcm_withdraw_v1", first.channelId);
    assertEquals("pc_fcm_claim_v1", second.channelId);
    assertEquals("fcm1", first.payload);
    assertEquals("fcm2", second.payload);
    assertEquals("Server one", ((BeautyStyleInformation) first.styleInformation).title);
    assertEquals("Body two", ((BeautyStyleInformation) second.styleInformation).body);
    assertEquals("goal", ((BeautyStyleInformation) first.styleInformation).template);
    assertEquals("goal", ((BeautyStyleInformation) second.styleInformation).template);
    assertNotEquals(first.id, second.id);
  }

  @Test public void oldFirstTopicTemplateRestoresAsGoalAndPreservesServerCopyAndWithdrawalPayload() {
    FlutterFCMPlugin.saveNotificationDetails(context, "c177fcm_piggy", template("pc_fcm_withdraw_v1", "fcm1", "payout"));
    NotificationDetails first = LocalFirebaseMessageService.buildNotificationDetails(context, message("c177fcm_piggy", "Server first", "Server body"));
    assertNotNull(first);
    assertEquals("pc_fcm_withdraw_v1", first.channelId);
    assertEquals("fcm1", first.payload);
    assertEquals("goal", ((BeautyStyleInformation) first.styleInformation).template);
    assertEquals("Claim", ((BeautyStyleInformation) first.styleInformation).button);
    assertEquals("Server first", ((BeautyStyleInformation) first.styleInformation).title);
    assertEquals("Server body", ((BeautyStyleInformation) first.styleInformation).body);
    assertNotNull(LocalFirebaseMessageService.buildNotificationDetails(context, message("c177fcm_piggy_two", "Server second", "Second body")));
  }

  @Test public void directDeviceMessagesSelectPayloadAndPreserveRemoteAmountWithMalformedId() {
    Bundle data = new Bundle();
    data.putString("payload", "fcm2");
    data.putString("title", "Remote title");
    data.putString("body", "Remote body");
    data.putString("amount", "$120");
    data.putString("id", "not-an-int");
    NotificationDetails details = LocalFirebaseMessageService.buildNotificationDetails(context, new RemoteMessage(data));
    assertNotNull(details);
    assertEquals("fcm2", details.payload);
    assertTrue(details.id >= 0);
    assertEquals("$120", ((BeautyStyleInformation) details.styleInformation).amount);
    assertEquals("Remote title", details.title);
  }

  @Test public void unknownChannelAndMissingServerCopyDoNotShowWrongLocalMessage() {
    assertNull(LocalFirebaseMessageService.buildNotificationDetails(context, message("unknown", "Unknown", "Body")));
    assertNull(LocalFirebaseMessageService.buildNotificationDetails(context, message("c177fcm_piggy", null, null)));
    FlutterFCMPlugin.removeNotificationDetails(context, "c177fcm_piggy");
    assertNull(LocalFirebaseMessageService.buildNotificationDetails(context, message("c177fcm_piggy", "Removed", "Body")));
    assertNotNull(LocalFirebaseMessageService.buildNotificationDetails(context, message("c177fcm_piggy_two", "Still active", "Body")));
  }
}
