import 'package:flutter/material.dart';

/// A suggestion chip to be displayed at the bottom of the screen.
/// 
/// You can provide an [icon] and a [label] as well as an [onTap] callback.
/// Also, you can change the [show] parameter to show or hide the chip.
/// IMPORTANT: This widget expects to be placed at the buttom of the enclosing
/// widget, as it doesn't really "hides" but moves down. TODO
class Suggestion extends StatefulWidget {
  Suggestion({
    @required this.show,
    @required this.onTap,
    @required this.icon,
    @required this.label,
  });
  
  /// Whether the suggestion chip is shown. If you change this, it jumpily
  /// animates to its new position.
  final bool show;

  /// A callback to be called if the suggestion is tapped.
  final VoidCallback onTap;

  /// The icon.
  final Widget icon;

  /// The label;
  final Widget label;


  @override
  _SuggestionState createState() => _SuggestionState();
}

class _SuggestionState extends State<Suggestion> with SingleTickerProviderStateMixin {
  bool lastShown;
  double visibility = 0.0;
  AnimationController controller;
  Animation<double> animation;

  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 250)
    )..addListener(() => setState(() {
      visibility = animation.value;
    }));
    animation = CurvedAnimation(curve: ElasticOutCurve(), parent: controller);
  }

  void tick() {
    if (widget.show == lastShown) return;
    if (lastShown == null) {
      lastShown = widget.show;
      visibility = lastShown ? 1.0 : 0.0;
    }

    if (widget.show)
      controller.forward();
    else
      controller.reverse();

    lastShown = widget.show;
  }

  @override
  Widget build(BuildContext context) {
    tick();

    return ClipRect(
      child: Transform.translate(
        offset: Offset(0.0, 56 * (1.0 - visibility)),
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Transform.scale(
            scale: 0.8,
            child: FloatingActionButton.extended(
              backgroundColor: Colors.white,
              elevation: 8.0,
              icon: widget.icon,
              label: widget.label,
              onPressed: widget.onTap,
            )
          )
        ),
      )
    );
  }
}