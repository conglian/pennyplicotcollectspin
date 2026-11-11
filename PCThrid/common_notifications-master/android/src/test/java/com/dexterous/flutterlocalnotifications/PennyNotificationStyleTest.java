package com.dexterous.flutterlocalnotifications;

import static org.junit.Assert.*;
import android.app.Activity;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.TextView;
import android.widget.ImageView;
import androidx.core.app.NotificationCompat;
import androidx.test.core.app.ApplicationProvider;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.dexterous.flutterlocalnotifications.models.styles.BeautyStyleInformation;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.Shadows;
import org.robolectric.annotation.Config;
import java.util.HashMap;
import java.util.Map;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 28)
public class PennyNotificationStyleTest {
  @Test public void flutterChannelAndPersistedSchedulesKeepTemplateAndAmount() {
    Map<String, Object> style = new HashMap<>();
    style.put("title", "My Cash Account");
    style.put("body", "Balance reminder");
    style.put("button", "Withdraw");
    style.put("image", "");
    style.put("appIcon", "pc_notice_app_icon");
    style.put("template", "account");
    style.put("amount", "$59.25");
    style.put("htmlFormatTitle", false);
    style.put("htmlFormatContent", false);
    Map<String, Object> platform = new HashMap<>();
    platform.put("style", 6);
    platform.put("channelAction", 0);
    platform.put("styleInformation", style);
    Map<String, Object> arguments = new HashMap<>();
    arguments.put("id", 8852);
    arguments.put("platformSpecifics", platform);
    NotificationDetails parsed = NotificationDetails.from(arguments);
    BeautyStyleInformation info = (BeautyStyleInformation) parsed.styleInformation;
    assertEquals("account", info.template);
    assertEquals("$59.25", info.amount);
    com.google.gson.Gson gson = FlutterLocalNotificationsPlugin.buildGson();
    NotificationDetails restored = gson.fromJson(gson.toJson(parsed), NotificationDetails.class);
    assertTrue(PennyNotificationStyle.isPenny(restored));
    assertEquals("$59.25", ((BeautyStyleInformation) restored.styleInformation).amount);
  }

  @Test public void legacyBeautyKeepsExistingTemplate() {
    Context context = ApplicationProvider.getApplicationContext();
    NotificationDetails details = new NotificationDetails();
    details.styleInformation = new BeautyStyleInformation("Title", "Body", "", "Go", "");
    assertFalse(PennyNotificationStyle.apply(context, details, new NotificationCompat.Builder(context, "test")));
    assertFalse(PennyNotificationStyle.suppressWhileForeground(details));
  }

