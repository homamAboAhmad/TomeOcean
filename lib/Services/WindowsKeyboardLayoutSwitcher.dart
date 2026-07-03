import 'dart:ffi';
import 'dart:io';

class WindowsKeyboardLayoutSwitcher {
  static void switchToArabic() {
    if (!Platform.isWindows) return;
    try {
      final user32 = DynamicLibrary.open('user32.dll');
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      final getProcessHeap = kernel32.lookupFunction<IntPtr Function(),
          int Function()>('GetProcessHeap');
      final heapAlloc = kernel32.lookupFunction<
          Pointer<Void> Function(IntPtr, Uint32, IntPtr),
          Pointer<Void> Function(int, int, int)>('HeapAlloc');
      final heapFree = kernel32.lookupFunction<
          Int32 Function(IntPtr, Uint32, Pointer<Void>),
          int Function(int, int, Pointer<Void>)>('HeapFree');
      final loadKeyboardLayout = user32.lookupFunction<
          IntPtr Function(Pointer<Uint16>, Uint32),
          int Function(Pointer<Uint16>, int)>('LoadKeyboardLayoutW');
      final activateKeyboardLayout = user32.lookupFunction<
          IntPtr Function(IntPtr, Uint32),
          int Function(int, int)>('ActivateKeyboardLayout');

      final heap = getProcessHeap();
      final pointer = heapAlloc(heap, 0, 18).cast<Uint16>();
      const layout = '00000401';
      for (var i = 0; i < layout.length; i++) {
        pointer[i] = layout.codeUnitAt(i);
      }
      pointer[layout.length] = 0;
      final handle = loadKeyboardLayout(pointer, 1);
      if (handle != 0) activateKeyboardLayout(handle, 0);
      heapFree(heap, 0, pointer.cast<Void>());
    } catch (_) {}
  }
}
