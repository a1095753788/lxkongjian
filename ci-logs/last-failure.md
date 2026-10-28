# 构建失败日志

run: https://github.com/a1095753788/lxkongjian/actions/runs/40657062474

## 错误关键行
```
14:FAILURE: Build failed with an exception.
18:> Could not resolve all artifacts for configuration 'classpath'.
19:   > Could not find org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.3.72.
37:   > Could not find org.ow2.asm:asm:7.0.
43:   > Could not find org.ow2.asm:asm-analysis:7.0.
48:   > Could not find org.ow2.asm:asm-commons:7.0.
54:   > Could not find org.ow2.asm:asm-util:7.0.
60:   > Could not find net.sf.jopt-simple:jopt-simple:4.9.
64:   > Could not find net.sf.proguard:proguard-gradle:6.0.3.
69:   > Could not find com.squareup:javapoet:1.10.0.
73:   > Could not find com.google.protobuf:protobuf-java:3.10.0.
83:   > Could not find com.google.protobuf:protobuf-java-util:3.10.0.
88:   > Could not find com.google.crypto.tink:tink:1.3.0-rc2.
93:   > Could not find com.google.flatbuffers:flatbuffers-java:1.12.0.
96:   > Could not find org.tensorflow:tensorflow-lite-metadata:0.1.0-rc1.
101:   > Could not find com.squareup:javawriter:2.5.0.
104:   > Could not find org.bouncycastle:bcpkix-jdk15on:1.56.
111:   > Could not find org.bouncycastle:bcprov-jdk15on:1.56.
118:   > Could not find org.ow2.asm:asm-tree:7.0.
123:   > Could not find javax.inject:javax.inject:1.
127:   > Could not find it.unimi.dsi:fastutil:7.2.0.
132:   > Could not find com.googlecode.json-simple:json-simple:1.1.
137:   > Could not find com.google.guava:guava:28.1-jre.
149:   > Could not find org.apache.httpcomponents:httpmime:4.5.6.
153:   > Could not find org.apache.httpcomponents:httpcore:4.4.10.
159:   > Could not find org.apache.httpcomponents:httpclient:4.5.6.
164:   > Could not find org.jetbrains.kotlin:kotlin-reflect:1.3.72.
170:   > Could not find org.antlr:antlr4:4.5.3.
175:   > Could not find commons-io:commons-io:2.4.
178:   > Could not find com.googlecode.juniversalchardet:juniversalchardet:1.0.3.
181:   > Could not find com.google.code.gson:gson:2.8.5.
189:   > Could not find org.glassfish.jaxb:jaxb-runtime:2.3.1.
195:   > Could not find com.google.auto.value:auto-value-annotations:1.6.2.
198:   > Could not find com.google.errorprone:error_prone_annotations:2.3.1.
201:   > Could not find com.google.guava:guava:28.1-jre.
206:   > Could not find com.google.protobuf:protobuf-java:3.10.0.
211:   > Could not find com.google.protobuf:protobuf-java-util:3.10.0.
216:   > Could not find com.google.code.gson:gson:2.8.5.
221:   > Could not find org.jetbrains.kotlin:kotlin-stdlib:1.3.60.
227:   > Could not find org.ow2.asm:asm:7.0.
232:   > Could not find org.ow2.asm:asm-util:7.0.
237:   > Could not find org.ow2.asm:asm-commons:7.0.
242:   > Could not find org.jdom:jdom2:2.0.6.
245:   > Could not find org.apache.commons:commons-compress:1.12.
251:   > Could not find org.jetbrains.trove4j:trove4j:20160824.
256:   > Could not find net.sf.kxml:kxml2:2.3.0.
262:   > Could not find com.google.code.findbugs:jsr305:1.3.9.
267:   > Could not find com.google.guava:guava:28.1-jre.
272:   > Could not find org.jetbrains:annotations:13.0.
275:   > Could not find com.sun.activation:javax.activation:1.2.0.
278:   > Could not find com.google.jimfs:jimfs:1.1.
281:> Failed to notify project evaluation listener.
282:   > java.lang.NullPointerException (no error message)
291:   > java.lang.NullPointerException (no error message)
300:BUILD FAILED in 2m 18s
305:│ This results in a build failure when applying the Flutter Gradle plugin at           │
308:│ To resolve this update flutter or opt out of `android.newDsl`.                       │
313:│ incompatible dependencies.                                                           │
315:Gradle task assembleDebug failed with exit code 1
```