  @Test public void allTemplatesBindSmallExpandedViewsAndButtonPayload() {
    Context context = ApplicationProvider.getApplicationContext();
    for (String template : new String[]{"account", "goal"}) {
      BeautyStyleInformation info = new BeautyStyleInformation("My Cash Account", "A useful reminder", "", "Withdraw", "");
      info.template = template;
      info.amount = "$59.25";
      info.button = "goal".equals(template) ? "Claim" : "Withdraw";
      NotificationDetails details = new NotificationDetails();
      details.styleInformation = info;
      details.id = 777;
      Intent intent = new Intent(context, Activity.class).putExtra("payload", template);
      PendingIntent click = PendingIntent.getActivity(context, template.hashCode(), intent,
          PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
      NotificationCompat.Builder builder = new NotificationCompat.Builder(context, "test")
          .setSmallIcon(R.drawable.pc_notification_small).setContentIntent(click);
      assertTrue(PennyNotificationStyle.apply(context, details, builder));
      android.app.Notification notification = builder.build();
      assertNotNull(notification.contentView);
      assertNotNull(notification.bigContentView);
      FrameLayout parent = new FrameLayout(context);
      View small = notification.contentView.apply(context, parent);
      View big = notification.bigContentView.apply(context, parent);
      assertEquals(info.button, ((TextView) small.findViewById(R.id.pc_notice_button)).getText().toString());
      assertEquals(info.title, ((TextView) small.findViewById(R.id.pc_notice_title)).getText().toString());
      assertEquals(info.button, ((TextView) big.findViewById(R.id.pc_notice_button)).getText().toString());
      if ("account".equals(template)) {
        assertEquals("$59.25", small.findViewById(R.id.pc_notice_amount).getContentDescription());
        assertEquals("$59.25", big.findViewById(R.id.pc_notice_amount).getContentDescription());
        assertNotNull(((ImageView) small.findViewById(R.id.pc_notice_amount)).getDrawable());
        assertEquals("My Cash Account=", ((TextView) big.findViewById(R.id.pc_notice_title)).getText().toString());
      } else {
        assertEquals(View.GONE, small.findViewById(R.id.pc_notice_amount).getVisibility());
        assertEquals("A useful reminder", ((TextView) big.findViewById(R.id.pc_notice_body)).getText().toString());
      }
      for (int width : new int[]{280, 380}) {
        big.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(252, View.MeasureSpec.AT_MOST));
        big.layout(0, 0, big.getMeasuredWidth(), big.getMeasuredHeight());
        View button = big.findViewById(R.id.pc_notice_button);
        assertTrue(button.getWidth() > 0);
        assertTrue(button.getBottom() <= big.getHeight());
        small.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(48, View.MeasureSpec.AT_MOST));
        small.layout(0, 0, small.getMeasuredWidth(), small.getMeasuredHeight());
        View smallButton = small.findViewById(R.id.pc_notice_button);
        assertTrue(smallButton.getBottom() <= small.getHeight());
        if ("account".equals(template)) {
          View title = small.findViewById(R.id.pc_notice_title);
          assertTrue(title.getRight() + ((View) title.getParent()).getLeft() <= smallButton.getLeft());
        }
      }
      big.findViewById(R.id.pc_notice_button).performClick();
      Intent launched = Shadows.shadowOf((android.app.Application) context).getNextStartedActivity();
      assertNotNull(launched);
      assertEquals(template, launched.getStringExtra("payload"));
      if ("goal".equals(template)) {
        small.findViewById(R.id.pc_notice_button).performClick();
        Intent compactLaunch = Shadows.shadowOf((android.app.Application) context).getNextStartedActivity();
        assertNotNull(compactLaunch);
        assertEquals(template, compactLaunch.getStringExtra("payload"));
      }
    }
  }

  @Test public void removedPersistedTemplateUsesGoalWithoutChangingItsClickPayload() {
    Context context = ApplicationProvider.getApplicationContext();
    BeautyStyleInformation info = new BeautyStyleInformation("Saved title", "Saved body", "", "Cash Out", "");
    info.template = "payout";
    NotificationDetails details = new NotificationDetails();
    details.styleInformation = info;
    Intent intent = new Intent(context, Activity.class).putExtra("payload", "noti3");
    PendingIntent click = PendingIntent.getActivity(context, 7552, intent,
        PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    NotificationCompat.Builder builder = new NotificationCompat.Builder(context, "test")
        .setSmallIcon(R.drawable.pc_notification_small).setContentIntent(click);
    assertTrue(PennyNotificationStyle.apply(context, details, builder));
    assertEquals("goal", info.template);
    assertEquals("Claim", info.button);
    View big = builder.build().bigContentView.apply(context, new FrameLayout(context));
    assertEquals(172, big.getLayoutParams().height / context.getResources().getDisplayMetrics().density, .1);
    assertEquals("Claim", ((TextView) big.findViewById(R.id.pc_notice_button)).getText().toString());
    big.findViewById(R.id.pc_notice_button).performClick();
    Intent launched = Shadows.shadowOf((android.app.Application) context).getNextStartedActivity();
    assertNotNull(launched);
    assertEquals("noti3", launched.getStringExtra("payload"));
  }
}
