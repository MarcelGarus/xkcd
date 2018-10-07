import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A widget displaying a zoomable image. It can be touched and scaled using
/// multitouch.
class ZoomableImage extends StatefulWidget {
  ZoomableImage({
    @required this.image,
    this.focus,
    this.onMoved,
    this.onCentered,
    this.backgroundColor = Colors.black,
    this.placeholder,
  }) :
      assert(image != null),
      super();

  /// The image provider.
  final ImageProvider image;

  /// The part of the image that's currently in focus.
  final Rect focus;

  /// Whether you can move the image with just one finger.
  final Function onMoved; // TODO: return the current focus
  final VoidCallback onCentered;

  /// A background color.
  final Color backgroundColor;

  /// A placeholder, being displayed while the image is loading.
  final Widget placeholder;

  @override
  _ZoomableImageState createState() => _ZoomableImageState();
}

// See /flutter/examples/layers/widgets/gestures.dart
class _ZoomableImageState extends State<ZoomableImage> with SingleTickerProviderStateMixin {
  // The actual image.
  ImageStream _imageStream;
  ui.Image _image;

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
  /// By setting [animate], one can control whether to animate to the new focus
  /// or move there directly.
  void _focus(Rect focus) {
    focus = focus ?? Rect.fromLTWH(
      0.0,
      0.0,
      _image.width.toDouble(),
      _image.height.toDouble()
    );

    final focusSize = focus.size;
    final targetScale = math.min(
      _canvasSize.width / focusSize.width,
      _canvasSize.height / focusSize.height,
    );
    final focusCenter = focus.center * targetScale;
    final targetOffset = (_canvasSize / 2.0).bottomRight(Offset.zero) - focusCenter;

    // If there should be an animation to the new focus, initialize the curve
    // and the animations, then start the controller.
    // If there should be no animation, set the according values directly.
    _scale = targetScale;
    _offset = targetOffset;
  }

  /// Centers the image.
  void _centerAndScaleImage() {
    _focus(null);
    if (widget.onCentered != null)
      widget.onCentered();
  }

  /// Zooms in by a factor of 2 on the center of the screen.
  void _handleDoubleTap(BuildContext ctx) => setState(() {
    double newScale = _scale * 2;

    if (newScale > 2.0) {
      _centerAndScaleImage();
    } else {
      // We want the new offset to be twice as far from the center in both
      // width and height than it is now.
      _scale = newScale;
      _offset = _offset - (ctx.size.center(Offset.zero) - _offset);
    }
  });

  /// Save parameters of the moment when the scale starts in order to be able
  /// to compute deltas when scaling.
  void _handleScaleStart(ScaleStartDetails details) {
    _startingFocalPoint = details.focalPoint;
    _previousOffset = _offset;
    _previousScale = _scale;
  }

  /// Updates the scale and offset depending on the scale delta.
  void _handleScaleUpdate(ScaleUpdateDetails d) => setState(() {
    // Calculate the new scale and ensure that the item under the focal point
    // stays in the same place despite zooming.
    final double newScale = (_previousScale * d.scale).clamp(0.0, 2.0);
    final Offset normalizedOffset = (_startingFocalPoint - _previousOffset) / _previousScale;
    final Offset newOffset = d.focalPoint - normalizedOffset * newScale;

    _scale = newScale;
    _offset = newOffset;

    if (widget.onMoved != null) {
      final topLeft = -_offset / _scale;

      widget.onMoved(Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy,
        _canvasSize.width / _scale,
        _canvasSize.height / _scale
      ));
    }
  });

  @override
  Widget build(BuildContext ctx) {
    // If the image didn't load yet, display the placeholder. Otherwise, do
    // more complicated stuff in the layout builder.
    return _image == null ? widget.placeholder ?? Container() : LayoutBuilder(
      builder: (ctx, constraints) {
        // If the orientation changed, center the image and update the canvas
        // size.
        Orientation orientation = MediaQuery.of(ctx).orientation;
        if (orientation != _previousOrientation) {
          _previousOrientation = orientation;
          _canvasSize = constraints.biggest;
          _centerAndScaleImage();
        }

        // If the focus changed, animate to the new focus.
        if (_previousFocus != widget.focus) {
          _previousFocus = widget.focus;
          _focus(widget.focus);
        }

        // Return the image.
        return GestureDetector(
          onDoubleTap: () => _handleDoubleTap(ctx),
          onScaleStart: _handleScaleStart,
          onScaleUpdate: _handleScaleUpdate,
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
