#if OS == .LINUX {
    #load "linux.jai";
} else {
    init :: () {
        // Default Runtime_Support_Crash_Handler should be enough probably, I only have problems on Linux
    }
}
