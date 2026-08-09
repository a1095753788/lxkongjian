package com.novabox.player;

import android.content.Context;
import android.content.SharedPreferences;

/** Stores the user's selected folder so it persists across launches. */
public class PrefManager {

    private static final String PREFS = "novabox_prefs";
    private static final String KEY_FOLDER = "selected_folder";
    private static final String KEY_SHUFFLE = "shuffle_on_launch";

    private final SharedPreferences sp;

    public PrefManager(Context ctx) {
        sp = ctx.getApplicationContext().getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    public String getFolder() {
        return sp.getString(KEY_FOLDER, null);
    }

    public void setFolder(String path) {
        sp.edit().putString(KEY_FOLDER, path).apply();
    }

    public boolean isShuffleOnLaunch() {
        return sp.getBoolean(KEY_SHUFFLE, true);
    }

    public void setShuffleOnLaunch(boolean shuffle) {
        sp.edit().putBoolean(KEY_SHUFFLE, shuffle).apply();
    }
}
