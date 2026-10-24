import 'package:flutter/services.dart';

/// Uses Android's speech recognition and speech synthesis; no always-on recording.
class Voice {
  static const channel = MethodChannel('app.moneywise/voice');
  static Future<String> listen() async =>
      await channel.invokeMethod<String>('listen') ?? '';
  static Future<void> cancel() => channel.invokeMethod<void>('cancel');
  static Future<void> speak(String text) =>
      channel.invokeMethod<void>('speak', {'text': text});
  static Future<void> stop() => channel.invokeMethod<void>('stop');
}
