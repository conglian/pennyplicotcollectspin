package com.dexterous.flutterlocalnotifications;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.os.Build;
import android.support.v4.media.MediaMetadataCompat;
import android.support.v4.media.session.MediaSessionCompat;
import android.util.Log;
import android.widget.RemoteViews;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

import com.dexterous.flutterlocalnotifications.models.NotificationDetails;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.Objects;
import java.util.UUID;

/** 1.0.0 的 T7 媒体卡片，只在一条宿主通知发布后发送。 */
public final class PennyMediaNotification {
  static final String CHANNEL_ID = "pc_notice_media_v1";
  static final int FIRST_DISPLAY_ID = 21_000;
  private static final String TAG = "PennyMediaNotification";
  private static final String CURSOR = "penny_media_notification_cursor_v1";
  private static final String SOURCE_PREFIX = "penny_media_notification_source_";
  private static final String DISMISS_PREFIX = "penny_media_notification_dismiss_";
  private static final int SLOT_COUNT = PennyNotificationAnalytics.MAX_VISIBLE_NOTIFICATIONS;
  private static final String[][] COPIES = {
    {"Your Piggy Bank Is Waiting", "Open PennyPilot to check your progress."},
    {"Ready For Another Round?", "Try a quiz or give the wheel another spin."},
    {"Check In On Your Piggy", "See your latest progress in PennyPilot."},
    {"Keep Your Cash Goal In Sight", "Open PennyPilot to see how close you are."}
  };
  private static final MediaSessionCompat[] systemMediaSessions = new MediaSessionCompat[SLOT_COUNT];

  private PennyMediaNotification() {}

  static void showForHost(Context context, NotificationDetails host, String broadcastAction) {
    if (!PennyNotificationStyle.isPenny(host)) return;
    String type = PennyNotificationAnalytics.typeFor(host.payload, broadcastAction);
    if ("local".equals(type) || "fcm".equals(type) || PennyNotificationAnalytics.isSceneType(type)) {
      show(context, host);
    }
  }

  /** FCM 的非前台通知由 SDK 发布，调用方已确认系统里有对应通知。 */
  public static void showForSystemFcm(Context context, NotificationDetails host) {
    PennyNotificationAnalytics.recordShown(context, host, null);
    show(context, host);
  }

