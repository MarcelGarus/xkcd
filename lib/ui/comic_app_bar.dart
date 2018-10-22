import 'package:flutter/material.dart';
import 'package:xkcd/bloc.dart';
import 'package:xkcd/comic.dart';
import 'package:xkcd/ui/marquee.dart';
import 'package:xkcd/ui/comic_details.dart';

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
          items.add(Expanded(
            child: AdaptiveText(
              comic.title,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Signature',
                fontWeight: FontWeight.w700,
                fontSize: 20.0,
              )
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





class AdaptiveText extends StatelessWidget {
  AdaptiveText(this.text, { this.style }) : super(key: Key(text));

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_checkTextFits(context, constraints.maxWidth, constraints.maxHeight))
          return Center(child: Text(text, style: style));

        final primaryColor = Theme.of(context).primaryColor;
        final transparent = primaryColor.withAlpha(0);
        return Stack(
          children: <Widget>[
            Container(
              width: constraints.maxWidth,
              padding: EdgeInsets.symmetric(vertical: 14.0),
              child: Marquee(
                blankSpace: 100.0,
                pixelsPerSecond: 50.0,
                child: Text(text, style: style)
              )
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 16.0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [ transparent, primaryColor ])
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 16.0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [ primaryColor, transparent ])
                ),
              ),
            )
          ]
        );
      },
    );
  }

  // See https://github.com/leisim/auto_size_text.git
  bool _checkTextFits(BuildContext context, double maxWidth, double maxHeight) {
    var span = TextSpan(text: text, style: style);

    var tp = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      locale: Localizations.localeOf(context),
    );

    tp.layout(maxWidth: maxWidth);

    return !(tp.didExceedMaxLines || tp.height > maxHeight);
  }
}
