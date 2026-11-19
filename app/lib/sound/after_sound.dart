// The sound after Done or Partly (Chi, thread 0007; design A and D). Off by default.
// Choices: a soft built-in chime (made in code, tools/sounds/make_chimes.py), BloomBack music (9 gentle tracks by
// Kevin MacLeod, CC BY 4.0, credit shown wherever they play; Chi, thread 0007, 16/11) or a song file the user picked,
// played on the phone only and never uploaded.
// Silent mode is respected: iOS "ambient" follows the silent switch; Android plays on the notification stream,
// which is muted when the phone is on silent or vibrate. During quiet hours it plays only through headphones.
// It stops after about 30 seconds or when the user taps pause.
// audio_session marks AudioDeviceType experimental; it is only used to tell headphones from the speaker.
// ignore_for_file: experimental_member_use
import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

enum SoundMode { off, chime, music, song }

class MusicTrack {
  final String id;
  final String title;
  final int seconds;
  const MusicTrack(this.id, this.title, this.seconds);
  String get asset => 'assets/music/$id.m4a';
  /// The credit CC BY 4.0 asks for (Chi's wording, thread 0007).
  String get credit => '"$title" Kevin MacLeod (incompetech.com) · Licensed under Creative Commons: By Attribution 4.0 · '
      'https://creativecommons.org/licenses/by/4.0/';
}

/// Chi's 9 approved tracks (thread 0007, 16/11), 48 kbps mono AAC made from incompetech's MP3s.
const kMusic = <MusicTrack>[
  MusicTrack('morning', 'Morning', 153),
  MusicTrack('clear-air', 'Clear Air', 183),
  MusicTrack('easy-lemon-30-second', 'Easy Lemon (30 second)', 31),
  MusicTrack('sunshine-ver-2', 'Sunshine (version 2)', 224),
  MusicTrack('water-lily', 'Water Lily', 144),
  MusicTrack('avec-soin', 'Avec Soin', 145),
  MusicTrack('senbazuru', 'Senbazuru', 94),
  MusicTrack('windswept', 'Windswept', 208),
  MusicTrack('summer-day', 'Summer Day', 198),
];

MusicTrack musicTrack(String id) => kMusic.firstWhere((m) => m.id == id, orElse: () => kMusic.first);
MusicTrack? trackOfAsset(String? asset) => kMusic.where((m) => m.asset == asset).firstOrNull;

/// The built-in chimes: asset file and the name shown in More.
const kChimes = <String, String>{
  'bell': 'assets/sounds/chime-bell.wav',
  'wind': 'assets/sounds/chime-wind.wav',
  'marimba': 'assets/sounds/chime-marimba.wav',
};

enum PlayResult { played, quietNeedsHeadphones, failed }

const kSoundCap = Duration(seconds: 30);

abstract class AfterSound {
  /// True while something plays (the Play/Pause button on the Today card).
  ValueListenable<bool> get playing;

  /// Plays one asset (a chime or a track) or a song file, up to 30 s. During quiet hours only through headphones.
  Future<PlayResult> play({String? asset, String? songPath, required bool quietHours});

  /// Music while doing the small step: the assets one after another (looping), or the song file on repeat,
  /// with no 30 s limit; pause, resume and next.
  Future<PlayResult> playSession({List<String> assets = const [], String? songPath, required bool quietHours});

  /// Which of the session's assets is playing (null when none or a song file).
  ValueListenable<String?> get nowAsset;

  Future<void> pause();
  Future<void> resume();
  Future<void> next();
  Future<void> stop();

  /// Headphones, a headset or Bluetooth audio are connected.
  Future<bool> headphones();
}

class PhoneSound implements AfterSound {
  AudioPlayer? _player;
  Timer? _cap;
  bool _configured = false;
  final _playing = ValueNotifier(false);
  final _nowAsset = ValueNotifier<String?>(null);
  List<String> _sessionAssets = const [];
  StreamSubscription<int?>? _indexSub;

  @override
  ValueListenable<bool> get playing => _playing;

  @override
  ValueListenable<String?> get nowAsset => _nowAsset;

