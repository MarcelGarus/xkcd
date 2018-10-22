import 'dart:async';
import 'package:flutter/material.dart';


class Marquee extends StatefulWidget{
  Marquee({
    Key key,
    @required this.child,
    this.scrollAxis = Axis.horizontal,
    this.blankSpace = 100.0,
    this.pixelsPerSecond = 100.0,
  }) :
      assert(child != null),
      assert(scrollAxis != null),
      assert(blankSpace != null && !blankSpace.isNaN && blankSpace >= 0 && blankSpace.isFinite),
      assert(pixelsPerSecond != null && !pixelsPerSecond.isNaN && pixelsPerSecond > 0.0 && pixelsPerSecond.isFinite),
      super(key: key);

  /// The child to be rendered repeatedly.
  final Widget child;

  /// The scroll axis of the marquee.
  final Axis scrollAxis;

  /// The blank space between children.
  final double blankSpace;

  /// The velocity of the marquee in pixels per second.
  final double pixelsPerSecond;

  @override
  State<StatefulWidget> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> with SingleTickerProviderStateMixin {
  /// The scroll controller that controls the ListView.
  ScrollController controller;

  /// The current position in pixels.
  double position = 0.0;

  /// The timer that is fired every second.
  Timer timer;

  /// Initializes the scroll controller and the timer.
  @override
  void initState() {
    super.initState();
    controller = ScrollController();
    _startScrolling();
  }

  /// Disposes the timer.
  @override
  void dispose() {
    _stopScrolling();
    super.dispose();
  }

  void _startScrolling() {
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      position += widget.pixelsPerSecond;

      controller.animateTo(position,
        duration: Duration(seconds: 1),
        curve: Curves.linear
      );
    });
  }

  void _stopScrolling() => timer?.cancel();

  /// Builds the marquee.
  @override
  Widget build(BuildContext context) => ListView.builder(
    controller: controller,
    scrollDirection: widget.scrollAxis,
    physics: NeverScrollableScrollPhysics(),
    itemBuilder: (_, i) => i.isEven ? widget.child : _buildBlankSpace()
  );

  /// Builds the blank space between children.
  Widget _buildBlankSpace() => SizedBox(
    width: widget.scrollAxis == Axis.horizontal ? widget.blankSpace : null,
    height: widget.scrollAxis == Axis.vertical ? widget.blankSpace : null,
  );
}