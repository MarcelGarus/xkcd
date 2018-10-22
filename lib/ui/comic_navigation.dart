import 'package:flutter/material.dart';

/// A callback for being notified about changes of the navigation.
typedef NavigationChangedCallback(int index);

/// A widget to be used as an alternative for the bottom app bar for navigating
/// through multiple comic tiles. Includes:
/// * A button to close the app.
/// * A discrete slider for skimming through tiles as well as seeing your
///   progress.
/// * A numeric indicator for the current tile.
/// * Buttons for navigating to the previous and next tile.
///   - If at the first comic, the previous button is not displayed.
///   - If at the last comic, the next button morphes into a close button. TODO animate!
/// 
/// You just provide the [tile], the [numTiles] as well as callbacks to be
/// notified [onChanged] and [onClose]. If [tile] is [null], no progress slider
/// is displayed but a general zoom info instead.
/// 
/// The navigation widget itself does not maintain any state. Instead, when the
/// state changes, the widget notifies the [onChanged] callback. Usually,
/// widgets using the navigation will listen for the [onChanged] callback and
/// rebuild the navigation with a new [tile] value to update the visual
/// appearance of the navigation.
class ComicNavigation extends StatefulWidget {
  ComicNavigation({
    @required this.show,
    @required this.tile,
    @required this.numTiles,
    @required this.onChanged,
    @required this.onClose
  });

  /// Whether the navigation bar is visible.
  final bool show;

  /// The current progress.
  final int tile;
  bool get isFirst => tile <= 0.0;
  bool get isLast => tile >= numTiles - 1;

  /// The maximum progress.
  final int numTiles;

  /// Callback being called whenever the progress changes.
  final NavigationChangedCallback onChanged;

  /// Callback that's called if the navigation is closed.
  final VoidCallback onClose;

  _ComicNavigationState createState() => _ComicNavigationState();
}

class _ComicNavigationState extends State<ComicNavigation> with SingleTickerProviderStateMixin {
  bool _previouslyShown = false;
  double visibility = 0.0;
  double get inverseVisibility => 1.0 - visibility;
  AnimationController controller;
  Animation<double> animation;

  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 100),
    )..addListener(() => setState(() {
      visibility = animation.value;
    }));
    animation = CurvedAnimation(curve: Cubic(0.0, 0.0, 0.6, 1.0), parent: controller);
  }

  /// Animates the bar.
  void _onVisibleChanged() {
    _previouslyShown = widget.show;

    if (widget.show) {
      controller.forward();
    } else {
      controller.reverse();
    }
  }

  Offset get offset => Offset(0.0, inverseVisibility * 56.0);

  @override
  Widget build(BuildContext context) {
    if (_previouslyShown != widget.show)
      _onVisibleChanged();

    final Widget child = (widget.tile == null)
      ? buildGeneralContent()
      : buildProgressContent();

    return Visibility(
      visible: visibility > 0.0,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Transform.translate(
          offset: offset,
          child: Material(
            color: Colors.white,
            elevation: 12.0,
            child: Container(height: 56.0, child: child),
          )
        )
      )
    );
  }

  /// Builds content without specific progress.
  Widget buildGeneralContent() {
    return InkResponse(
      onTap: widget.onClose,
      radius: MediaQuery.of(context).size.width,
      highlightShape: BoxShape.rectangle,
      child: Center(
        child: Text('Click to return',
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontSize: 18.0,
            fontWeight: FontWeight.bold
          )
        )
      )
    );
  }

  /// Builds content for a specific progress.
  Widget buildProgressContent() {
    final primaryColor = Theme.of(context).primaryColor;
    final items = [
      IconButton(
        icon: Icon(Icons.close, color: primaryColor),
        onPressed: widget.onClose,
      ),
      Slider(
        divisions: widget.numTiles - 1,
        min: 0.0,
        max: widget.numTiles - 1.0,
        value: widget.tile.toDouble(),
        onChanged: (val) => widget.onChanged(val.round()),
      ),
      Opacity(
        opacity: widget.isFirst ? 0.0 : 1.0,
        child: IconButton(
          icon: Icon(Icons.keyboard_arrow_left, color: primaryColor),
          onPressed: () => widget.isFirst
            ? null
            : widget.onChanged(widget.tile - 1),
        ),
      ),
      Text('${widget.tile + 1} / ${widget.numTiles}',
        style: TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.w700,
          fontSize: 18.0,
        )
      ),
      IconButton(
        icon: Icon(
          widget.isLast ? Icons.done : Icons.keyboard_arrow_right,
          color: primaryColor
        ),
        onPressed: () => widget.isLast
          ? widget.onClose()
          : widget.onChanged(widget.tile + 1),
      ),
    ];

    return Row(children: items);
  }
}
