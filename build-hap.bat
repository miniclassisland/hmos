@echo off
set "NODE_HOME=D:\huawei\DevEco Studio\tools\node"
set "JAVA_HOME=D:\huawei\DevEco Studio\jbr"
set "DEVECO_SDK_HOME=D:\huawei\DevEco Studio\sdk"
set "PATH=%NODE_HOME%;%JAVA_HOME%\bin;%PATH%"
cd /d "d:\.dev\miniclassisland\hmos"
call "D:\huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
if exist ".hvigor" rmdir /s /q ".hvigor"
if exist "entry\build\default\intermediates" rmdir /s /q "entry\build\default\intermediates"
if exist "entry\build\default\cache" rmdir /s /q "entry\build\default\cache"
