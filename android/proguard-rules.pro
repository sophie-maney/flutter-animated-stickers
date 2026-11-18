# Consumer R8 rules: JNI looks these up by name (src/main/cpp/jni_bridge.cc).
-keep class town.leggy.animated_stickers.WtNative {
    native <methods>;
}
-keep interface town.leggy.animated_stickers.NativeErrorListener { *; }
-keepclassmembers class * implements town.leggy.animated_stickers.NativeErrorListener {
    void onNativeError(java.lang.String, java.lang.String);
}
