import 'package:flutter/material.dart';

class InfiniteTabs extends StatefulWidget {
  InfiniteTabs({
    this.isEnabled = true,
    this.previous,
    this.current,
    this.next,
    this.onPrevious,
    this.onNext
  });

  final bool isEnabled;
  final Widget previous, current, next;
  final VoidCallback onPrevious, onNext;

  @override
  _InfiniteTabsState createState() => _InfiniteTabsState();
}

class _InfiniteTabsState extends State<InfiniteTabs> with SingleTickerProviderStateMixin {
  Offset dragStart;
  bool isScrollingDrag = false;

  // Stuff for scrolling.
  double _scroll = 0.0;
  double get scroll => _scroll;
  set scroll(double val) {
    _scroll = val.clamp(widget.previous == null ? 0 : -1, widget.next == null ? 0 : 1);
  }
  double scrollWhenDragStarted = 0.0;
  int scrollTarget;
  AnimationController controller;
  Animation<double> animation;


  void initState() {
    super.initState();
    controller = AnimationController(duration: Duration(seconds: 1), vsync: this)
      ..addListener(() => setState(() {
        scroll = animation?.value ?? 0.0;
      }))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (scrollTarget == -1 && widget.onNext != null)
            widget.onNext();
          if (scrollTarget == 1 && widget.onPrevious != null)
            widget.onPrevious();
          scroll = 0.0;
        }
      });
  }

  void dispose() {
    controller.dispose();
    super.dispose();
  }


  void onDragDown(DragDownDetails details) {
    dragStart = details.globalPosition;
    scrollWhenDragStarted = scroll;
  }

  void onDragUpdate(DragUpdateDetails details) => setState(() {
    final delta = details.globalPosition - dragStart;
    scroll = scrollWhenDragStarted + delta.dx / MediaQuery.of(context).size.width;
  });

  void onDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx / 1000.0;
    scrollTarget = (scroll + velocity * 0.2).clamp(-1, 1).round();

    animation = Tween(begin: scroll, end: scrollTarget.toDouble()).animate(controller);
    controller
      ..value = 0.0
      ..fling(velocity: velocity.abs());
  }

  Offset _caluclateOffset(int index) => Offset(
    MediaQuery.of(context).size.width * (index + scroll),
    0.0
  );
  Offset get previousOffset => _caluclateOffset(-1);
  Offset get currentOffset => _caluclateOffset(0);
  Offset get nextOffset => _caluclateOffset(1);
  
  @override
  Widget build(BuildContext context) {
    final previous = widget.previous ?? Container();
    final current = widget.current ?? Container();
    final next = widget.next ?? Container();

    return GestureDetector(
      onHorizontalDragDown: widget.isEnabled ? onDragDown : null,
      onHorizontalDragUpdate: widget.isEnabled ? onDragUpdate : null,
      onHorizontalDragEnd: widget.isEnabled ? onDragEnd : null,
      child: Stack(
        children: <Widget>[
          Transform.translate(offset: previousOffset, child: previous),
          Transform.translate(offset: currentOffset, child: current),
          Transform.translate(offset: nextOffset, child: next),
        ],
      )
    );
  }
}
