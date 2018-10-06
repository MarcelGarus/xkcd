import 'dart:async';
import 'package:flutter/material.dart';
import 'package:xkcd/bloc.dart';
import 'package:xkcd/comic_data.dart';
import 'package:xkcd/zoomable_image.dart';

class ComicsScreen extends StatefulWidget {
  @override
  _ComicsScreenState createState() => _ComicsScreenState();
}

class _ComicsScreenState extends State<ComicsScreen> with SingleTickerProviderStateMixin {
  bool focusesExist = true;
  double zoomMode = 0.0;
  double get inverseZoomMode => 1.0 - zoomMode;
  int currentFocus = 0;

  AnimationController controller;
  Animation<double> animation;


  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 100),
    )..addListener(() => setState(() {
      zoomMode = animation.value;
    }));
    animation = CurvedAnimation(curve: Cubic(0.0, 0.0, 0.6, 1.0), parent: controller);
  }

  void enterZoomMode() {
    currentFocus = 0;
    controller.forward();
  }

  void exitZoomMode() {
    controller.reverse();
  }


  EdgeInsets get focusSuggestionPadding => EdgeInsets.only(
    bottom: !focusesExist ? 0.0 : (56 * inverseZoomMode).clamp(0.0, double.infinity)
  );
  Offset get zoomBarOffset => Offset(0.0, inverseZoomMode * 56.0);

  @override
  Widget build(BuildContext context) {
    final appBar = Align(
      alignment: Alignment.bottomCenter,
      child: _buildAppBar()
    );

    final zoomBar = Align(
      alignment: Alignment.bottomCenter,
      child: Transform.translate(
        offset: zoomBarOffset,
        child: FocusBar(
          currentFocus: currentFocus,
          numFocuses: 3,
          onChange: (newFocus) => setState(() {
            currentFocus = newFocus;
          }),
          onClose: exitZoomMode,
        ),
      )
    );

    final focusSuggestion = Suggestion(
      isShown: focusesExist && zoomMode == 0.0,
      icon: Icon(Icons.view_carousel, color: Colors.white),
      label: Text('View comic', style: TextStyle(color: Colors.white)),
      onTap: enterZoomMode,
    );

    return Stack(
      children: <Widget>[
        _buildStreamedComic(Bloc.of(context).current),
        focusSuggestion,
        appBar,
        zoomBar,
      ]
    );
  }

  Widget _buildAppBar() {
    final items = [
      IconButton(
        icon: Icon(Icons.menu, color: Colors.white),
        onPressed: null,
      ),
      StreamBuilder(
        stream: Bloc.of(context).current,
        builder: (context, AsyncSnapshot<ComicData> snapshot) {
          return Text(snapshot.data?.title ?? '<loading>',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18.0,
            )
          );
        },
      ),
      IconButton(
        icon: Icon(Icons.info_outline, color: Colors.white),
        onPressed: null,
      ),
    ];

    return Material(
      color: Theme.of(context).primaryColor,
      elevation: 12.0,
      child: Container(
        height: 56.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: items,
        )
      ),
    );
  }

  Widget _buildStreamedComic(Stream<ComicData> stream) {
    return Container(
      padding: EdgeInsets.all(16.0),
      alignment: Alignment.center,
      color: Colors.white,
      child: StreamBuilder(
        stream: stream,
        builder: (context, AsyncSnapshot<ComicData> snapshot) {
          if (!snapshot.hasData)
            return CircularProgressIndicator();

          return ZoomableImage(
            Image.network(snapshot.data.imageUrl).image,
            placeholder: CircularProgressIndicator(),
            backgroundColor: Colors.white,
          );
        },
      )
    );
  }
}




/// A suggestion chip displayed at the bottom of the screen. You can provide an
/// [icon] and a [label], as well as an [onTap] listener. Depending on whether
/// you set [isShown] to true or false, the suggestion sets its padding so as
/// to disappear behind the bottom bar or not.
/// If you change [isShown], the suggestion jumpily animates to its new
/// position.
class Suggestion extends StatefulWidget {
  Suggestion({
    @required this.isShown,
    this.icon,
    @required this.label,
    @required this.onTap
  });
  
