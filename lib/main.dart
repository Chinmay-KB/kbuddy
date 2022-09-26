import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final tuneUrl = 'https://www.youtube.com/watch?v=R2sxMVRgybI';
final tuneManifest = 'R2sxMVRgybI';
void main() {
  runApp(const MaterialApp(
    home: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final yt = YoutubeExplode();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: FutureBuilder<Map<String, dynamic>>(
            future: fetchYoutubeData(),
            builder: ((context, snapshot) {
              if (snapshot.hasData) {
                return Text(snapshot.data.toString());
              }
              return const CircularProgressIndicator();
            })),
      ),
    );
  }

  Future<Map<String, dynamic>> fetchYoutubeData() async {
    final video = await yt.videos.get(tuneUrl);
    playAudio(tuneManifest);
    return {'name': video.title, 'author': video.author};
  }

  Future<void> playAudio(String manifest) async {
    final manifest = await yt.videos.streamsClient.getManifest(tuneManifest);
    final audioStreamInfo = manifest.audioOnly.withHighestBitrate();
    var stream = yt.videos.streamsClient.get(audioStreamInfo);

    final directory = await getTemporaryDirectory();
    final audioFile = File('${directory.path}/audio.mp3');
    var fileStream = audioFile.openWrite();
    stream.pipe(fileStream).then((value) async {
      await fileStream.flush();
      await fileStream.close();
      final ap = AudioPlayer();
      ap.play(BytesSource(audioFile.readAsBytesSync()));
    });
  }
}
