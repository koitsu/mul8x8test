@echo off
set NAME=mul8x8test
set ROMFILE=%NAME%.nes

:: ca65/ld65 flags

set CFLAGS=-g -l %NAME%.lst
set LDFLAGS=-m %NAME%.map -Ln %NAME%.lbl --dbgfile %NAME%.dbg

:: Main build process

ca65.exe %CFLAGS% -o %NAME%.o %NAME%.asm             || goto :error
ld65.exe %LDFLAGS% -C ld65.cfg -o %ROMFILE% %NAME%.o || goto :error
goto :end

:: Error "handler", if you can call it that

:error
set errno=%errorlevel%
echo.
echo ------------------------------------------------------
echo Build failed, error code %errno%
echo Review above output for details/last command/etc.
echo ------------------------------------------------------
exit /b %errno%

:end
