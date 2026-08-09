package com.novabox.player;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.os.Environment;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.Button;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import java.io.File;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * 文件夹浏览界面。
 * <p>
 * 存储设备和文件夹全部放在同一个 ListView 里，
 * 遥控器只需在一个列表内上下移动即可选择一切。
 */
public class MainActivity extends Activity {

    private static final int REQ_PERMISSION = 1;

    /** 列表项类型 */
    private static final int TYPE_STORAGE = 0;
    private static final int TYPE_PARENT = 1;
    private static final int TYPE_FOLDER = 2;
    private static final int TYPE_SEPARATOR = 3;

    private PrefManager prefs;
    private File currentDir;
    private TextView pathLabel;
    private TextView hintLabel;
    private ListView listView;
    private ListAdapter listAdapter;
    private List<StorageUtils.StorageDevice> storageDevices = new ArrayList<>();

    /** 列表项数据 */
    private static class Item {
        int type;
        File file;
        String label;
        boolean highlight;
    }
    private final List<Item> items = new ArrayList<>();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        prefs = new PrefManager(this);
        pathLabel = findViewById(R.id.path_label);
        hintLabel = findViewById(R.id.hint_label);
        listView = findViewById(R.id.list);

        listAdapter = new ListAdapter();
        listView.setAdapter(listAdapter);

        findViewById(R.id.btn_select).setOnClickListener(v -> confirmSelection());
        findViewById(R.id.btn_shuffle_toggle).setOnClickListener(v -> toggleShuffle());
        updateShuffleLabel();

        listView.setOnItemClickListener((parent, view, position, id) -> {
            Item item = items.get(position);
            if (item == null) return;
            switch (item.type) {
                case TYPE_STORAGE:
                case TYPE_FOLDER:
                    if (item.file != null && item.file.isDirectory()) {
                        openDir(item.file);
                    }
                    break;
                case TYPE_PARENT:
                    if (item.file != null && item.file.isDirectory()) {
                        openDir(item.file);
                    }
                    break;
            }
        });