  final bool isShown;
  final Widget icon;
  final Widget label;
  final VoidCallback onTap;

  @override
  _SuggestionState createState() => _SuggestionState();
}

class _SuggestionState extends State<Suggestion> with SingleTickerProviderStateMixin {
  bool lastShown;
  double value = 0.0;
  AnimationController controller;
  Animation<double> animation;

  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 150)
    )..addListener(() => setState(() {
      value = animation.value;
    }));
    animation = CurvedAnimation(curve: ElasticOutCurve(), parent: controller);
  }

  void tick() {
    if (widget.isShown == lastShown) return;
    if (lastShown == null) {
      lastShown = widget.isShown;
      value = lastShown ? 1.0 : 0.0;
    }

    if (widget.isShown)
      controller.forward();
    else
      controller.reverse();

    lastShown = widget.isShown;
  }

  @override
  Widget build(BuildContext context) {
    tick();

    return Container(
      alignment: Alignment.bottomCenter,
      padding: EdgeInsets.only(bottom: value.clamp(0.0, double.infinity) * 56),
      child: ActionChip(
        avatar: widget.icon,
        label: widget.label,
        onPressed: widget.onTap,
        backgroundColor: Colors.black,
      )
    );
  }
}







typedef FocusBarChangeCallback(int index);

class FocusBar extends StatelessWidget {
  FocusBar({
    this.currentFocus,
    this.numFocuses,
    this.onChange,
    this.onClose
  });

  final int currentFocus;
  final int numFocuses;
  bool get isFirstFocus => currentFocus <= 0.0;
  bool get isLastFocus => currentFocus >= numFocuses - 1;

  final FocusBarChangeCallback onChange;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final items = [
      IconButton(
        icon: Icon(Icons.close, color: primaryColor),
        onPressed: onClose,
      ),
      Slider(
        divisions: numFocuses - 1,
        min: 0.0,
        max: numFocuses - 1.0,
        value: currentFocus.toDouble(),
        onChanged: (val) => onChange(val.round()),
      ),
      Opacity(
        opacity: isFirstFocus ? 0.0 : 1.0,
        child: IconButton(
          icon: Icon(Icons.keyboard_arrow_left, color: primaryColor),
          onPressed: () => isFirstFocus ? null : onChange(currentFocus - 1),
        ),
      ),
      StreamBuilder(
        stream: Bloc.of(context).current,
        builder: (context, AsyncSnapshot<ComicData> snapshot) {
          return Text('${currentFocus + 1} / $numFocuses',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w700,
              fontSize: 18.0,
            )
          );
        },
      ),
      IconButton(
        icon: Icon(
          isLastFocus ? Icons.done : Icons.keyboard_arrow_right,
          color: primaryColor
        ),
        onPressed: () => isLastFocus ? onClose() : onChange(currentFocus + 1),
      ),
    ];

    return Material(
      color: Colors.white,
      elevation: 12.0,
      child: Container(
        height: 56.0,
        child: Row(
          children: items,
        )
      ),
    );
  }
}






class InfiniteTabs extends StatefulWidget {
  InfiniteTabs({
    this.previous,
    this.current,
    this.next,
    this.onPrevious,
    this.onNext
  });

  final Widget previous, current, next;
  final VoidCallback onPrevious, onNext;

  @override
  _InfiniteTabsState createState() => _InfiniteTabsState();
}

class _InfiniteTabsState extends State<InfiniteTabs>
    with SingleTickerProviderStateMixin {
  
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
          if (scrollTarget == -1) widget.onNext();
          if (scrollTarget == 1) widget.onPrevious();
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
      onHorizontalDragDown: onDragDown,
      onHorizontalDragUpdate: onDragUpdate,
      onHorizontalDragEnd: onDragEnd,
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
