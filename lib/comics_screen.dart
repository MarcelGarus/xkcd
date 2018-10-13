import 'dart:async';
import 'package:flutter/material.dart';
import 'package:xkcd/bloc.dart';
import 'package:xkcd/comic.dart';
import 'package:xkcd/comic_details.dart';
import 'package:xkcd/comic_navigation.dart';
import 'package:xkcd/infinite_tabs.dart';
import 'package:xkcd/suggestion.dart';
import 'package:xkcd/zoomable_image.dart';

class ComicsScreen extends StatefulWidget {
  @override
  _ComicsScreenState createState() => _ComicsScreenState();
}

class _ComicsScreenState extends State<ComicsScreen> with SingleTickerProviderStateMixin {
  Comic _previousComic;

  // Zoom mode refers to the mode where a single comic is viewed in more detail.
  bool inZoomMode = false;

  // The focuses of the comic represent important parts.
  int progress;
  Rect focus;
  AnimationController focusController;
  CurvedAnimation focusAnimation;
  Rect beginFocus, endFocus; // Focuses for animation.


  void initState() {
    super.initState();

    focusController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200)
    )..addListener(() => setState(() {
      focus = Rect.lerp(beginFocus, endFocus, focusAnimation.value ?? 0.0);
    }));
    focusAnimation = CurvedAnimation(
      curve: Cubic(0.3, 0.0, 0.7, 1.0),
      parent: focusController
    );

    Bloc.of(context).current.listen((Comic comic) {
      if ((_previousComic?.id ?? -1) != (comic?.id ?? -1)) {
        // We just got a new comic, so exit the zoom mode.
        print('New comic: $comic');

        _previousComic = comic;
        _exitZoomMode(comic);
      }
    });
  }

  void _enterZoomMode(Comic comic, { bool initFocus = false }) {
    if (inZoomMode) return;

    inZoomMode = true;
    if (initFocus)
      _goToFocus(comic, 0);
  }

  Rect _getWholeImageFocus(Comic comic) {
    return Rect.fromLTRB(
      0.0,
      0.0,
      comic.image.width.toDouble(),
      comic.image.height.toDouble()
    );
  }

  void _exitZoomMode(Comic comic) {
    if (!inZoomMode) return;

    setState(() {
      inZoomMode = false;
      progress = null;
      
      beginFocus = focus ?? _getWholeImageFocus(comic);
      endFocus = _getWholeImageFocus(comic);
      focusController.reset();
      focusController.forward();
    });
  }

  void _goToFocus(Comic comic, int index) {
    if (index == null)
      _exitZoomMode(comic);
    else {
      if (index > (comic.focuses?.length ?? -1))
        return;

      progress = index;

      beginFocus = focus ?? _getWholeImageFocus(comic);
      endFocus = comic.focuses[progress];
      focusController.reset();
      focusController.forward();
    }
  }

  void _onFocusMoved(Comic comic, Rect newFocus) {
    focusController.stop();
    focus = newFocus;
    if (!inZoomMode)
      _enterZoomMode(comic);
    else setState(() {});
  }


  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        _buildTabs(),
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [ _buildSuggestion(), ComicAppBar() ]
        ),
        _buildNavigationBar()
      ]
    );
  }

  Widget _buildTabs() {
    return InfiniteTabs(
      isEnabled: !inZoomMode,
      previous: _buildStreamedComic(Bloc.of(context).previous),
      current: _buildStreamedComic(Bloc.of(context).current, interactive: true),
      next: _buildStreamedComic(Bloc.of(context).next),
      onNext: Bloc.of(context).goToNext,
      onPrevious: Bloc.of(context).goToPrevious,
    );
  }

  Widget _buildSuggestion() {
    final primaryColor = Theme.of(context).primaryColor;

    return StreamBuilder(
      stream: Bloc.of(context).current,
      builder: (context, AsyncSnapshot<Comic> snapshot) {
        final comic = snapshot.data;

        return Suggestion(
          show: !inZoomMode && (comic?.focuses?.length ?? 0) > 0,
          onTap: comic == null
            ? null
            : () => _enterZoomMode(comic, initFocus: true),
          icon: Icon(Icons.view_carousel, color: primaryColor),
          label: Text('Zoom at the comic tiles',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w700,
              fontSize: 18.0,
              letterSpacing: 0.7
            )
          ),
        );
      },
    );
  }

  Widget _buildNavigationBar() {
    return StreamBuilder(
      stream: Bloc.of(context).current,
      builder: (context, AsyncSnapshot<Comic> snapshot) {
        final comic = snapshot.data;

        return ComicNavigation(
          show: inZoomMode,
          progress: comic?.focuses == null ? null : progress,
          maxProgress: comic?.focuses?.length ?? 0,
          onChanged: (progress) => _goToFocus(comic, progress),
          onClose: () => _exitZoomMode(comic),
        );
      }
    );
  }

  Widget _buildStreamedComic(Stream<Comic> stream, { bool interactive = false }) {
    return Container(
      padding: EdgeInsets.all(16.0),
      alignment: Alignment.center,
      color: Colors.white,
      child: StreamBuilder(
        stream: stream,
        builder: (context, AsyncSnapshot<Comic> snapshot) {
          if (!snapshot.hasData || snapshot.data.image == null)
            return CircularProgressIndicator();

          print('Building zoomable image with focus $focus.');
          final comic = snapshot.data;
          return ZoomableImage(
            image: comic.image,
            focus: interactive ? focus : null,
            isInteractive: interactive,
            backgroundColor: Colors.white,
            onMoved: (Rect rect) => _onFocusMoved(comic, rect),
            onCentered: () => _exitZoomMode(comic)
          );
        },
      )
    );
  }
}




class ComicAppBar extends StatefulWidget {
  @override
  _ComicAppBarState createState() => _ComicAppBarState();
}

class _ComicAppBarState extends State<ComicAppBar> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Bloc.of(context).current,
      builder: (context, AsyncSnapshot<Comic> snapshot) {
        final comic = snapshot.data;
        final items = <Widget>[
          IconButton(
            icon: Icon(Icons.menu, color: Colors.white),
            onPressed: null,
          ),
        ];

        if (comic?.title == null) {
          items.add(Container(
            color: Colors.white.withAlpha(100),
            height: 24.0,
            width: 100.0,
          ));
        } else {
          items.add(Text(
            comic.title,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18.0,
            )
          ));
        }

        items.add(IconButton(
          icon: Icon(Icons.info_outline, color: Colors.white),
          onPressed: () => showBottomSheet(
            context: context,
            builder: (context) => ComicDetails(comicStream: Bloc.of(context).current)
          ),
        ));

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
      },
    );
  }
}