  Future<AudioSession> _session() async {
    final session = await AudioSession.instance;
    if (!_configured) {
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.ambient,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          usage: AndroidAudioUsage.notification,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      ));
      _configured = true;
    }
    return session;
  }

  static const _headphoneTypes = {
    AudioDeviceType.wiredHeadset,
    AudioDeviceType.wiredHeadphones,
    AudioDeviceType.bluetoothA2dp,
    AudioDeviceType.bluetoothSco,
    AudioDeviceType.bluetoothLe,
    AudioDeviceType.hearingAid,
    AudioDeviceType.usbAudio,
  };

  @override
  Future<bool> headphones() async {
    try {
      final devices = await (await _session()).getDevices(includeInputs: false);
      return devices.any((d) => _headphoneTypes.contains(d.type));
    } catch (_) {
      return false; // unknown: treat as the speaker, so quiet hours stay quiet
    }
  }

  @override
  Future<PlayResult> play({String? asset, String? songPath, required bool quietHours}) async {
    if (asset == null && songPath == null) return PlayResult.failed;
    if (quietHours && !await headphones()) return PlayResult.quietNeedsHeadphones;
    try {
      await stop();
      await _session();
      final p = _player ??= AudioPlayer();
      await p.setLoopMode(LoopMode.off);
      if (asset != null) {
        await p.setAsset(asset);
      } else {
        await p.setFilePath(songPath!);
      }
      _nowAsset.value = asset;
      _playing.value = true;
      _cap = Timer(kSoundCap, stop);
      // play() completes when the sound ends, is paused or is stopped.
      unawaited(p.play().whenComplete(() {
        _cap?.cancel();
        _playing.value = false;
      }));
      return PlayResult.played;
    } catch (_) {
      _playing.value = false;
      return PlayResult.failed;
    }
  }

  @override
  Future<PlayResult> playSession({List<String> assets = const [], String? songPath, required bool quietHours}) async {
    if (assets.isEmpty && songPath == null) return PlayResult.failed;
    if (quietHours && !await headphones()) return PlayResult.quietNeedsHeadphones;
    try {
      await stop();
      await _session();
      final p = _player ??= AudioPlayer();
      if (songPath != null) {
        _sessionAssets = const [];
        await p.setFilePath(songPath);
        await p.setLoopMode(LoopMode.one);
        _nowAsset.value = null;
      } else {
        _sessionAssets = assets;
        await p.setAudioSources([for (final a in assets) AudioSource.asset(a)]);
        await p.setLoopMode(LoopMode.all);
        _indexSub = p.currentIndexStream.listen((i) => _nowAsset.value = i == null ? null : _sessionAssets[i]);
      }
      _playing.value = true;
      unawaited(p.play());
      return PlayResult.played;
    } catch (_) {
      _playing.value = false;
      return PlayResult.failed;
    }
  }

  @override
  Future<void> pause() async {
    _playing.value = false;
    await _player?.pause();
  }

  @override
  Future<void> resume() async {
    final p = _player;
    if (p == null) return;
    _playing.value = true;
    unawaited(p.play());
  }

  @override
  Future<void> next() async {
    final p = _player;
    if (p == null || _sessionAssets.isEmpty) return;
    await p.seekToNext();
  }

  @override
  Future<void> stop() async {
    _cap?.cancel();
    _cap = null;
    await _indexSub?.cancel();
    _indexSub = null;
    _sessionAssets = const [];
    _playing.value = false;
    _nowAsset.value = null;
    await _player?.stop();
  }
}

/// For tests and the web demo: remembers what it was asked to play, makes no sound.
class SilentSound implements AfterSound {
  final plays = <String>[];
  final sessions = <List<String>>[];
  bool headphonesIn;
  final _playing = ValueNotifier(false);
  final _nowAsset = ValueNotifier<String?>(null);
  List<String> _list = const [];
  SilentSound({this.headphonesIn = false});

  @override
  ValueListenable<bool> get playing => _playing;

  @override
  ValueListenable<String?> get nowAsset => _nowAsset;

  @override
  Future<PlayResult> playSession({List<String> assets = const [], String? songPath, required bool quietHours}) async {
    if (quietHours && !headphonesIn) return PlayResult.quietNeedsHeadphones;
    _list = songPath != null ? [songPath] : assets;
    sessions.add(_list);
    _nowAsset.value = songPath == null && assets.isNotEmpty ? assets.first : null;
    _playing.value = true;
    return PlayResult.played;
  }

  @override
  Future<void> pause() async => _playing.value = false;

  @override
  Future<void> resume() async => _playing.value = true;

  @override
  Future<void> next() async {
    final i = _list.indexOf(_nowAsset.value ?? '');
    if (i >= 0 && _list.isNotEmpty) _nowAsset.value = _list[(i + 1) % _list.length];
  }

  @override
  Future<bool> headphones() async => headphonesIn;

  @override
  Future<PlayResult> play({String? asset, String? songPath, required bool quietHours}) async {
    if (quietHours && !headphonesIn) return PlayResult.quietNeedsHeadphones;
    plays.add(asset ?? songPath ?? '');
    _nowAsset.value = asset;
    _playing.value = true;
    return PlayResult.played;
  }

  @override
  Future<void> stop() async {
    _playing.value = false;
    _nowAsset.value = null;
  }
}
