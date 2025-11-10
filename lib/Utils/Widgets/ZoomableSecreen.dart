import 'package:flutter/cupertino.dart';

class CustomInteractiveViewer extends StatefulWidget {
  final Widget child;
  const CustomInteractiveViewer({required this.child, super.key});

  @override
  State<CustomInteractiveViewer> createState() => _CustomInteractiveViewerState();
}

class _CustomInteractiveViewerState extends State<CustomInteractiveViewer> {


  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: InteractiveViewer(
        // transformationController: _controller,
        panEnabled: true,
        scaleEnabled: true,
        minScale: 0.5,
        maxScale: 4.0,
        boundaryMargin: const EdgeInsets.only(bottom: 300), // يسمح بالسحب من البداية
        child: widget.child,
      ),
    );
  }
}
