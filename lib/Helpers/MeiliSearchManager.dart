import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:golden_shamela/Services/AppStoragePaths.dart';

class MeiliSearchManager {
  static final MeiliSearchManager _instance = MeiliSearchManager._internal();
  factory MeiliSearchManager() => _instance;
  MeiliSearchManager._internal();

  Process? _meiliProcess; // Made private
  String? _lastError;

  String? getLastError() => _lastError;
  bool get isMeiliSearchRunning => _meiliProcess != null;

  Future<bool> startMeiliSearch() async {
    if (_meiliProcess != null) {
      print("MeiliSearchManager: MeiliSearch process is already running.");
      return true;
    }

    _lastError = null; // Clear previous error

    String exePath = p.join(Directory.current.path, 'assets', 'exe', 'meilisearch.exe');
    String dataPath = AppStoragePaths.meiliDataPath;
    await Directory(dataPath).create(recursive: true);

    print("MeiliSearchManager: Attempting to start MeiliSearch...");
    print("MeiliSearchManager: Executable path: $exePath");
    print("MeiliSearchManager: Data path: $dataPath");

    const int maxRetries = 3;
    const Duration retryDelay = Duration(seconds: 2);

    for (int i = 0; i < maxRetries; i++) {
      try {
        _meiliProcess = await Process.start(
          exePath,
          [
            '--db-path', dataPath,
            '--http-addr', '127.0.0.1:7700',
            '--no-analytics',
            '--experimental-contains-filter',
            // '--master-key', 'aMasterKey' // Optional: for production
          ],
        );

        _meiliProcess!.stderr.transform(utf8.decoder).listen((data) {
          _lastError = data;
          print('MeiliSearch stderr: $data');
        });

        _meiliProcess!.stdout.transform(utf8.decoder).listen((data) {
          // print('MeiliSearch stdout: $data');
        });

        print("MeiliSearchManager: MeiliSearch process started with PID: ${_meiliProcess!.pid}");

        // Add a health check to ensure MeiliSearch is actually ready
        if (await _waitForMeiliSearchReady()) {
          print("MeiliSearchManager: MeiliSearch is ready.");
          return true;
        } else {
          _lastError = "MeiliSearch process started but did not become ready.";
          print("MeiliSearchManager: $_lastError");
          stopMeiliSearch(); // Kill the process if it's not ready
          return false;
        }

      } on ProcessException catch (e) {
        _lastError = "Failed to start MeiliSearch executable: ${e.message}";
        print("MeiliSearchManager: Error starting MeiliSearch process: $_lastError");
        if (e.message.contains("10048") && i < maxRetries - 1) { // OS Error 10048 is "port already in use"
          print("MeiliSearchManager: Port 7700 in use. Retrying in ${retryDelay.inSeconds} seconds...");
          await Future.delayed(retryDelay);
        } else {
          return false;
        }
      } catch (e) {
        _lastError = "An unexpected error occurred while starting MeiliSearch: $e";
        print("MeiliSearchManager: Error starting MeiliSearch process: $_lastError");
        return false;
      }
    }
    _lastError = "MeiliSearch failed to start after $maxRetries attempts. Port 7700 might be in use.";
    return false;
  }

  Future<bool> _waitForMeiliSearchReady() async {
    const String healthUrl = 'http://127.0.0.1:7700/health';
    const int maxHealthChecks = 10;
    const Duration healthCheckDelay = Duration(seconds: 1);

    for (int i = 0; i < maxHealthChecks; i++) {
      try {
        final response = await http.get(Uri.parse(healthUrl));
        if (response.statusCode == 200) {
          return true; // MeiliSearch is ready
        }
      } catch (e) {
        // Connection refused or other network error, MeiliSearch is not ready yet
      }
      print("MeiliSearchManager: Waiting for MeiliSearch to be ready... (attempt ${i + 1}/$maxHealthChecks)");
      await Future.delayed(healthCheckDelay);
    }
    return false; // MeiliSearch did not become ready within the timeout
  }

  void stopMeiliSearch() {
    if (_meiliProcess != null) {
      print("MeiliSearchManager: Stopping MeiliSearch process...");
      _meiliProcess!.kill();
      _meiliProcess = null;
      _lastError = null;
      print("MeiliSearchManager: MeiliSearch process stopped.");
    }
  }
}