        if (checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE)
                == PackageManager.PERMISSION_GRANTED) {
            startBrowsing();
        } else {
            requestPermissions(
                    new String[]{
                            Manifest.permission.READ_EXTERNAL_STORAGE,
                            Manifest.permission.WRITE_EXTERNAL_STORAGE
                    }, REQ_PERMISSION);
        }
    }

    private void startBrowsing() {
        storageDevices = StorageUtils.getAvailableStorages(this);

        String saved = prefs.getFolder();
        File start = (saved != null && new File(saved).isDirectory()) ? new File(saved) : null;
        if (start == null && !storageDevices.isEmpty()) {
            start = storageDevices.get(0).path;
        }
        if (start == null) start = Environment.getExternalStorageDirectory();
        if (start == null || !start.isDirectory()) start = new File("/");
        openDir(start);
    }

    /** 判断文件是否是某个存储设备的根目录。 */
    private boolean isStorageRoot(File dir) {
        try {
            String canonical = dir.getCanonicalPath();
            for (StorageUtils.StorageDevice dev : storageDevices) {
                if (dir.getCanonicalPath().equals(dev.path.getCanonicalPath())) return true;
            }
        } catch (Exception ignored) {}
        return false;
    }

    /** 找到当前目录属于哪个存储设备。 */
    private File getCurrentStorageRoot() {
        try {
            String currentCanonical = currentDir.getCanonicalPath();
            File bestMatch = null;
            int bestLen = 0;
            for (StorageUtils.StorageDevice dev : storageDevices) {
                String devCanonical = dev.path.getCanonicalPath();
                if (currentCanonical.startsWith(devCanonical) && devCanonical.length() > bestLen) {
                    bestMatch = dev.path;
                    bestLen = devCanonical.length();
                }
            }
            return bestMatch;
        } catch (Exception e) {
            return null;
        }
    }

    private void openDir(File dir) {
        currentDir = dir;
        pathLabel.setText(dir.getAbsolutePath());
        rebuildList();
    }

    /**
     * 重建列表内容。布局如下：
     *   [存储设备 × N]      — 始终显示，高亮当前设备
     *   [↑ 返回上层]        — 只有不在存储根目录时显示
     *   [📁 子文件夹 × N]   — 当前目录下的文件夹
     */
    private void rebuildList() {
        items.clear();
        File currentRoot = getCurrentStorageRoot();

        // 1. 所有存储设备
        if (storageDevices.size() > 1 || currentRoot == null) {
            Item sep = new Item();
            sep.type = TYPE_SEPARATOR;
            sep.label = "── 存储设备 ──";
            items.add(sep);

            for (StorageUtils.StorageDevice dev : storageDevices) {
                Item item = new Item();
                item.type = TYPE_STORAGE;
                item.file = dev.path;
                item.label = "💾  " + dev.label;
                item.highlight = (currentRoot != null && samePath(currentRoot, dev.path));
                items.add(item);
            }
        }

        // 2. 返回上层（不在存储设备根目录时才显示）
        if (!isStorageRoot(currentDir)) {
            File parent = currentDir.getParentFile();
            if (parent != null && parent.canRead()) {
                Item item = new Item();
                item.type = TYPE_PARENT;
                item.file = parent;
                item.label = parent.getAbsolutePath().equals("/")
                        ? "↑  / (根目录)" : "↑  返回上层";
                items.add(item);
            }
        }

        // 3. 当前目录下的子文件夹
        File[] files = currentDir.listFiles();
        if (files != null) {
            List<File> dirs = new ArrayList<>();
            for (File f : files) {
                if (f.isDirectory() && !f.isHidden()) dirs.add(f);
            }
            Collections.sort(dirs, (a, b) -> a.getName().compareToIgnoreCase(b.getName()));

            if (!dirs.isEmpty()) {
                Item sep = new Item();
                sep.type = TYPE_SEPARATOR;
                sep.label = "── 文件夹 ──";
                items.add(sep);
            }

            for (File f : dirs) {
                Item item = new Item();
                item.type = TYPE_FOLDER;
                item.file = f;
                int count = VideoScanner.countSubFolders(f);
                item.label = "📁  " + f.getName() + (count > 0 ? "  (" + count + ")" : "");
                items.add(item);
            }
        }

        listAdapter.notifyDataSetChanged();

        // 让当前设备或第一条获得焦点
        listView.requestFocus();
        int focusPos = 0;
        for (int i = 0; i < items.size(); i++) {
            if (items.get(i).type != TYPE_SEPARATOR) {
                focusPos = i;
                break;
            }
        }
        listView.setSelection(focusPos);
    }

    private static boolean samePath(File a, File b) {
        try {
            return a.getCanonicalPath().equals(b.getCanonicalPath());
        } catch (Exception e) {
            return a.getAbsolutePath().equals(b.getAbsolutePath());
        }
    }

    // ==================== 列表 Adapter ====================

    private class ListAdapter extends BaseAdapter {

        @Override
        public int getCount() { return items.size(); }

        @Override
        public Item getItem(int position) { return items.get(position); }

        @Override
        public long getItemId(int position) { return position; }

        @Override
        public boolean isEnabled(int position) {
            return items.get(position).type != TYPE_SEPARATOR;
        }

        @Override
        public View getView(int position, View convertView, ViewGroup parent) {
            Item item = items.get(position);
            LayoutInflater inf = LayoutInflater.from(MainActivity.this);

            if (item.type == TYPE_SEPARATOR) {
                TextView tv = (TextView) inf.inflate(android.R.layout.simple_list_item_1,
                        parent, false);
                tv.setText(item.label);
                tv.setTextColor(0xFF8BC34A);
                tv.setBackgroundColor(0xFF222222);
                tv.setTextSize(13);
                tv.setEnabled(false);
                tv.setPadding(dp(16), dp(4), dp(16), dp(4));
                return tv;
            }

            TextView tv = (TextView) inf.inflate(
                    android.R.layout.simple_list_item_activated_1, parent, false);
            tv.setText(item.label);
            tv.setTextSize(16);
            tv.setPadding(dp(16), dp(10), dp(16), dp(10));

            if (item.highlight) {
                // 当前选中的存储设备
                tv.setTextColor(0xFF8BC34A);
                tv.setBackgroundColor(0xFF1A3A0E);
            } else {
                tv.setTextColor(0xFFEEEEEE);
            }
            return tv;
        }
    }

    private int dp(int v) {
        return (int) (v * getResources().getDisplayMetrics().density + 0.5f);
    }

    // ==================== 操作 ====================

    private void confirmSelection() {
        if (currentDir == null) return;
        List<File> videos = VideoScanner.scan(currentDir);
        if (videos.isEmpty()) {
            Toast.makeText(this, R.string.no_videos_found, Toast.LENGTH_SHORT).show();
            return;
        }
        prefs.setFolder(currentDir.getAbsolutePath());
        launchPlayer(videos);
    }

    private void launchPlayer(List<File> videos) {
        ArrayList<String> paths = new ArrayList<>(videos.size());
        for (File f : videos) paths.add(f.getAbsolutePath());

        Intent intent = new Intent(this, PlayerActivity.class);
        intent.putStringArrayListExtra(PlayerActivity.EXTRA_VIDEOS, paths);
        intent.putExtra(PlayerActivity.EXTRA_SHUFFLE, prefs.isShuffleOnLaunch());
        startActivity(intent);
    }

    private void toggleShuffle() {
        prefs.setShuffleOnLaunch(!prefs.isShuffleOnLaunch());
        updateShuffleLabel();
    }

    private void updateShuffleLabel() {
        Button b = findViewById(R.id.btn_shuffle_toggle);
        b.setText(prefs.isShuffleOnLaunch() ? R.string.shuffle_on : R.string.shuffle_off);
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE)
                == PackageManager.PERMISSION_GRANTED) {
            List<StorageUtils.StorageDevice> devs = StorageUtils.getAvailableStorages(this);
            if (devs.size() != storageDevices.size()) {
                storageDevices = devs;
                if (currentDir != null) rebuildList();
            }
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQ_PERMISSION
                && grantResults.length > 0
                && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            startBrowsing();
        } else {
            Toast.makeText(this, R.string.permission_denied, Toast.LENGTH_LONG).show();
            finish();
        }
    }
}
