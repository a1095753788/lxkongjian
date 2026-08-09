package com.novabox.player;

import android.content.Context;
import android.os.Environment;
import android.os.storage.StorageManager;
import android.os.storage.StorageVolume;

import java.io.File;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/**
 * 检测所有可用的存储设备（内部存储 + 外置 USB 硬盘 + SD 卡）。
 * <p>
 * 机顶盒上的外置硬盘通常挂载在 /storage/XXXX-XXXX 或 /mnt/ 下，
 * 这里用三种方式合并检测，确保不遗漏：
 * 1. StorageManager 官方 API
 * 2. 扫描 /storage/ 目录下的挂载点
 * 3. 扫描常见 /mnt/ 挂载点
 */
public final class StorageUtils {

    private StorageUtils() {}

    /** 存储设备信息 */
    public static class StorageDevice {
        public final File path;
        public final String label;

        public StorageDevice(File path, String label) {
            this.path = path;
            this.label = label;
        }
    }

    public static List<StorageDevice> getAvailableStorages(Context ctx) {
        Set<String> seenPaths = new LinkedHashSet<>();
        List<StorageDevice> result = new ArrayList<>();

        // 1. 内部存储
        File internal = Environment.getExternalStorageDirectory();
        if (internal != null && internal.canRead()) {
            addDevice(result, seenPaths, internal, "内部存储");
        }

        // 2. StorageManager 获取所有存储卷
        try {
            StorageManager sm = (StorageManager) ctx.getSystemService(Context.STORAGE_SERVICE);
            if (sm != null) {
                List<StorageVolume> volumes = sm.getStorageVolumes();
                for (StorageVolume vol : volumes) {
                    if (!"mounted".equals(vol.getState())) continue;
                    File f = getVolumePath(vol);
                    if (f != null && f.canRead()) {
                        String desc;
                        try {
                            desc = vol.getDescription(ctx);
                        } catch (Exception e) {
                            desc = f.getName();
                        }
                        addDevice(result, seenPaths, f, desc);
                    }
                }
            }
        } catch (Exception ignored) {
        }

        // 3. 扫描 /storage/ 目录（外置 USB / SD 卡常见挂载点）
        scanDir(new File("/storage"), result, seenPaths);

        // 4. 扫描常见 /mnt 挂载点
        scanDir(new File("/mnt"), result, seenPaths);

        return result;
    }

    private static void scanDir(File dir, List<StorageDevice> result, Set<String> seen) {
        File[] children = dir.listFiles();
        if (children == null) return;
        for (File f : children) {
            if (!f.isDirectory() || !f.canRead()) continue;
            String name = f.getName();
            // 跳过系统目录
            if (name.equals("emulated") || name.equals("self") || name.equals("asec")
                    || name.equals("obb") || name.equals("secure") || name.equals("shell")
                    || name.startsWith(".")) {
                continue;
            }
            // 外置存储常见命名：XXXX-XXXX (FAT格式) 或 usb_xxx
            if (name.matches("[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}")) {
                addDevice(result, seen, f, "外置存储 " + name);
            } else if (name.toLowerCase().contains("usb")) {
                addDevice(result, seen, f, "USB " + name);
            } else if (name.toLowerCase().contains("sd") || name.toLowerCase().contains("ext")) {
                addDevice(result, seen, f, "SD卡 " + name);
            } else if (f.list() != null && f.list().length > 0) {
                // 其他有内容的目录也可能是挂载的存储
                addDevice(result, seen, f, name);
            }
        }
    }

    /** 用反射获取 StorageVolume 的真实路径（API 24 上 getPathFile 被隐藏）。 */
    private static File getVolumePath(StorageVolume volume) {
        try {
            Method getPathFile = volume.getClass().getMethod("getPathFile");
            return (File) getPathFile.invoke(volume);
        } catch (Exception e1) {
            try {
                Method getPath = volume.getClass().getMethod("getPath");
                String path = (String) getPath.invoke(volume);
                return path != null ? new File(path) : null;
            } catch (Exception e2) {
                return null;
            }
        }
    }

    private static void addDevice(List<StorageDevice> result, Set<String> seen,
                                  File path, String label) {
        try {
            String canonical = path.getCanonicalPath();
            if (seen.contains(canonical)) return;
            seen.add(canonical);
            result.add(new StorageDevice(new File(canonical), label));
        } catch (Exception ignored) {
        }
    }
}
