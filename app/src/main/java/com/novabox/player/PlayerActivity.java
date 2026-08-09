package com.novabox.player;

import android.app.AlertDialog;
import android.app.Dialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.media.MediaPlayer;
import android.media.PlaybackParams;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.widget.BaseAdapter;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;
import android.widget.VideoView;

import java.io.File;
import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;

/**
 * 本地"抖音风格"播放器。
 * <p>
 * 打开后随机乱序播放视频，遥控器操作：
 * <ul>
 *   <li>上 / 频道+ / PageUp / MediaNext -> 下一个视频</li>
 *   <li>下 / 频道- / PageDown / MediaPrev -> 上一个视频</li>
 *   <li>左 / 右 -> 后退 / 快进 10 秒</li>
 *   <li>中键(OK) -> 暂停 / 继续</li>
 *   <li>设置键(Menu) -> 打开设置（倍速/删除）</li>
 * </ul>
 * 视频播完自动播下一个，无限循环。
 */
public class PlayerActivity extends android.app.Activity {

    private static final String TAG = "NovaBoxPlayer";
    public static final String EXTRA_VIDEOS = "extra_videos";
    public static final String EXTRA_SHUFFLE = "extra_shuffle";

    private static final int SEEK_STEP_MS = 10_000;

    // 倍速选项
    private static final float[] SPEEDS = {0.5f, 0.75f, 1.0f, 1.25f, 1.5f, 2.0f, 2.5f, 3.0f};
    private static final String[] SPEED_LABELS = {"0.5x", "0.75x", "1.0x", "1.25x", "1.5x", "2.0x", "2.5x", "3.0x"};
    private int speedIndex = 2; // 默认 1.0x

    private VideoView videoView;
    private TextView titleOverlay;
    private TextView indexOverlay;
    private TextView speedOverlay;
    private final Handler handler = new Handler(Looper.getMainLooper());

    private final List<String> playlist = new ArrayList<>();
    private int currentIndex = 0;
    private boolean shuffle;

