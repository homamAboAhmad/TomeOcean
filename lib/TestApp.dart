import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Helpers/ExeRunner.dart';
import 'package:golden_shamela/Utils/NumberUtils.dart';
import 'package:process_run/shell.dart';

import 'Constants.dart';
import 'Controllers/PathController.dart';

const pythonCodePath = "D:\\0templates\\pythonAddWordBr\\main.py";
String exFilePath = "D:\\..templates\\pythonProject\\ex2.docx";

showFileProcessDailog(BuildContext context, String filePath,
    {bool? update}) async {
  return await showDialog(
      context: context,
      builder: (c) {
        return AlertDialog(
          content: FileProcessingDialog(filePath, update: update),
        );
      });
}

class FileProcessingDialog extends StatefulWidget {
  String filePath;
  bool? update;

  FileProcessingDialog(this.filePath, {this.update});

  @override
  _FileProcessingDialogState createState() => _FileProcessingDialogState();
}

class _FileProcessingDialogState extends State<FileProcessingDialog> {
  double progress = 0.0;
  String jsonFilePath = "";
  String txtFilePath = "";
  ShellLinesController controller = ShellLinesController();

  Future<void> processFile(String filePath) async {
    await ExeRunner().runExe(BOOKS_FOLDER_PATH, filePath,(opt){
      output = opt.split("\n")[0];
      _updateProgress("progress:${progress + 0.1}");

    });
    _finishProgress();
    Navigator.of(context).pop(null);

    return;
    try {
      // _clearProgress();
      _addShellWatcher();
      await _startShellProcess(filePath);
      _finishProgress();
      _returnResult();
    } catch (e) {
      print("Error: $e");
      _clearProgress();
      _returnError();
    }
  }

  String output = "...";

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(child: FittedBox(child: Text( output,style: TextStyle(color: Colors.black,fontSize: 16,fontFamily: 'jreg'),))),
          ),
          LinearProgressIndicator(value: progress),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    if (alreadyExists(widget.filePath) && widget.update != true)
      _returnResult();
    else
      processFile(widget.filePath);
  }

  void _clearProgress() {
    setState(() {
      progress = 0.0;
    });
  }

  _addShellWatcher() {
    controller.stream.listen((line) {

       _updateProgress("progress:${progress + 0.1}");
      // bool isProgresLine = line.contains("progress:");
      // if (isProgresLine) {
      //    _updateProgress(line);
      // } else {
      //   print("line: $line");
      //   setState(() {
      //     output = line;
      //   });
      // }


    });
  }

  void _finishProgress() {
    setState(() {
      progress = 1.0;
    });
  }

  _startShellProcess(String filePath) async {
    var shell =
        Shell(stdoutEncoding: const Utf8Codec(), stdout: controller.sink);
    await shell.runExecutableArguments(
      'python',
      ['-u', pythonCodePath, BOOKS_FOLDER_PATH, filePath],
    );
    }

  void _updateProgress(String line) {
    String progressString = line.split("progress:")[1];
    progress = double.parse(progressString);
    setState(() {
      print(progress);
    });
  }

  void _updateJsonFilePath(line) {
    setState(() {
      jsonFilePath = line.replaceFirst("JSON file saved at: ", "").trim();
    });
  }

  void _updateTxtFilePath(String line) {
    setState(() {
      txtFilePath = line.replaceFirst("TXT file saved at: ", "").trim();
    });
  }

  void _returnResult() {
    var resultMap = {
      // 'jsonFilePath':jsonFilePath,
      'txtFilePath': txtFilePath
    };
    Navigator.of(context).pop(resultMap);
  }

  void _returnError() {
    Navigator.of(context).pop(null);
  }

  bool alreadyExists(String filePath) {
    // bool jsonFileExists =File(filePath.replaceFirst(".docx", "_pages.json")).existsSync();
    // if(jsonFileExists)
    //   jsonFilePath = filePath.replaceFirst(".docx", "_pages.json");
    bool txtFileExists =
        File(filePath.replaceFirst(".docx", "_pages.txt")).existsSync();
    if (txtFileExists)
      txtFilePath = filePath.replaceFirst(".docx", "_pages.txt");

    return /*jsonFileExists&&*/ txtFileExists;
  }
}

getTxtFilePath(String filePath) {
  return filePath.replaceFirst(".docx", "_pages.txt");
}
