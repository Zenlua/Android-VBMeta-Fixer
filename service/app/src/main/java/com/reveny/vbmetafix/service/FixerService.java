package com.reveny.vbmetafix.service;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.IBinder;
import android.provider.Settings;
import android.util.Log;

import com.reveny.vbmetafix.service.keyattestation.Entry;

public class FixerService extends Service {
    private static final String CHANNEL_ID = "fixer_service_channel";
    private static final int NOTIFICATION_ID = 1001;
    private static final String TAG = "FixerService";
    private Handler handler;
    private HandlerThread handlerThread;

    public void writeBootHashToSystemGlobal(String bootHash) {
        try {
            Settings.Global.putString(getContentResolver(), "pif_boot_hash", bootHash);
            Log.d(TAG, "Boot hash saved to Settings.Global (key=pif_boot_hash)");
        } catch (Exception e) {
            Log.e(TAG, "Failed to write boot hash to system_global", e);
        }
    }

    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "Service Created");
        createNotificationChannel();
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION_ID, createNotification(), 1);
        } else {
            startForeground(NOTIFICATION_ID, createNotification());
        }
        this.handlerThread = new HandlerThread("FixerServiceThread");
        this.handlerThread.start();
        this.handler = new Handler(this.handlerThread.getLooper());
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel channel =
                    new NotificationChannel(CHANNEL_ID,
                            "Fixer Service Channel",
                            NotificationManager.IMPORTANCE_DEFAULT);
            channel.setDescription("Used for running VBMeta fixing operations");
            NotificationManager notificationManager =
                    (NotificationManager) getSystemService(NotificationManager.class);
            if (notificationManager != null) {
                notificationManager.createNotificationChannel(channel);
            }
        }
    }

    private Notification createNotification() {
        if (Build.VERSION.SDK_INT >= 26) {
            return new Notification.Builder(this, CHANNEL_ID)
                    .setContentTitle("VBMeta Service")
                    .setContentText("Processing boot hash...")
                    .setSmallIcon(0x01080041)
                    .build();
        }
        return new Notification.Builder(this)
                .setContentTitle("VBMeta Service")
                .setContentText("Processing boot hash...")
                .setSmallIcon(0x01080041)
                .setPriority(Notification.PRIORITY_LOW)
                .build();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(TAG, "Service Started");
        // Sử dụng method reference thay cho lớp synthetic của Jadx
        this.handler.post(this::lambda$onStartCommand$0);
        return START_STICKY;
    }

    public void lambda$onStartCommand$0() {
        try {
            try {
                String bootHash = Entry.run();
                Log.d(TAG, "Boot hash: " + bootHash);
                writeBootHashToSystemGlobal(bootHash);
            } catch (Exception e) {
                Log.e(TAG, "Error processing boot hash", e);
            }
        } finally {
            stopSelf();
        }
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onDestroy() {
        if (this.handlerThread != null) {
            this.handlerThread.quitSafely();
        }
        super.onDestroy();
        Log.d(TAG, "Service Destroyed");
    }
}
