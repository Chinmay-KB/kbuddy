import 'dart:developer';
import 'dart:io';
import 'dart:math' hide log;

import 'package:audioplayers/audioplayers.dart';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_audio/return_code.dart';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final tuneUrl = 'https://www.youtube.com/watch?v=R2sxMVRgybI';
final tuneManifest = 'R2sxMVRgybI';
final record = Record();

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
        child: Column(
          children: [
            TextButton(
              onPressed: () {
                playAudio(tuneManifest);
              },
              child: Text('Play Audio'),
            ),
            TextButton(
              onPressed: () {
                if (!recordingAudio)
                  recordAudio();
                else
                  stopRecording();
              },
              child: Text(
                  recordingAudio ? 'Stop recording and play' : 'Record Audio'),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> fetchYoutubeData() async {
    final video = await yt.videos.get(tuneUrl);
    return {'name': video.title, 'author': video.author};
  }

  bool recordingAudio = false;
  Future<void> recordAudio() async {
    if (await Permission.microphone.request().isGranted) {
      final directory = await getTemporaryDirectory();
      final randomNo = Random().nextInt(1000).toString();
      recordingPath = '${directory.path}/$randomNo.mp3';
      setState(() {
        recordingAudio = true;
      });
      await record.start(
        path: recordingPath,
        encoder: AudioEncoder.opus, // by default
        bitRate: 128000, // by default
        // by default
      );
    }
  }

  String? recordingPath;

  Future<void> stopRecording() async {
    final path = await record.stop();
    setState(() {
      recordingAudio = true;
    });
    if (path != null) {
      mixBothAudios(path);
    }
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

  Future<String> audioSource() async {
    final manifest = await yt.videos.streamsClient.getManifest(tuneManifest);
    final audioStreamInfo = manifest.audioOnly.withHighestBitrate();
    var stream = yt.videos.streamsClient.get(audioStreamInfo);

    final directory = await getTemporaryDirectory();
    final audioFile = File('${directory.path}/audio.mp3');
    var fileStream = audioFile.openWrite();
    await stream.pipe(fileStream);
    await fileStream.flush();
    await fileStream.close();
    return audioFile.path;
  }

  Future<void> mixBothAudios(String recording) async {
    final directory = await getTemporaryDirectory();
    final randomNo = Random().nextInt(1000).toString();
    final outputPath = '${directory.path}/${randomNo}_output.mp3';
    final youtubeAudioPath = await audioSource();
    final result = await FFmpegKit.execute(
        '-i ${youtubeAudioPath} -i ${recording} -filter_complex amix=inputs=2:duration=first $outputPath');
    // ffmpeg
    if (ReturnCode.isSuccess(await result.getReturnCode())) {
      final ap = AudioPlayer();
      ap.play(BytesSource(File(outputPath).readAsBytesSync()));
    } else if (ReturnCode.isCancel(await result.getReturnCode())) {
    } else {
      log((await result.getAllLogsAsString()) ?? 'No logs');
    }
  }
}
