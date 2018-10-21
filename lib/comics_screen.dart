import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
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
    return StreamBuilder(
      stream: Bloc.of(context).zoomStatus,
      builder: (context, AsyncSnapshot<ZoomStatus> snapshot) {
        final zoomStatus = snapshot.data;

        return InfiniteTabs(
          isEnabled: !(zoomStatus?.enabled ?? true),
          previous: _buildStreamedComic(Bloc.of(context).previous),
          current: _buildStreamedComic(Bloc.of(context).current, interactive: true),
          next: _buildStreamedComic(Bloc.of(context).next),
          onNext: Bloc.of(context).goToNextComic,
          onPrevious: Bloc.of(context).goToPreviousComic,
        );
      },
    );
  }

  Widget _buildSuggestion() {
    final primaryColor = Theme.of(context).primaryColor;

    return StreamBuilder(
      stream: Bloc.of(context).current,
      builder: (context, AsyncSnapshot<Comic> comicSnapshot) {
        return StreamBuilder(
          stream: Bloc.of(context).zoomStatus,
          builder: (context, AsyncSnapshot<ZoomStatus> zoomSnapshot) {
            final comic = comicSnapshot.data;
            final zoomStatus = zoomSnapshot.data;
            final enabled = !(zoomStatus?.enabled ?? true) && comic != null
              && comic.imageLoaded && (comic?.tiles?.length ?? 0) > 0;

            return Suggestion(
              show: enabled,
              onTap: () {
                if (enabled) Bloc.of(context).enterZoom(focusOnFirstTile: true);
              },
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
      },
    );
  }

  Widget _buildNavigationBar() {
    return StreamBuilder(
      stream: Bloc.of(context).current,
      builder: (context, AsyncSnapshot<Comic> comicSnapshot) {
        return StreamBuilder(
          stream: Bloc.of(context).zoomStatus,
          builder: (context, AsyncSnapshot<ZoomStatus> zoomSnapshot) {
            final comic = comicSnapshot.data;
            final zoomStatus = zoomSnapshot.data;

            if (comic == null || zoomStatus == null)
              return Container();
            
            return ComicNavigation(
              show: zoomStatus?.enabled ?? false,
              tile: zoomStatus?.tile,
              numTiles: comic.tiles?.length ?? 0,
              onChanged: Bloc.of(context).zoomToTile,
              onClose: Bloc.of(context).exitZoom
            );
          }
        );
      },
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
          //print('Got a new comic from the BLoC: ${snapshot.data}. Image is at ${snapshot.data?.image?.path}');
          return (!snapshot.hasData || snapshot.data.image == null)
            ? CircularProgressIndicator()
            : ZoomableComic(comic: snapshot.data, interactive: interactive);
        },
      )
    );
  }
}









class ZoomableComic extends StatefulWidget {
  ZoomableComic({ @required this.comic, @required this.interactive }) :
    assert(comic != null),
    super(key: Key('Comic ${comic.id}'));

  final Comic comic;
  final bool interactive;

  @override
  _ZoomableComicState createState() => _ZoomableComicState();
}

class _ZoomableComicState extends State<ZoomableComic>
    with SingleTickerProviderStateMixin {
  ZoomStatus _previousZoomMode = ZoomStatus.seed;

  ui.Image _image;
  Rect _focus;
  AnimationController _focusController;
  CurvedAnimation _focusAnimation;
  Rect _beginFocus, _endFocus; // Focuses for animation.

  void initState() {
    super.initState();

    // Initialize controllers and the focus animation.
    _focusController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200)
    )..addListener(() => setState(() {
      _focus = Rect.lerp(_beginFocus, _endFocus, _focusAnimation.value ?? 0.0);
    }));
    _focusAnimation = CurvedAnimation(
      curve: Cubic(0.3, 0.0, 0.7, 1.0),
      parent: _focusController
    );

    if (widget.interactive) {
      Bloc.of(context).zoomStatus.listen(_onZoomStatusChanged);
    }
  }

  void _onZoomStatusChanged(ZoomStatus zoomStatus) {
    //print('Zoom mode updated: $zoomMode (comic ${widget.comic.id} has ${widget.comic.tiles?.length} tiles)');

    if (_previousZoomMode == zoomStatus) return;
    if (zoomStatus.enabled && zoomStatus.tile == null) return;

    _beginFocus = _focus ?? _getWholeImageFocus();
    _endFocus = zoomStatus.enabled && zoomStatus.tile < (widget.comic.tiles?.length ?? 0)
      ? widget.comic.tiles[zoomStatus.tile]
      : _getWholeImageFocus();
    _focusController?.reset();
    _focusController?.forward();

    _previousZoomMode = zoomStatus;
  }

  /// Returns the focus for the whole comic to be visible.
  Rect _getWholeImageFocus() => (_image != null) ? Rect.fromLTRB(
    0.0, 0.0, _image.width.toDouble(), _image.height.toDouble()
  ) : (Offset.zero & Size(1.0, 1.0));

  void _onFocusMovedManually(
    Comic comic,
    ZoomStatus zoomStatus,
    Rect newFocus
  ) => setState(() {
    _focusController.stop();
    _focus = newFocus;

    if (!zoomStatus.enabled)
      Bloc.of(context).enterZoom();

    if (comic.tiles == null) return;

    // Check how visible each of the tiles is, then maybe choose the most
    // visible one as the current progress.
    final visibilities = comic.tiles.map((tile) {
      final tileArea = max(0, tile.width * tile.height);
      final intersect = tile.intersect(_focus);
      final intersectArea = max(0, intersect.width * intersect.height);
      return intersectArea / tileArea;
    }).toList();
    final mostVisible = visibilities.reduce(max);
    final mostVisibleIndex = visibilities.indexOf(mostVisible);
    final sum = visibilities.reduce((a, b) => a + b);
    final tileIndex = (mostVisible > 0.5 && mostVisible / sum > 0.5)
      ? mostVisibleIndex : null;

    Bloc.of(context).zoomToTile(tileIndex);
  });

  @override
  Widget build(BuildContext context) {
    return ZoomableImage(
      image: FileImage(widget.comic.image),
      focus: widget.interactive ? _focus : null,
      isInteractive: widget.interactive,
      backgroundColor: Colors.white,
      onResolved: (ui.Image image) {
        _image = image;
      },
      onMoved: (Rect rect) {
        _onFocusMovedManually(widget.comic, _previousZoomMode, rect);
      },
      onCentered: Bloc.of(context).exitZoom
    );
  }

  @override
  void dispose() {
    _focusController?.stop(canceled: true);
    _focusController?.dispose();
    _focusController = null;
    super.dispose();
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
              fontSize: 12.0,
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
