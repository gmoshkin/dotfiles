main :: () {
    status: SYSTEM_POWER_STATUS;

    ok := GetSystemPowerStatus(*status);
    if !ok {
        code, message := System.get_error_value_and_string();
        print("Failed to get power status: #% %\n", code, message, to_standard_error=true);
        exit(1);
    }

    if (status.BatteryLifePercent == 255) {
        // 255 indicates unknown or no battery
        print("?\%\n");
    } else {
        print("%\%\n", status.BatteryLifePercent);
    }
}

#if OS == .WINDOWS {
    #import "Windows";

    SYSTEM_POWER_STATUS :: struct {
        ACLineStatus: u8;
        BatteryFlag: u8;
        BatteryLifePercent: u8;
        SystemStatusFlag: u8;
        BatteryLifeTime: DWORD;
        BatteryFullLifeTime: DWORD;
    }
    GetSystemPowerStatus :: (lpSystemPowerStatus: *SYSTEM_POWER_STATUS) -> BOOL #foreign kernel32;
    kernel32 :: #library,system "kernel32";
}

#import "Basic";
System :: #import "System";
