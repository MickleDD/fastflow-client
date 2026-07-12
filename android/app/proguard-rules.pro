# JNI seam — fastflow_jni.cpp resolves these strictly by name at runtime:
#   * JNI_OnLoad: FindClass("com/fastflow/vpn/NativeBridge") + RegisterNatives
#     against the native* externals;
#   * upcalls: GetStaticMethodID for protectSocket(I)Z / replayNetworkState()V.
# Renaming or stripping any of them turns the platform network monitor off.
-keep class com.fastflow.vpn.NativeBridge { *; }
