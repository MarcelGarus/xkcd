import 'dart:async';
import 'package:flutter/material.dart';
import 'package:xkcd/bloc.dart';
import 'package:xkcd/comic_data.dart';
import 'package:xkcd/zoomable_image.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      bloc: Bloc(),
      child: MaterialApp(
        title: 'xkcd',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: MyHomePage(title: 'xkcd'),
      )
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomAppBar(
        child: Material(
          color: Colors.blue,
          elevation: 12.0,
          child: Container(
            height: 56.0,
            child: Row(
              children: <Widget>[
                Text('xkcd bottom bar', style: TextStyle(color: Colors.white))
              ],
            )
          ),
        ),
      ),
      /*bottomNavigationBar: AppBar(
        title: Text(widget.title),
      ),*/
      body: _buildStreamedComic(Bloc.of(context).current),
      /*body: InfiniteTabs(
        previous: _buildStreamedComic(Bloc.of(context).previous),
        current: _buildStreamedComic(Bloc.of(context).current),
        next: _buildStreamedComic(Bloc.of(context).next),
        onNext: Bloc.of(context).goToNext,
        onPrevious: Bloc.of(context).goToPrevious,
      ),*/
    );
  }

  _buildStreamedComic(Stream<ComicData> stream) {
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
