package com.novabox.player;

import java.io.File;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/**
 * Scans a local folder for video files.
 * <p>
 * Inspired by Nova Video Player's MediaStore-based scanning (aos-Video's VideoLoader),
 * but uses direct File traversal so it works on Android 7.0 TV boxes without
 * depending on the Media indexer being up to date.
 */
public final class VideoScanner {

    /** Common video file extensions. */
    private static final Set<String> VIDEO_EXTS = new HashSet<>(Arrays.asList(
            "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "3gp", "mpeg",
            "mpg", "m4v", "ts", "m2ts", "vob", "ogv", "rmvb", "rm", "f4v"
    ));

    private VideoScanner() {}

    public static boolean isVideoFile(File file) {
        if (file == null || !file.isFile()) return false;
        String name = file.getName();
        int dot = name.lastIndexOf('.');
        if (dot < 0 || dot == name.length() - 1) return false;
        String ext = name.substring(dot + 1).toLowerCase(Locale.US);
        return VIDEO_EXTS.contains(ext);
    }

    /**
     * Recursively scan the folder and return all video files found.
     * Results are sorted by name for a deterministic starting order.
     */
    public static List<File> scan(File rootDir) {
        List<File> result = new ArrayList<>();
        if (rootDir == null || !rootDir.isDirectory()) return result;
        traverse(rootDir, result);
        Collections.sort(result, (a, b) -> a.getName().compareToIgnoreCase(b.getName()));
        return result;
    }

    private static void traverse(File dir, List<File> out) {
        File[] children = dir.listFiles();
        if (children == null) return;
        for (File f : children) {
            if (f.isDirectory()) {
                // skip hidden / system folders
                if (!f.isHidden()) traverse(f, out);
            } else if (isVideoFile(f)) {
                out.add(f);
            }
        }
    }

    /** Count of sub-folders for the browser display. */
    public static int countSubFolders(File dir) {
        File[] children = dir.listFiles(File::isDirectory);
        return children == null ? 0 : children.length;
    }
}
