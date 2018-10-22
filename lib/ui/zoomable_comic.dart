import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:xkcd/bloc.dart';
import 'package:xkcd/comic.dart';
import 'package:xkcd/ui/zoomable_image.dart';

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
