import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ZoomableImage extends StatefulWidget {
  ZoomableImage(
    this.image, {
    Key key,
    this.focus,
    @deprecated double scale,
    this.maxScale = 2.0,
    this.onTap,
    this.backgroundColor = Colors.black,
    this.placeholder,
  }) : super(key: key);

  final ImageProvider image;
  final Rect focus;
  final double maxScale;
  final GestureTapCallback onTap;
  final Color backgroundColor;
  final Widget placeholder;

  @override
  _ZoomableImageState createState() => _ZoomableImageState();
}

// See /flutter/examples/layers/widgets/gestures.dart
class _ZoomableImageState extends State<ZoomableImage> with SingleTickerProviderStateMixin {
  ImageStream _imageStream;
  ui.Image _image;
  Rect _lastFocus;

  AnimationController _controller;
  Offset _startingFocalPoint;

  Offset _previousOffset;
  Offset _offset; // where the top left corner of the image is drawn
  Animation _offsetAnimation;

  double _previousScale;
  double _scale; // multiplier applied to scale the full image
  Animation _scaleAnimation;

  Orientation _previousOrientation;

  Size _canvasSize;


  /// Initializes animation controller and animations.
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300)
    )..addListener(() => setState(() {
      _offset = _offsetAnimation.value;
      _scale = _scaleAnimation.value;
    }));
  }

  /// Focuses on a part of the image.
  void _focus(Rect focusRect, { bool animate = true }) {
    focusRect = focusRect ?? Rect.fromLTWH(
      0.0,
      0.0,
      _image.width.toDouble(),
      _image.height.toDouble()
    );

    final focusSize = focusRect.size;
    print('Canvas size is $_canvasSize and $focusSize is $focusSize');
    final targetScale = math.min(
      _canvasSize.width / focusSize.width,
      _canvasSize.height / focusSize.height,
    );
    final focusCenter = focusRect.center * targetScale;
    final targetOffset = (_canvasSize / 2.0).bottomRight(Offset.zero) - focusCenter;

    if (animate) {
      final offsetCurve = CurvedAnimation(curve: Cubic(0.2, 0.0, 0.5, 1.0), parent: _controller);
      final scaleCurve = CurvedAnimation(curve: Cubic(0.2, 0.0, 0.5, 1.0), parent: _controller);
      _offsetAnimation = Tween(begin: _offset, end: targetOffset).animate(offsetCurve);
      _scaleAnimation = Tween(begin: _scale, end: targetScale).animate(scaleCurve);
      _controller.forward(from: 0.0);
    } else {
      _scale = targetScale;
      _offset = targetOffset;
    }
  }

  /// Centers the image.
  void _centerAndScaleImage() => _focus(null, animate: false);

  Function() _handleDoubleTap(BuildContext ctx) {
    return () {
      double newScale = _scale * 2;
      if (newScale > widget.maxScale) {
        setState(() => _centerAndScaleImage());
        return;
      }

      // We want to zoom in on the center of the screen.
      // Since we're zooming by a factor of 2, we want the new offset to be twice
      // as far from the center in both width and height than it is now.
      Offset center = ctx.size.center(Offset.zero);
      Offset newOffset = _offset - (center - _offset);

      setState(() {
        _scale = newScale;
        _offset = newOffset;
      });
    };
  }

  void _handleScaleStart(ScaleStartDetails d) {
    _startingFocalPoint = d.focalPoint;
    _previousOffset = _offset;
    _previousScale = _scale;
  }

  void _handleScaleUpdate(ScaleUpdateDetails d) {
    double newScale = (_previousScale * d.scale).clamp(0.2, widget.maxScale);

    // Ensure that item under the focal point stays in the same place despite zooming
    final Offset normalizedOffset =
        (_startingFocalPoint - _previousOffset) / _previousScale;
    final Offset newOffset = d.focalPoint - normalizedOffset * newScale;

    setState(() {
      _scale = newScale;
      _offset = newOffset;
    });
  }

  @override
  Widget build(BuildContext ctx) {
    Widget paintWidget() {
      return CustomPaint(
        child: Container(color: widget.backgroundColor),
        foregroundPainter: _ZoomableImagePainter(
          image: _image,
          offset: _offset,
          scale: _scale,
        ),
      );
    }

    // If the image didn't load yet, display the placeholder.
    if (_image == null) {
      return widget.placeholder;
    }

    return LayoutBuilder(builder: (ctx, constraints) {
      Orientation orientation = MediaQuery.of(ctx).orientation;
      if (orientation != _previousOrientation) {
        _previousOrientation = orientation;
        _canvasSize = constraints.biggest;
        _centerAndScaleImage();
      }

      // If the focus changed, animate to the new focus.
      if (_lastFocus != widget.focus) {
        _lastFocus = widget.focus;
        _focus(widget.focus);
      }

      return GestureDetector(
        child: paintWidget(),
        onTap: widget.onTap,
        onDoubleTap: _handleDoubleTap(ctx),
        onScaleStart: _handleScaleStart,
        onScaleUpdate: _handleScaleUpdate,
      );
    });
  }

  @override
  void didChangeDependencies() {
    _resolveImage();
    super.didChangeDependencies();
  }

  @override
  void reassemble() {
    _resolveImage(); // in case the image cache was flushed
    super.reassemble();
  }

  void _resolveImage() {
    _imageStream = widget.image.resolve(createLocalImageConfiguration(context));
    _imageStream.addListener(_handleImageLoaded);
  }

  void _handleImageLoaded(ImageInfo info, bool synchronousCall) {
    print("image loaded: $info");
    setState(() {
      _image = info.image;
    });
  }

  @override
  void dispose() {
    _imageStream.removeListener(_handleImageLoaded);
    super.dispose();
  }
}

class _ZoomableImagePainter extends CustomPainter {
  const _ZoomableImagePainter({this.image, this.offset, this.scale});

  final ui.Image image;
  final Offset offset;
  final double scale;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    Size imageSize = new Size(image.width.toDouble(), image.height.toDouble());
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
