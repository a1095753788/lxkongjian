# 构建失败日志

run: https://github.com/a1095753788/lxkongjian/actions/runs/40656173841

## 错误关键行
```
14:FAILURE: Build completed with 2 failures.
16:1: Task failed with an exception.
23:> Could not find method jcenter() for arguments [] on repository container of type org.gradle.api.internal.artifacts.dsl.DefaultRepositoryHandler.
32:2: Task failed with an exception.
36:> Failed to notify project evaluation listener.
37:   > java.lang.NullPointerException (no error message)
46:   > java.lang.NullPointerException (no error message)
55:BUILD FAILED in 2m 12s
60:│ This results in a build failure when applying the Flutter Gradle plugin at           │
63:│ To resolve this update flutter or opt out of `android.newDsl`.                       │
68:│ incompatible dependencies.                                                           │
70:Gradle task assembleDebug failed with exit code 1
```

## 日志末尾 250 行
```
Running Gradle task 'assembleDebug'...                          
Checking the license for package NDK (Side by side) 28.2.13676358 in /usr/local/lib/android/sdk/licenses
License for package NDK (Side by side) 28.2.13676358 accepted.
Preparing "Install NDK (Side by side) 28.2.13676358 v.28.2.13676358".
"Install NDK (Side by side) 28.2.13676358 v.28.2.13676358" ready.
Installing NDK (Side by side) 28.2.13676358 in /usr/local/lib/android/sdk/ndk/28.2.13676358
"Install NDK (Side by side) 28.2.13676358 v.28.2.13676358" complete.
"Install NDK (Side by side) 28.2.13676358 v.28.2.13676358" finished.
Downloading file from: https://github.com/media-kit/libmpv-android-video-build/releases/download/v1.1.7/default-arm64-v8a.jar
Downloading file from: https://github.com/media-kit/libmpv-android-video-build/releases/download/v1.1.7/default-armeabi-v7a.jar
Downloading file from: https://github.com/media-kit/libmpv-android-video-build/releases/download/v1.1.7/default-x86_64.jar
Downloading file from: https://github.com/media-kit/libmpv-android-video-build/releases/download/v1.1.7/default-x86.jar

FAILURE: Build completed with 2 failures.

1: Task failed with an exception.
-----------
* Where:
Build file '/home/runner/.pub-cache/hosted/pub.dev/video_thumbnail-0.5.6/android/build.gradle' line: 7

* What went wrong:
A problem occurred evaluating project ':video_thumbnail'.
> Could not find method jcenter() for arguments [] on repository container of type org.gradle.api.internal.artifacts.dsl.DefaultRepositoryHandler.

* Try:
> Run with --stacktrace option to get the stack trace.
> Run with --info or --debug option to get more log output.
> Run with --scan to generate a Build Scan (Powered by Develocity).
> Get more help at https://help.gradle.org.
==============================================================================

2: Task failed with an exception.
-----------
* What went wrong:
A problem occurred configuring project ':video_thumbnail'.
> Failed to notify project evaluation listener.
   > java.lang.NullPointerException (no error message)
   > 'kotlin-android' plugin requires one of the Android Gradle plugins.
     Please apply one of the following plugins to ':video_thumbnail' project:
     - com.android.application
     	- com.android.library
     	- com.android.dynamic-feature
     	- com.android.test
     	- com.android.instantapp
     	- com.android.feature
   > java.lang.NullPointerException (no error message)

* Try:
> Run with --stacktrace option to get the stack trace.
> Run with --info or --debug option to get more log output.
> Run with --scan to generate a Build Scan (Powered by Develocity).
> Get more help at https://help.gradle.org.
==============================================================================

BUILD FAILED in 2m 12s
Running Gradle task 'assembleDebug'...                            132.7s

┌─ Flutter Fix ────────────────────────────────────────────────────────────────────────┐
│ [!] Starting AGP 9+, only the new DSL interface will be read.                        │
│ This results in a build failure when applying the Flutter Gradle plugin at           │
│ /home/runner/work/lxkongjian/lxkongjian/local_douyin/android/app/build.gradle.kts.   │
│                                                                                      │
│ To resolve this update flutter or opt out of `android.newDsl`.                       │
│ For instructions on how to opt out, see:                                             │
│ https://developer.android.com/build/releases/agp-9-0-0-release-notes                 │
│                                                                                      │
│ If you are not upgrading to AGP 9+, run `flutter analyze --suggestions` to check for │
│ incompatible dependencies.                                                           │
└──────────────────────────────────────────────────────────────────────────────────────┘
Gradle task assembleDebug failed with exit code 1
```
