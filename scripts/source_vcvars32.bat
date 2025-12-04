:: Put this file next to 'find_windows_dev_kit.exe'
FOR /F "tokens=* USEBACKQ" %%V IN (`%~dp0\find_windows_dev_kit.exe vcvars32`) do ("%%V")
