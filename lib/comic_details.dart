import 'package:flutter/material.dart';
import 'package:xkcd/bloc.dart';
import 'package:xkcd/comic.dart';

class ComicDetails extends StatelessWidget {
  ComicDetails();

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12.0,
      child: Container(
        padding: EdgeInsets.all(16.0),
        //alignment: Alignment.center,
        child: StreamBuilder(
          stream: Bloc.of(context).current,
          builder: (context, AsyncSnapshot<Comic> snapshot) {
            return (!snapshot.hasData)
              ? CircularProgressIndicator()
              : buildDetails(snapshot.data);
          }
        )
      )
    );
  }

  Widget buildDetails(Comic comic) {
    final items = <Widget>[ Container() ];

    items.addAll([
      Text(comic.title, style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.w700)),
      SizedBox(height: 8.0),
      Text('#${comic.id} - published at ${comic.published}'),
    ]);

    if ((comic.alt?.length ?? 0.0) > 0) {
      items.addAll([
        SizedBox(height: 16.0),
        Text(comic.alt),
      ]);
    }

    if ((comic.link?.length ?? 0.0) > 0) {
      items.addAll([
        SizedBox(height: 16.0),
        OutlineButton(
          onPressed: () {
            print('TODO: open the link ${comic.link}');
          },
          child: Text(comic.link),
        )
      ]);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
    );
  }
}