    private Dialog settingsDialog;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_player);

        videoView = findViewById(R.id.video_view);
        titleOverlay = findViewById(R.id.title_overlay);
        indexOverlay = findViewById(R.id.index_overlay);
        speedOverlay = findViewById(R.id.speed_overlay);

        Intent intent = getIntent();
        ArrayList<String> incoming = intent.getStringArrayListExtra(EXTRA_VIDEOS);
        shuffle = intent.getBooleanExtra(EXTRA_SHUFFLE, true);
        if (incoming == null || incoming.isEmpty()) {
            Toast.makeText(this, R.string.no_videos_found, Toast.LENGTH_SHORT).show();
            finish();
            return;
        }
        playlist.addAll(incoming);

        if (shuffle) Collections.shuffle(playlist, new Random());

        videoView.setOnCompletionListener(mp -> nextVideo());
        videoView.setOnErrorListener(this::onPlaybackError);

        playIndex(0);
    }

    private boolean onPlaybackError(MediaPlayer mp, int what, int extra) {
        Log.w(TAG, "Playback error what=" + what + " extra=" + extra);
        Toast.makeText(this, R.string.playback_error, Toast.LENGTH_SHORT).show();
        handler.postDelayed(this::nextVideo, 600);
        return true;
    }

    private void playIndex(int index) {
        if (playlist.isEmpty()) {
            finish();
            return;
        }
        currentIndex = (index % playlist.size() + playlist.size()) % playlist.size();
        String path = playlist.get(currentIndex);
        videoView.setVideoURI(Uri.fromFile(new File(path)));
        videoView.start();
        // 恢复倍速（VideoView 重新创建 MediaPlayer 后需要重新设置）
        applySpeed();
        showOverlay(new File(path).getName());
    }

    private void nextVideo() {
        playIndex(currentIndex + 1);
    }

    private void prevVideo() {
        playIndex(currentIndex - 1);
    }

    private void togglePause() {
        if (videoView.isPlaying()) {
            videoView.pause();
        } else {
            videoView.start();
        }
    }

    private void seekBy(int deltaMs) {
        try {
            int pos = videoView.getCurrentPosition();
            int dur = videoView.getDuration();
            int target = Math.max(0, Math.min(dur, pos + deltaMs));
            videoView.seekTo(target);
        } catch (Exception ignored) {
        }
    }

    // ==================== 倍速控制 ====================

    /** 通过反射获取 VideoView 内部的 MediaPlayer。 */
    private MediaPlayer getInternalMediaPlayer() {
        try {
            Field f = VideoView.class.getDeclaredField("mMediaPlayer");
            f.setAccessible(true);
            return (MediaPlayer) f.get(videoView);
        } catch (Exception e) {
            Log.w(TAG, "无法获取内部 MediaPlayer: " + e.getMessage());
            return null;
        }
    }

    /** 设置播放倍速。 */
    private void applySpeed() {
        float speed = SPEEDS[speedIndex];
        if (Math.abs(speed - 1.0f) < 0.01f) {
            speedOverlay.setVisibility(View.GONE);
            return;
        }
        try {
            MediaPlayer mp = getInternalMediaPlayer();
            if (mp != null) {
                PlaybackParams params = mp.getPlaybackParams();
                params.setSpeed(speed);
                mp.setPlaybackParams(params);
            }
            // 显示倍速指示器
            speedOverlay.setText(SPEED_LABELS[speedIndex]);
            speedOverlay.setVisibility(View.VISIBLE);
        } catch (Exception e) {
            Log.w(TAG, "设置倍速失败: " + e.getMessage());
        }
    }

    /** 设置指定倍速索引。 */
    private void setSpeed(int index) {
        speedIndex = index;
        applySpeed();
    }

    // ==================== 删除视频 ====================

    /** 删除当前播放的视频文件，然后跳到下一个。 */
    private void deleteCurrentVideo() {
        if (playlist.isEmpty()) return;
        String path = playlist.get(currentIndex);
        File file = new File(path);
        boolean deleted = false;
        if (file.exists()) {
            try {
                videoView.stopPlayback();
                deleted = file.delete();
            } catch (Exception e) {
                Log.w(TAG, "删除文件异常: " + e.getMessage());
            }
        }

        if (deleted) {
            playlist.remove(currentIndex);
            Toast.makeText(this, R.string.settings_deleted, Toast.LENGTH_SHORT).show();
            if (playlist.isEmpty()) {
                Toast.makeText(this, R.string.no_videos_found, Toast.LENGTH_SHORT).show();
                finish();
                return;
            }
            // currentIndex 可能越界，playIndex 会自动取模
            if (currentIndex >= playlist.size()) currentIndex = 0;
            playIndex(currentIndex);
        } else {
            Toast.makeText(this, R.string.settings_delete_fail, Toast.LENGTH_SHORT).show();
            // 删除失败，重新开始播放当前视频
            videoView.start();
            applySpeed();
        }
    }

    // ==================== 设置弹窗 ====================

    /** 设置列表项类型 */
    private static final int ITEM_SPEED = 0;
    private static final int ITEM_SEPARATOR = 1;
    private static final int ITEM_DELETE = 2;
    private static final int ITEM_CLOSE = 3;

    private static class SettingItem {
        int type;
        String label;
        int speedIndex;
        boolean highlight;
    }

    private void showSettingsDialog() {
        if (videoView.isPlaying()) videoView.pause();

        List<SettingItem> settingItems = new ArrayList<>();

        // 倍速选项
        SettingItem sep = new SettingItem();
        sep.type = ITEM_SEPARATOR;
        sep.label = "播放速度";
        settingItems.add(sep);

        for (int i = 0; i < SPEEDS.length; i++) {
            SettingItem item = new SettingItem();
            item.type = ITEM_SPEED;
            item.speedIndex = i;
            item.label = SPEED_LABELS[i];
            item.highlight = (i == speedIndex);
            settingItems.add(item);
        }

        // 分隔线
        SettingItem sep2 = new SettingItem();
        sep2.type = ITEM_SEPARATOR;
        sep2.label = "";
        settingItems.add(sep2);

        // 删除
        SettingItem delItem = new SettingItem();
        delItem.type = ITEM_DELETE;
        delItem.label = "🗑  删除当前视频文件";
        settingItems.add(delItem);

        // 关闭
        SettingItem closeItem = new SettingItem();
        closeItem.type = ITEM_CLOSE;
        closeItem.label = "关闭设置";
        settingItems.add(closeItem);

        final Dialog dialog = new Dialog(this, android.R.style.Theme_Material_NoActionBar);
        dialog.setContentView(R.layout.dialog_settings);
        dialog.setCancelable(true);
        dialog.getWindow().setLayout(
                (int) (getResources().getDisplayMetrics().widthPixels * 0.5),
                WindowManager.LayoutParams.WRAP_CONTENT);

        ListView listView = dialog.findViewById(R.id.settings_list);
        final SettingsAdapter adapter = new SettingsAdapter(settingItems);
        listView.setAdapter(adapter);

        listView.setOnItemClickListener((parent, view, position, id) -> {
            SettingItem item = settingItems.get(position);
            switch (item.type) {
                case ITEM_SPEED:
                    setSpeed(item.speedIndex);
                    // 刷新高亮
                    for (SettingItem si : settingItems) {
                        if (si.type == ITEM_SPEED) {
                            si.highlight = (si.speedIndex == speedIndex);
                        }
                    }
                    adapter.notifyDataSetChanged();
                    break;
                case ITEM_DELETE:
                    dialog.dismiss();
                    confirmDelete();
                    break;
                case ITEM_CLOSE:
                    dialog.dismiss();
                    break;
            }
        });

        dialog.setOnDismissListener(d -> {
            if (!videoView.isPlaying()) videoView.start();
            applySpeed();
        });

        // 定位到当前倍速
        int focusPos = 0;
        for (int i = 0; i < settingItems.size(); i++) {
            if (settingItems.get(i).type == ITEM_SPEED && settingItems.get(i).highlight) {
                focusPos = i;
                break;
            }
        }
        listView.requestFocus();
        listView.setSelection(focusPos);

        settingsDialog = dialog;
        dialog.show();
    }

    private void confirmDelete() {
        new AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog)
                .setTitle(R.string.settings_delete)
                .setMessage("确定删除 \"" + new File(playlist.get(currentIndex)).getName() + "\" ？")
                .setPositiveButton("删除", (d, w) -> deleteCurrentVideo())
                .setNegativeButton("取消", (d, w) -> {
                    if (!videoView.isPlaying()) videoView.start();
                    applySpeed();
                })
                .show();
    }

    /** 设置列表 Adapter */
    private class SettingsAdapter extends BaseAdapter {
        private final List<SettingItem> items;

        SettingsAdapter(List<SettingItem> items) {
            this.items = items;
        }

        @Override
        public int getCount() { return items.size(); }

        @Override
        public SettingItem getItem(int position) { return items.get(position); }

        @Override
        public long getItemId(int position) { return position; }

        @Override
        public boolean isEnabled(int position) {
            return items.get(position).type != ITEM_SEPARATOR;
        }

        @Override
        public View getView(int position, View convertView, ViewGroup parent) {
            SettingItem item = items.get(position);
            LayoutInflater inf = LayoutInflater.from(PlayerActivity.this);

            if (item.type == ITEM_SEPARATOR) {
                TextView tv = (TextView) inf.inflate(
                        android.R.layout.simple_list_item_1, parent, false);
                tv.setText(item.label);
                tv.setTextColor(0xFF8BC34A);
                tv.setBackgroundColor(0xFF222222);
                tv.setTextSize(13);
                tv.setEnabled(false);
                tv.setPadding(dp(16), dp(6), dp(16), dp(6));
                return tv;
            }

            TextView tv = (TextView) inf.inflate(
                    android.R.layout.simple_list_item_activated_1, parent, false);
            String text = item.label;
            if (item.type == ITEM_SPEED && item.highlight) {
                text = text + "  ✓";
            }
            tv.setText(text);
            tv.setTextSize(16);
            tv.setGravity(Gravity.CENTER);
            tv.setPadding(dp(16), dp(12), dp(16), dp(12));

            if (item.type == ITEM_DELETE) {
                tv.setTextColor(0xFFFF5555);
            } else if (item.highlight) {
                tv.setTextColor(0xFF8BC34A);
            } else {
                tv.setTextColor(0xFFEEEEEE);
            }
            return tv;
        }
    }

    // ==================== 标题浮层 ====================

    private static final int OVERLAY_DURATION = 2500;

    private void showOverlay(String name) {
        titleOverlay.setText(name);
        indexOverlay.setText((currentIndex + 1) + " / " + playlist.size());
        titleOverlay.setVisibility(View.VISIBLE);
        indexOverlay.setVisibility(View.VISIBLE);
        handler.removeCallbacks(hideOverlay);
        handler.postDelayed(hideOverlay, OVERLAY_DURATION);
    }

    private final Runnable hideOverlay = () -> {
        titleOverlay.setVisibility(View.GONE);
        indexOverlay.setVisibility(View.GONE);
    };

    // ==================== 遥控器按键 ====================

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        // 设置弹窗打开时，交给系统处理
        if (settingsDialog != null && settingsDialog.isShowing()) {
            return super.onKeyDown(keyCode, event);
        }

        switch (keyCode) {
            case KeyEvent.KEYCODE_DPAD_UP:
            case KeyEvent.KEYCODE_CHANNEL_UP:
            case KeyEvent.KEYCODE_PAGE_UP:
            case KeyEvent.KEYCODE_MEDIA_NEXT:
                nextVideo();
                return true;
            case KeyEvent.KEYCODE_DPAD_DOWN:
            case KeyEvent.KEYCODE_CHANNEL_DOWN:
            case KeyEvent.KEYCODE_PAGE_DOWN:
            case KeyEvent.KEYCODE_MEDIA_PREVIOUS:
                prevVideo();
                return true;
            case KeyEvent.KEYCODE_DPAD_LEFT:
                seekBy(-SEEK_STEP_MS);
                return true;
            case KeyEvent.KEYCODE_DPAD_RIGHT:
                seekBy(SEEK_STEP_MS);
                return true;
            case KeyEvent.KEYCODE_DPAD_CENTER:
            case KeyEvent.KEYCODE_ENTER:
                togglePause();
                return true;
            case KeyEvent.KEYCODE_MENU:
            case KeyEvent.KEYCODE_SETTINGS:
                showSettingsDialog();
                return true;
            default:
                return super.onKeyDown(keyCode, event);
        }
    }

    private int dp(int v) {
        return (int) (v * getResources().getDisplayMetrics().density + 0.5f);
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (videoView.isPlaying()) videoView.pause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (settingsDialog == null || !settingsDialog.isShowing()) {
            if (!videoView.isPlaying()) videoView.start();
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        handler.removeCallbacksAndMessages(null);
        if (settingsDialog != null && settingsDialog.isShowing()) {
            settingsDialog.dismiss();
        }
        try {
            videoView.stopPlayback();
        } catch (Exception ignored) {
        }
    }
}
