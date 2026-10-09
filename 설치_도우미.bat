@echo off
chcp 65001 >nul
setlocal EnableExtensions
title 나만의 인공지능 - 설치 도우미
cd /d "%~dp0"

rem ============================================================
rem  나만의 인공지능 - 실습 PC 설치 도우미
rem  1) Ollama 설치/업데이트  2) 브라우저 연결 허용 변수 등록
rem  3) Ollama 다시 시작      4) 모델 받기 (USB 복사본 우선)
rem  5) 실습 파일 바탕화면 복사 6) 모델 예열
rem  관리자 권한 없이 실행돼요. 이 파일을 더블클릭하세요.
rem ============================================================

set "MODEL=exaone3.5:2.4b"
set "EMBED=bge-m3"
set "MIN_VER=0.12.11"
set "HTML=나만의 인공지능.html"
set "OLLAMA_DIR=%LOCALAPPDATA%\Programs\Ollama"
set "OLLAMA_EXE=%OLLAMA_DIR%\ollama.exe"
set "OLLAMA_APP=%OLLAMA_DIR%\ollama app.exe"
set "URL=http://127.0.0.1:11434"
set "PROBLEM=0"

echo.
echo  ==================================================
echo    나만의 인공지능 - 실습 PC 설치 도우미
echo  ==================================================
echo   모델: %MODEL%
echo   창을 닫지 말고 끝날 때까지 기다려 주세요.
echo.

rem ---------- 1. Ollama 설치 확인 ----------
echo [1/6] Ollama 설치 확인 중...
if not exist "%OLLAMA_EXE%" (
  for /f "delims=" %%P in ('where ollama 2^>nul') do set "OLLAMA_EXE=%%P"
)
if not exist "%OLLAMA_EXE%" goto install_ollama

powershell -NoProfile -Command "$v = (& '%OLLAMA_EXE%' --version 2>&1) -join ' '; if ($v -match '(\d+\.\d+\.\d+)') { if ([version]$matches[1] -lt [version]'%MIN_VER%') { exit 1 } else { Write-Host ('      설치된 버전: ' + $matches[1]); exit 0 } } else { exit 0 }"
if errorlevel 1 (
  echo       버전이 %MIN_VER%보다 낮아요. 새 버전으로 업데이트할게요.
  goto install_ollama
)
echo       Ollama가 이미 설치되어 있어요.
goto origins

:install_ollama
echo       Ollama를 내려받는 중... 몇 분 걸릴 수 있어요.
curl.exe -L --fail -o "%TEMP%\OllamaSetup.exe" https://ollama.com/download/OllamaSetup.exe
if errorlevel 1 (
  echo.
  echo   [X] Ollama를 내려받지 못했어요. 인터넷 연결을 확인하거나
  echo       https://ollama.com/download 에서 직접 설치한 뒤 이 파일을 다시 실행하세요.
  goto fail
)
echo       설치하는 중...
"%TEMP%\OllamaSetup.exe" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
set "OLLAMA_EXE=%OLLAMA_DIR%\ollama.exe"
if not exist "%OLLAMA_EXE%" (
  echo   [X] 설치가 끝나지 않았어요. OllamaSetup.exe를 직접 실행해 주세요: %TEMP%\OllamaSetup.exe
  goto fail
)
echo       설치 완료!

rem ---------- 2. 환경 변수 등록 ----------
:origins
echo.
echo [2/6] 브라우저 연결 허용 설정 중...
setx OLLAMA_ORIGINS "*" >nul
setx OLLAMA_KEEP_ALIVE "2h" >nul
set "OLLAMA_ORIGINS=*"
set "OLLAMA_KEEP_ALIVE=2h"
echo       OLLAMA_ORIGINS = *   (바탕화면 HTML 파일이 AI에 연결돼요)
echo       OLLAMA_KEEP_ALIVE = 2h (수업 중 모델을 메모리에 계속 올려 둬요)

