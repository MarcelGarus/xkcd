import 'dart:async';
import 'package:flutter/material.dart';
import 'package:xkcd/bloc.dart';
import 'package:xkcd/comic.dart';
import 'package:xkcd/ui/comic_app_bar.dart';
import 'package:xkcd/ui/comic_navigation.dart';
import 'package:xkcd/ui/infinite_tabs.dart';
import 'package:xkcd/ui/suggestion.dart';
import 'package:xkcd/ui/zoomable_comic.dart';

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
