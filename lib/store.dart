import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'domain.dart';

String newId() => List.generate(
  16,
  (_) => Random.secure().nextInt(256),
).map((v) => v.toRadixString(16).padLeft(2, '0')).join();

class AppStore extends ChangeNotifier {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
  );
  static const native = MethodChannel('app.moneywise/capture');
  Ledger ledger = Ledger();
  bool loaded = false, busy = false;
  String? failure;
  String aiUrl = '', aiToken = '';
  Future<void> load() async {
    try {
      final raw = await _storage.read(key: 'ledger.v1');
      ledger = raw == null ? Ledger() : Ledger.decode(raw);
      validateLedger(ledger);
      aiUrl = await _storage.read(key: 'coach.url') ?? '';
      aiToken = await _storage.read(key: 'coach.token') ?? '';
      loaded = true;
      failure = null;
    } catch (_) {
      failure =
          'Your saved data could not be opened. Nothing has been overwritten. Retry or restore a backup after checking device storage.';
    }
    notifyListeners();
  }

  Future<void> change(void Function(Ledger) edit) async {
    if (busy || !loaded) throw StateError('Storage is busy. Please retry.');
    busy = true;
    notifyListeners();
    try {
      final next = Ledger.decode(ledger.encode());
      edit(next);
      validateLedger(next);
      await _storage.write(key: 'ledger.v1', value: next.encode());
      ledger = next;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> restore(Ledger backup) async {
    if (busy) {
      throw StateError('Storage is busy. Please retry.');
    }
    validateLedger(backup);
    busy = true;
    notifyListeners();
    try {
      final copy = Ledger.decode(backup.encode());
      await _storage.write(key: 'ledger.v1', value: copy.encode());
      ledger = copy;
      loaded = true;
      failure = null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> configureCoach(String url, String token) async {
    if (url.isNotEmpty &&
        (Uri.tryParse(url)?.scheme != 'https' ||
            Uri.tryParse(url)?.host.isEmpty != false)) {
      throw const FormatException('Use an HTTPS server URL.');
    }
    await _storage.write(key: 'coach.token', value: token);
    await _storage.write(
      key: 'coach.url',
      value: url.replaceFirst(RegExp(r'/+$'), ''),
    );
    aiUrl = url.replaceFirst(RegExp(r'/+$'), '');
    aiToken = token;
    notifyListeners();
  }

  Future<void> erase() async {
    if (busy) throw StateError('Wait for the current save.');
    busy = true;
    notifyListeners();
    try {
      // Clear capture history before clearing the ledger to avoid reimport on next launch.
      if (defaultTargetPlatform == TargetPlatform.android && !kIsWeb) {
        await native.invokeMethod<void>('clear');
      }
      await _storage.deleteAll();
      ledger = Ledger();
      aiUrl = '';
      aiToken = '';
      failure = null;
      loaded = true;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> pending() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return [];
    final raw = await native.invokeMethod<String>('pending') ?? '[]';
    return (jsonDecode(raw) as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> acknowledge(String id) =>
      native.invokeMethod<void>('ack', {'id': id});
}
