package com.dexterous.flutterlocalnotifications;

import static org.junit.Assert.*;

import android.app.Notification;
import android.content.Context;
import android.support.v4.media.session.MediaSessionCompat;
import androidx.core.app.NotificationCompat;
import androidx.test.core.app.ApplicationProvider;
import com.dexterous.flutterlocalnotifications.models.NotificationDetails;
import com.dexterous.flutterlocalnotifications.models.styles.MediaStyleInformation;
import java.lang.reflect.Method;
import java.util.HashSet;
import java.util.Set;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 28)
public class PCMediaNotificationChannelsTest {
  @Test public void fourMediaChannelsOwnDifferentSessionsAndReuseOnlyTheirOwnToken() throws Exception {
    Context context = ApplicationProvider.getApplicationContext();
    Method method = FlutterLocalNotificationsPlugin.class.getDeclaredMethod("setMediaStyle", Context.class, NotificationDetails.class, NotificationCompat.Builder.class, Runnable.class);
    method.setAccessible(true);
    Set<MediaSessionCompat.Token> tokens = new HashSet<>();
    MediaSessionCompat.Token first = null;
    for (int index = 0; index < 4; index++) {
      NotificationDetails details = new NotificationDetails();
      details.channelId = "media_channel_" + index;
      details.title = "Media title " + index;
      details.body = "Media body " + index;
      details.styleInformation = new MediaStyleInformation("");
      NotificationCompat.Builder builder = new NotificationCompat.Builder(context, details.channelId).setSmallIcon(R.drawable.pc_notification_small);
      final boolean[] completed = {false};
      method.invoke(null, context, details, builder, (Runnable) () -> completed[0] = true);
      assertTrue(completed[0]);
      Notification notification = builder.build();
      MediaSessionCompat.Token token = androidx.media.app.NotificationCompat.MediaStyle.getMediaSession(notification);
      assertNotNull(token);
      tokens.add(token);
      if (index == 0) first = token;
    }
    assertEquals(4, tokens.size());
    NotificationDetails update = new NotificationDetails();
    update.channelId = "media_channel_0";
    update.title = "Updated first channel";
    update.body = "Updated body";
    update.styleInformation = new MediaStyleInformation("");
    NotificationCompat.Builder builder = new NotificationCompat.Builder(context, update.channelId).setSmallIcon(R.drawable.pc_notification_small);
    method.invoke(null, context, update, builder, (Runnable) () -> {});
    assertEquals(first, androidx.media.app.NotificationCompat.MediaStyle.getMediaSession(builder.build()));
  }
}