## 日志末尾 250 行
```
       - https://dl.google.com/dl/android/maven2/net/sf/proguard/proguard-gradle/6.0.3/proguard-gradle-6.0.3.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0
   > Could not find com.squareup:javapoet:1.10.0.
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > androidx.databinding:databinding-compiler-common:4.1.0
   > Could not find com.google.protobuf:protobuf-java:3.10.0.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/com/google/protobuf/protobuf-java/3.10.0/protobuf-java-3.10.0.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:aapt2-proto:4.1.0-6503028
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools:sdk-common:27.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools.ddms:ddmlib:27.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools.analytics-library:protos:27.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools.analytics-library:tracker:27.1.0
   > Could not find com.google.protobuf:protobuf-java-util:3.10.0.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/com/google/protobuf/protobuf-java-util/3.10.0/protobuf-java-util-3.10.0.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0
   > Could not find com.google.crypto.tink:tink:1.3.0-rc2.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/com/google/crypto/tink/tink/1.3.0-rc2/tink-1.3.0-rc2.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0
   > Could not find com.google.flatbuffers:flatbuffers-java:1.12.0.
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0
   > Could not find org.tensorflow:tensorflow-lite-metadata:0.1.0-rc1.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/org/tensorflow/tensorflow-lite-metadata/0.1.0-rc1/tensorflow-lite-metadata-0.1.0-rc1.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0
   > Could not find com.squareup:javawriter:2.5.0.
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0
   > Could not find org.bouncycastle:bcpkix-jdk15on:1.56.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/org/bouncycastle/bcpkix-jdk15on/1.56/bcpkix-jdk15on-1.56.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools:sdk-common:27.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools.build:apkzlib:4.1.0
   > Could not find org.bouncycastle:bcprov-jdk15on:1.56.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/org/bouncycastle/bcprov-jdk15on/1.56/bcprov-jdk15on-1.56.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools:sdk-common:27.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools.build:apkzlib:4.1.0
   > Could not find org.ow2.asm:asm-tree:7.0.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/org/ow2/asm/asm-tree/7.0/asm-tree-7.0.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0
   > Could not find javax.inject:javax.inject:1.
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools:sdk-common:27.1.0
   > Could not find it.unimi.dsi:fastutil:7.2.0.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/it/unimi/dsi/fastutil/7.2.0/fastutil-7.2.0.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0
   > Could not find com.googlecode.json-simple:json-simple:1.1.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/com/googlecode/json-simple/json-simple/1.1/json-simple-1.1.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0
   > Could not find com.google.guava:guava:28.1-jre.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/com/google/guava/guava/28.1-jre/guava-28.1-jre.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:aaptcompiler:4.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.analytics-library:crash:27.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.lint:lint-gradle-api:27.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:gradle-api:4.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > androidx.databinding:databinding-compiler-common:4.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools:common:27.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools.analytics-library:tracker:27.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools:sdk-common:27.1.0 > com.android.tools.analytics-library:shared:27.1.0
   > Could not find org.apache.httpcomponents:httpmime:4.5.6.
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.analytics-library:crash:27.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools:sdklib:27.1.0
   > Could not find org.apache.httpcomponents:httpcore:4.4.10.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/org/apache/httpcomponents/httpcore/4.4.10/httpcore-4.4.10.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.analytics-library:crash:27.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools:sdklib:27.1.0
   > Could not find org.apache.httpcomponents:httpclient:4.5.6.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/org/apache/httpcomponents/httpclient/4.5.6/httpclient-4.5.6.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.analytics-library:crash:27.1.0
   > Could not find org.jetbrains.kotlin:kotlin-reflect:1.3.72.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/org/jetbrains/kotlin/kotlin-reflect/1.3.72/kotlin-reflect-1.3.72.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.lint:lint-gradle-api:27.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools:sdk-common:27.1.0
   > Could not find org.antlr:antlr4:4.5.3.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/org/antlr/antlr4/4.5.3/antlr4-4.5.3.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > androidx.databinding:databinding-compiler-common:4.1.0
   > Could not find commons-io:commons-io:2.4.
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > androidx.databinding:databinding-compiler-common:4.1.0
   > Could not find com.googlecode.juniversalchardet:juniversalchardet:1.0.3.
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > androidx.databinding:databinding-compiler-common:4.1.0
   > Could not find com.google.code.gson:gson:2.8.5.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/com/google/code/gson/gson/2.8.5/gson-2.8.5.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > androidx.databinding:databinding-compiler-common:4.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools:sdklib:27.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools.build:manifest-merger:27.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools:sdk-common:27.1.0 > com.android.tools.analytics-library:shared:27.1.0
   > Could not find org.glassfish.jaxb:jaxb-runtime:2.3.1.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/org/glassfish/jaxb/jaxb-runtime/2.3.1/jaxb-runtime-2.3.1.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > androidx.databinding:databinding-compiler-common:4.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools:sdklib:27.1.0 > com.android.tools:repository:27.1.0
   > Could not find com.google.auto.value:auto-value-annotations:1.6.2.
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:bundletool:0.14.0
   > Could not find com.google.errorprone:error_prone_annotations:2.3.1.
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:bundletool:0.14.0
   > Could not find com.google.guava:guava:28.1-jre.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/com/google/guava/guava/28.1-jre/guava-28.1-jre.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:bundletool:0.14.0
   > Could not find com.google.protobuf:protobuf-java:3.10.0.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/com/google/protobuf/protobuf-java/3.10.0/protobuf-java-3.10.0.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:bundletool:0.14.0
   > Could not find com.google.protobuf:protobuf-java-util:3.10.0.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/com/google/protobuf/protobuf-java-util/3.10.0/protobuf-java-util-3.10.0.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:bundletool:0.14.0
   > Could not find com.google.code.gson:gson:2.8.5.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/com/google/code/gson/gson/2.8.5/gson-2.8.5.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build.jetifier:jetifier-core:1.0.0-beta09
   > Could not find org.jetbrains.kotlin:kotlin-stdlib:1.3.60.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/org/jetbrains/kotlin/kotlin-stdlib/1.3.60/kotlin-stdlib-1.3.60.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build.jetifier:jetifier-core:1.0.0-beta09
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build.jetifier:jetifier-processor:1.0.0-beta09
   > Could not find org.ow2.asm:asm:7.0.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/org/ow2/asm/asm/7.0/asm-7.0.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build.jetifier:jetifier-processor:1.0.0-beta09
   > Could not find org.ow2.asm:asm-util:7.0.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/org/ow2/asm/asm-util/7.0/asm-util-7.0.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build.jetifier:jetifier-processor:1.0.0-beta09
   > Could not find org.ow2.asm:asm-commons:7.0.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/org/ow2/asm/asm-commons/7.0/asm-commons-7.0.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build.jetifier:jetifier-processor:1.0.0-beta09
   > Could not find org.jdom:jdom2:2.0.6.
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build.jetifier:jetifier-processor:1.0.0-beta09
   > Could not find org.apache.commons:commons-compress:1.12.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/org/apache/commons/commons-compress/1.12/commons-compress-1.12.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools:sdklib:27.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools:sdklib:27.1.0 > com.android.tools:repository:27.1.0
   > Could not find org.jetbrains.trove4j:trove4j:20160824.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/org/jetbrains/trove4j/trove4j/20160824/trove4j-20160824.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools:sdk-common:27.1.0
   > Could not find net.sf.kxml:kxml2:2.3.0.
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools.build:manifest-merger:27.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools.ddms:ddmlib:27.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:aaptcompiler:4.1.0 > com.android.tools.layoutlib:layoutlib-api:27.1.0
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.lint:lint-gradle-api:27.1.0 > com.android.tools.lint:lint-model:27.1.0
   > Could not find com.google.code.findbugs:jsr305:1.3.9.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/com/google/code/findbugs/jsr305/1.3.9/jsr305-1.3.9.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools.build:apkzlib:4.1.0
   > Could not find com.google.guava:guava:28.1-jre.
     Searched in the following locations:
       - https://dl.google.com/dl/android/maven2/com/google/guava/guava/28.1-jre/guava-28.1-jre.pom
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools.build:apkzlib:4.1.0
   > Could not find org.jetbrains:annotations:13.0.
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:aaptcompiler:4.1.0 > com.android.tools.layoutlib:layoutlib-api:27.1.0
   > Could not find com.sun.activation:javax.activation:1.2.0.
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools:sdklib:27.1.0 > com.android.tools:repository:27.1.0
   > Could not find com.google.jimfs:jimfs:1.1.
     Required by:
         buildscript of project ':video_thumbnail' > com.android.tools.build:gradle:4.1.0 > com.android.tools.build:builder:4.1.0 > com.android.tools:sdklib:27.1.0 > com.android.tools:repository:27.1.0
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
> If the artifact you are trying to retrieve can be found in the repository but without metadata in 'Maven POM' format, you need to adjust the 'metadataSources { ... }' of the repository declaration.
> Run with --stacktrace option to get the stack trace.
> Run with --info or --debug option to get more log output.
> Run with --scan to generate a Build Scan (Powered by Develocity).
> Get more help at https://help.gradle.org.

BUILD FAILED in 2m 18s
Running Gradle task 'assembleDebug'...                            139.1s

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
