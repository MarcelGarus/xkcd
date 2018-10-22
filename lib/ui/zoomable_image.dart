import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

typedef OnResolvedCallback(ui.Image image);
typedef OnMoveCallback(Rect focus);

/// A widget displaying a zoomable image. It can be interacted with using
/// multitouch.
/// 
/// This widget holds no state. Rather, you provide your own [focus], thereby
/// describing what part of the image is visible. If the user interacts with
/// the image, the [onMoved] callback will be called with a new proposed focus
/// that fits to the interaction. You then have to rebuild this widget with the
/// new focus set as the [focus] property.
/// 
/// This file is based on the package https://pub.dartlang.org/packages/zoomable_image.
class ZoomableImage extends StatefulWidget {
  ZoomableImage({
    Key key,
    @required this.image,
    this.focus,
    this.isInteractive = false,
    this.onResolved,
    this.onMoved,
    this.onCentered,
    this.placeholder,
    this.backgroundColor = Colors.black,
  }) :
      assert(image != null),
      super(key: key);

  /// The image.
  final ImageProvider image;

  /// The part of the image that's currently in focus.
  final Rect focus;

  /// Whether you can move the image with just one finger.
  final bool isInteractive;

  // Callbacks.
  final OnResolvedCallback onResolved;
  final OnMoveCallback onMoved;
  final VoidCallback onCentered;

  /// A placeholder.
  final Widget placeholder;

  /// A background color.
  final Color backgroundColor;

  @override
  _ZoomableImageState createState() => _ZoomableImageState();
}

// See /flutter/examples/layers/widgets/gestures.dart
class _ZoomableImageState extends State<ZoomableImage> with SingleTickerProviderStateMixin {
  ImageStream _imageStream;
  ui.Image _image;
  Size _previousImageSize;
  Size _imageSize;

  // Buffers for the focus of the image.
  Orientation _previousOrientation;
  Rect _previousFocus;
  Size _canvasSize;

  Offset _startingFocalPoint;

  // Where the top left corner of the image is drawn.
  Offset _previousOffset;
  Offset _offset;

  // Multiplier applied to scale the full image.
  double _previousScale;
  double _scale;


  /// Focuses on the part of the image that's enclosed by [focus]. If [focus]
  /// is [null], the image is scaled and position to fit in the center of the
  /// available space.
  void _focus(Rect focus, { bool notifyCallback = true }) {
    focus = focus ?? Offset.zero & (_imageSize ?? Size(1.0, 1.0));

    final focusSize = focus.size;
    final targetScale = math.min(
      _canvasSize.width / focusSize.width,
      _canvasSize.height / focusSize.height,
    );
    final focusCenter = focus.center * targetScale;
    final targetOffset = (_canvasSize / 2.0).bottomRight(Offset.zero) - focusCenter;

    _scale = targetScale;
    _offset = targetOffset;

    if (notifyCallback)
      widget.onMoved(focus);
  }

  /// Centers the image.
  void _center({ bool notifyCallback = true }) {
    _focus(null, notifyCallback: false);
    if (notifyCallback && widget.onCentered != null)
      widget.onCentered();
  }

  void _notifyOnMoved() {
    if (widget.onMoved != null) {
      final topLeft = -_offset / _scale;

      widget.onMoved(Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy,
        _canvasSize.width / _scale,
        _canvasSize.height / _scale
      ));
    }
  }

  /// Zooms in by a factor of 2 on the center of the screen.
  void _handleDoubleTap(BuildContext ctx) {
    double newScale = _scale * 2;

    if (newScale > 2.0) {
      _center();
    } else {
      // We want the new offset to be twice as far from the center in both
      // width and height than it is now.
      _scale = newScale;
      _offset = _offset - (ctx.size.center(Offset.zero) - _offset);
    }

    _notifyOnMoved();
  }

  /// Save parameters of the moment when the scale starts in order to be able
  /// to compute deltas when scaling.
  void _handleScaleStart(ScaleStartDetails details) {
    _startingFocalPoint = details.focalPoint;
    _previousOffset = _offset;
    _previousScale = _scale;
  }

  /// Updates the scale and offset depending on the scale delta.
  void _handleScaleUpdate(ScaleUpdateDetails d) {
    // Calculate the new scale and ensure that the item under the focal point
    // stays in the same place despite zooming.
    final double newScale = (_previousScale * d.scale).clamp(0.0, 2.0);
    final Offset normalizedOffset = (_startingFocalPoint - _previousOffset) / _previousScale;
    final Offset newOffset = d.focalPoint - normalizedOffset * newScale;

    _scale = newScale;
    _offset = newOffset;

    _notifyOnMoved();
  }

  @override
  Widget build(BuildContext context) {
    // If the image didn't load yet, display the placeholder. Otherwise, do
    // more complicated stuff in the layout builder.
    return LayoutBuilder(
      builder: (ctx, constraints) {
        // If the orientation changed, center the image and update the canvas
        // size.
        Orientation orientation = MediaQuery.of(ctx).orientation;
        if (orientation != _previousOrientation) {
          _previousOrientation = orientation;
          _canvasSize = constraints.biggest;
          _center(notifyCallback: false);
        }

        // The image loaded, so display it centered.
        if (_previousImageSize != _imageSize) {
          _previousImageSize = _imageSize;
          _center(notifyCallback: false);
        }

        // If the focus changed, animate to the new focus.
        if (_previousFocus != widget.focus) {
          _previousFocus = widget.focus;
          _focus(widget.focus, notifyCallback: false);
        }

        if (_image == null)
          return widget.placeholder ?? Container();

        // Return the image.
        return GestureDetector(
          onDoubleTap: widget.isInteractive ? () => _handleDoubleTap(ctx) : null,
          onScaleStart: widget.isInteractive ? _handleScaleStart : null,
          onScaleUpdate: widget.isInteractive ? _handleScaleUpdate : null,
          child: CustomPaint(
            child: Container(color: widget.backgroundColor),
            foregroundPainter: _ZoomableImagePainter(
              image: _image,
              offset: _offset,
              scale: _scale,
            ),
          ),
        );
      }
    );
  }

  @override
  void didChangeDependencies() {
    _resolveImage();
    super.didChangeDependencies();
  }

  @override
  void reassemble() {
    // Resolve the image again in case the image cache was flushed.
    _resolveImage();
    super.reassemble();
  }

  void _resolveImage() {
    _imageStream = widget.image.resolve(createLocalImageConfiguration(context));
    _imageStream.addListener(_handleImageLoaded);
  }

  void _handleImageLoaded(ImageInfo info, bool synchronousCall) => setState(() {
    _image = info.image;
    _imageSize = Size(_image.width.toDouble(), _image.height.toDouble());

    if (widget.onResolved != null) {
      widget.onResolved(_image);
    }
  });

  @override
  void dispose() {
    _imageStream.removeListener(_handleImageLoaded);
    super.dispose();
  }
}

/// Painter that paints the given image with the given offset and scale.
class _ZoomableImagePainter extends CustomPainter {
  const _ZoomableImagePainter({
    @required this.image,
    @required this.offset,
    @required this.scale
  });

  final ui.Image image;
  final Offset offset;
  final double scale;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
    Size targetSize = imageSize * scale;

    paintImage(
      canvas: canvas,
      rect: offset & targetSize,
      image: image,
      fit: BoxFit.fill,
    );
  }

  @override
  bool shouldRepaint(_ZoomableImagePainter old) {
    return old.image != image || old.offset != offset || old.scale != scale;
  }
}
