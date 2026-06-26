#if OS == .LINUX #load "linux.jai";
#if OS == .MACOS #load "macos.jai";
#if OS == .WINDOWS {
    init :: () {
        // Default Runtime_Support_Crash_Handler should be enough probably, I only have problems on Linux
    }
}
