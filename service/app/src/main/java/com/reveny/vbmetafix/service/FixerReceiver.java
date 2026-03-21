package com.reveny.vbmetafix;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import com.reveny.vbmetafix.service.keyattestation.Entry;

import java.io.File;
import java.io.FileOutputStream;

public class FixerReceiver extends BroadcastReceiver {

    private static final String TAG = "FixerReceiver";

    @Override
    public void onReceive(Context context, Intent intent) {
        new Thread(() -> {
            try {
                String bootHash = Entry.run();
                Log.d(TAG, "Boot hash: " + bootHash);

                File file = new File(context.getCacheDir(), "boot.hash");
                try (FileOutputStream fos = new FileOutputStream(file)) {
                    fos.write(bootHash.getBytes());
                }

            } catch (Exception e) {
                Log.e(TAG, "Error", e);
            }
        }).start();
    }
}