rem ---------- 3. Ollama 다시 시작 ----------
echo.
echo [3/6] Ollama 다시 시작 중...
taskkill /F /IM "ollama app.exe" >nul 2>&1
taskkill /F /IM "ollama.exe" >nul 2>&1
timeout /t 2 /nobreak >nul
if exist "%OLLAMA_APP%" (
  start "" "%OLLAMA_APP%"
) else (
  start "" /min "%OLLAMA_EXE%" serve
)
set /a TRIES=0
:wait_server
set /a TRIES+=1
curl.exe -s -o nul --max-time 2 %URL%/api/version
if not errorlevel 1 goto server_up
if %TRIES% geq 40 (
  echo   [X] Ollama가 켜지지 않아요. 작업표시줄의 라마 아이콘을 확인하고 PC를 재부팅한 뒤 다시 실행하세요.
  goto fail
)
timeout /t 1 /nobreak >nul
goto wait_server
:server_up
echo       Ollama가 켜졌어요.

rem ---------- 4. 모델 받기 ----------
echo.
echo [4/6] 모델 확인 중...
if exist "%~dp0models\manifests" (
  echo       USB의 models 폴더를 찾았어요. 복사하는 중... ^(인터넷보다 빨라요^)
  robocopy "%~dp0models" "%USERPROFILE%\.ollama\models" /E /NFL /NDL /NJH /NJS /NP >nul
)
"%OLLAMA_EXE%" list | findstr /I /C:"%MODEL%" >nul
if not errorlevel 1 (
  echo       %MODEL% 모델이 이미 있어요.
  goto embed_model
)
echo       %MODEL% 모델을 내려받는 중... (약 1.6GB)
"%OLLAMA_EXE%" pull %MODEL%
if errorlevel 1 (
  echo   [X] 모델을 받지 못했어요. 인터넷 연결을 확인하고 다시 실행하세요.
  goto fail
)

:embed_model
"%OLLAMA_EXE%" list | findstr /I /C:"%EMBED%" >nul
if not errorlevel 1 (
  echo       %EMBED% 의미 지도용 모델도 있어요.
  goto copy_html
)
echo.
choice /C YN /T 15 /D N /M "      의미 지도를 더 정확하게 해 주는 %EMBED% 모델(약 1.2GB)도 받을까요? 15초 안에 고르지 않으면 건너뛰어요"
if errorlevel 2 (
  echo       건너뛰었어요. 없어도 수업 진행에는 문제없어요.
  goto copy_html
)
"%OLLAMA_EXE%" pull %EMBED%

rem ---------- 5. 실습 파일 바탕화면에 복사 ----------
:copy_html
echo.
echo [5/6] 실습 파일 복사 중...
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"`) do set "DESKTOP=%%D"
if exist "%~dp0%HTML%" (
  copy /Y "%~dp0%HTML%" "%DESKTOP%\%HTML%" >nul
  echo       바탕화면에 "%HTML%" 을 놓았어요.
) else (
  echo       이 폴더에 "%HTML%" 이 없어서 건너뛰었어요. 파일을 바탕화면에 직접 놓아 주세요.
)

rem ---------- 6. 모델 예열 ----------
echo.
echo [6/6] 모델 예열 중... (처음 한 번은 10~30초 걸려요)
curl.exe -s -o nul --max-time 180 %URL%/api/generate -d "{\"model\":\"%MODEL%\",\"prompt\":\"hi\",\"stream\":false}"
if errorlevel 1 (
  echo       예열하지 못했어요. 수업 때 첫 대답이 조금 느릴 수 있어요.
  set "PROBLEM=1"
) else (
  echo       준비 완료! 첫 대답이 빨라져요.
)

rem ---------- 결과 ----------
echo.
echo  ==================================================
if "%PROBLEM%"=="0" (
  echo    모두 끝났어요!
) else (
  echo    거의 끝났어요. 위의 안내를 확인해 주세요.
)
echo  ==================================================
powershell -NoProfile -Command "$v = (& '%OLLAMA_EXE%' --version 2>&1) -join ' '; if ($v -match '(\d+\.\d+\.\d+)') { Write-Host ('   Ollama 버전 : ' + $matches[1]) }"
echo    모델 목록    :
"%OLLAMA_EXE%" list
echo.
echo    이제 바탕화면의 "%HTML%" 을 더블클릭하고
echo    오른쪽 위에 "AI 연결됨" 이 보이는지 확인하세요.
echo.
pause
exit /b 0

:fail
echo.
echo  ==================================================
echo    설치를 마치지 못했어요. 위의 [X] 안내를 확인해 주세요.
echo  ==================================================
echo.
pause
exit /b 1
