import 'dart:convert';
import 'dart:io';

import 'package:golden_shamela/Services/WindowsKeyboardLayoutSwitcher.dart';
import 'package:golden_shamela/UI/Settings/app_other_settings.dart';

class WindowsStartupActions {
  static Future<void> applyAtStartup() async {
    final settings = AppOtherSettings.instance.draft();
    if (settings.switchKeyboardToArabicOnStartup) {
      WindowsKeyboardLayoutSwitcher.switchToArabic();
    }
    if (settings.createDesktopShortcut || settings.createStartMenuShortcut) {
      await createShortcutsIfMissing();
    }
  }

  static Future<void> applyAfterSettingsSave() async {
    final settings = AppOtherSettings.instance.draft();
    if (settings.createDesktopShortcut || settings.createStartMenuShortcut) {
      await createShortcutsIfMissing();
    }
  }

  static Future<void> createShortcutsIfMissing() async {
    if (!Platform.isWindows) return;
    try {
      final settings = AppOtherSettings.instance.draft();
      final exe = Platform.resolvedExecutable;
      final workDir = File(exe).parent.path;
      final desktop = settings.createDesktopShortcut ? r'''
CreateShortcut ([Environment]::GetFolderPath('DesktopDirectory'))
CreateShortcut (Join-Path $env:USERPROFILE 'Desktop')
''' : '';
      final startMenu = settings.createStartMenuShortcut ? r'''
CreateShortcut ([Environment]::GetFolderPath('Programs'))
CreateShortcut (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs')
''' : '';
      final script = '''
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
[ComImport, Guid("00021401-0000-0000-C000-000000000046")]
class ShellLink {}
[ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("000214F9-0000-0000-C000-000000000046")]
interface IShellLinkW {
  void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszFile, int cchMaxPath, IntPtr pfd, uint fFlags);
  void GetIDList(out IntPtr ppidl);
  void SetIDList(IntPtr pidl);
  void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszName, int cchMaxName);
  void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);
  void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszDir, int cchMaxPath);
  void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);
  void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszArgs, int cchMaxPath);
  void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);
  void GetHotkey(out short pwHotkey);
  void SetHotkey(short wHotkey);
  void GetShowCmd(out int piShowCmd);
  void SetShowCmd(int iShowCmd);
  void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszIconPath, int cchIconPath, out int piIcon);
  void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string pszIconPath, int iIcon);
  void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string pszPathRel, uint dwReserved);
  void Resolve(IntPtr hwnd, uint fFlags);
  void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
}
[ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("0000010b-0000-0000-C000-000000000046")]
interface IPersistFile {
  void GetClassID(out Guid pClassID);
  int IsDirty();
  void Load([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, uint dwMode);
  void Save([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, bool fRemember);
  void SaveCompleted([MarshalAs(UnmanagedType.LPWStr)] string pszFileName);
  void GetCurFile([MarshalAs(UnmanagedType.LPWStr)] out string ppszFileName);
}
public static class ShortcutCreator {
  public static void Create(string linkPath, string targetPath, string workingDirectory) {
    object raw = new ShellLink();
    try {
      IShellLinkW link = (IShellLinkW)raw;
      link.SetPath(targetPath);
      link.SetWorkingDirectory(workingDirectory);
      link.SetIconLocation(targetPath, 0);
      ((IPersistFile)link).Save(linkPath, true);
    } finally {
      Marshal.FinalReleaseComObject(raw);
    }
  }
}
'@
\$exePath = '${_escape(exe)}'
\$workDir = '${_escape(workDir)}'
function CreateShortcut([string]\$folder) {
  if ([string]::IsNullOrWhiteSpace(\$folder)) { return }
  if (-not (Test-Path -LiteralPath \$folder)) { return }
  \$shortcutName = [string]::Concat([char]0x0627,[char]0x0644,[char]0x0645,[char]0x0643,[char]0x062a,[char]0x0628,[char]0x0629,'.lnk')
  \$shortcutPath = Join-Path \$folder \$shortcutName
  if (Test-Path -LiteralPath \$shortcutPath) { Remove-Item -LiteralPath \$shortcutPath -Force }
  [ShortcutCreator]::Create(\$shortcutPath, \$exePath, \$workDir)
}
$desktop
$startMenu
''';
      await Process.run(_powershellPath, [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-EncodedCommand',
        _encodedPowerShell(script),
      ]);
    } catch (_) {}
  }

  static String _escape(String value) => value.replaceAll("'", "''");

  static String get _powershellPath {
    final root = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    return '$root\\System32\\WindowsPowerShell\\v1.0\\powershell.exe';
  }

  static String _encodedPowerShell(String script) {
    final bytes = <int>[];
    for (final unit in script.codeUnits) {
      bytes.add(unit & 0xff);
      bytes.add(unit >> 8);
    }
    return base64Encode(bytes);
  }
}