  private static synchronized void show(Context context, NotificationDetails host) {
    try {
      NotificationManagerCompat manager = NotificationManagerCompat.from(context);
      if (!PennyNotificationAnalytics.allowed(context, host)) return;
      createChannel(context);

      SharedPreferences preferences = preferences(context);
      int slot = Math.floorMod(preferences.getInt(CURSOR, 0), SLOT_COUNT);
      int id = FIRST_DISPLAY_ID + slot;
      NotificationDetails details = new NotificationDetails();
      details.channelId = CHANNEL_ID;
      details.payload = "{\"pcNotice\":1,\"type\":\"media\",\"action\":\"" + actionFor(host.payload) + "\"}";
      if (!PennyNotificationAnalytics.allowed(context, details)) return;

      String[] copy = COPIES[slot % COPIES.length];
      String dismissToken = UUID.randomUUID().toString();
      PendingIntent click = FlutterLocalNotificationsPlugin.notificationContentIntent(
          context, id, details.payload, true, dismissToken);
      NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ID)
          .setSmallIcon(R.drawable.pc_notification_small)
          .setContentTitle(copy[0])
          .setContentText(copy[1])
          .setContentIntent(click)
          .setPriority(NotificationCompat.PRIORITY_LOW)
          .setOnlyAlertOnce(true)
          .setAutoCancel(true);
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        configureSystemCard(context, builder, slot, copy, click);
      } else {
        builder.setStyle(new NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(card(context, R.layout.pc_notice_media_compact, copy, click))
            .setCustomBigContentView(card(context, R.layout.pc_notice_media_expanded, copy, click));
      }
      manager.notify(id, builder.build());
      preferences.edit().putInt(CURSOR, (slot + 1) % SLOT_COUNT)
          .putInt(SOURCE_PREFIX + slot, host.id)
          .putString(DISMISS_PREFIX + slot, dismissToken).apply();
      PennyNotificationAnalytics.recordShown(context, details, null);
    } catch (RuntimeException error) {
      Log.w(TAG, "Could not display the media companion", error);
    }
  }

  private static void configureSystemCard(Context context, NotificationCompat.Builder builder,
                                          int slot, String[] copy, PendingIntent click) {
    MediaSessionCompat session = systemMediaSessions[slot];
    if (session == null) {
      session = new MediaSessionCompat(context.getApplicationContext(), "PennyPilotMedia-" + slot);
      systemMediaSessions[slot] = session;
    }
    Bitmap cover = BitmapFactory.decodeResource(context.getResources(), R.drawable.pc_notice_account_icon);
    session.setSessionActivity(click);
    session.setMetadata(new MediaMetadataCompat.Builder()
        .putString(MediaMetadataCompat.METADATA_KEY_TITLE, copy[0])
        .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, copy[1])
        .putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, cover)
        .build());
    // T7 remains silent. Do not advertise play, pause, or seek commands.
    session.setActive(true);
    builder.setLargeIcon(cover)
        .setColor(Color.BLACK)
        .setStyle(new androidx.media.app.NotificationCompat.MediaStyle()
            .setMediaSession(session.getSessionToken()));
  }

  private static RemoteViews card(Context context, int layout, String[] copy, PendingIntent click) {
    RemoteViews view = new RemoteViews(context.getPackageName(), layout);
    view.setTextViewText(R.id.pc_notice_media_title, copy[0]);
    view.setTextViewText(R.id.pc_notice_media_body, copy[1]);
    view.setOnClickPendingIntent(R.id.pc_notice_media_card, click);
    return view;
  }

  private static void createChannel(Context context) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;
    NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
    if (manager.getNotificationChannel(CHANNEL_ID) != null) return;
    NotificationChannel channel = new NotificationChannel(
        CHANNEL_ID, "Piggy Media Reminders", NotificationManager.IMPORTANCE_LOW);
    channel.setSound(null, null);
    manager.createNotificationChannel(channel);
  }

  private static String actionFor(String payload) {
    if ("fcm1".equals(payload)) return "withdraw";
    if (payload != null && payload.trim().startsWith("{")) {
      try {
        if ("withdraw".equals(new JSONObject(payload).optString("action"))) return "withdraw";
      } catch (JSONException ignored) {
        // Fall back to the Earn action for an old or malformed payload.
      }
    }
    return "earn";
  }

  static synchronized void cancelSource(Context context, int sourceId) {
    SharedPreferences preferences = preferences(context);
    SharedPreferences.Editor editor = preferences.edit();
    NotificationManagerCompat manager = NotificationManagerCompat.from(context);
    for (int slot = 0; slot < SLOT_COUNT; slot++) {
      String key = SOURCE_PREFIX + slot;
      if (!preferences.contains(key) || preferences.getInt(key, 0) != sourceId) continue;
      cancelSlot(manager, editor, slot);
    }
    editor.apply();
  }

  static synchronized void cancelClicked(Context context, int displayId, String dismissToken) {
    int slot = displayId - FIRST_DISPLAY_ID;
    if (slot < 0 || slot >= SLOT_COUNT) return;
    SharedPreferences preferences = preferences(context);
    if (!preferences.contains(SOURCE_PREFIX + slot)
        || !Objects.equals(dismissToken, preferences.getString(DISMISS_PREFIX + slot, null))) return;
    SharedPreferences.Editor editor = preferences.edit();
    cancelSlot(NotificationManagerCompat.from(context), editor, slot);
    editor.apply();
  }

  private static void cancelSlot(NotificationManagerCompat manager, SharedPreferences.Editor editor, int slot) {
    manager.cancel(FIRST_DISPLAY_ID + slot);
    releaseSystemSession(slot);
    editor.remove(SOURCE_PREFIX + slot).remove(DISMISS_PREFIX + slot);
  }

  static synchronized void clearDisplaySlots(Context context) {
    SharedPreferences.Editor editor = preferences(context).edit().remove(CURSOR);
    for (int slot = 0; slot < SLOT_COUNT; slot++) {
      releaseSystemSession(slot);
      editor.remove(SOURCE_PREFIX + slot).remove(DISMISS_PREFIX + slot);
    }
    editor.apply();
  }

  private static void releaseSystemSession(int slot) {
    MediaSessionCompat session = systemMediaSessions[slot];
    if (session == null) return;
    session.release();
    systemMediaSessions[slot] = null;
  }

  private static SharedPreferences preferences(Context context) {
    return context.getSharedPreferences(
        FlutterLocalNotificationsPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE);
  }
}
