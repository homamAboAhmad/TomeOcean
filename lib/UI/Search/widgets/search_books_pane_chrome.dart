import 'package:flutter/material.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_split_pane.dart';

class SearchBooksPaneChrome extends StatelessWidget {
  final Widget? toolbar;
  final Widget child;
  final bool showCard;
  final Widget card;

  const SearchBooksPaneChrome({
    super.key,
    this.toolbar,
    required this.child,
    required this.showCard,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (toolbar != null) toolbar!,
        Expanded(
          child: showCard
              ? LibrarySplitPane(
                  axis: Axis.vertical,
                  initialRatio: 0.68,
                  minRatio: 0.3,
                  maxRatio: 0.85,
                  first: child,
                  second: card,
                )
              : child,
        ),
      ],
    );
  }
}
