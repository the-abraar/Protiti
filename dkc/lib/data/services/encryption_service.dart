import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'secure_store.dart';

/// Evidence files are AES-256-GCM in 64 KiB chunks: a long recording is never
/// held whole in memory, and any change to a file makes decryption fail.
///
/// Layout: magic `\0PRT` (4 bytes), version (1), random file id (16), then per
/// chunk a random 12-byte nonce, the ciphertext and a 16-byte tag. Each chunk's
/// associated data is file id + chunk index + last-chunk flag, so chunks cannot
/// be reordered, dropped, cut off or swapped in from another file.
///
/// Files written before Oct 2026 are AES-CTR text (`iv:ciphertext`, base64 of
/// base64) with no tag. They still open, and are rewritten in the new format
/// the first time they are read.
class EncryptionService {
  final FlutterSecureStorage _storage = secureStore;
  static const String _keyKey = StoreKeys.evidenceKey;

  static const chunkSize = 64 * 1024;
  // The old format is base64 text, which never starts with a zero byte.
  static const _magic = [0x00, 0x50, 0x52, 0x54];
  static const _version = 1;
  static const _headerLength = 21;
  static const _nonceLength = 12;
  static const _tagLength = 16;

  Future<Key> _getKey() async {
    String? base64Key = await _storage.read(key: _keyKey);
    if (base64Key == null) {
      final secureRandom = Random.secure();
      final keyBytes = List<int>.generate(32, (_) => secureRandom.nextInt(256));
      base64Key = base64UrlEncode(keyBytes);
      await _storage.write(key: _keyKey, value: base64Key);
    }
    return Key.fromBase64(base64Key);
  }

  /// Encrypts [plain] into [out] and returns the SHA-256 (hex) of the
  /// plaintext, computed in the same pass, before anything else touches it.
  Future<String> encryptFile(File plain, File out) async {
    final src = await plain.open();
    try {
      return await _encrypt((n) => _readFull(src, n), out);
    } finally {
      await src.close();
    }
  }

  /// The whole plaintext of an evidence file. For photos; use [decryptToFile]
  /// for anything that may be large.
  Future<Uint8List> decryptToBytes(File encrypted) async {
    final legacy = await _migrateIfLegacy(encrypted);
    if (legacy != null) return legacy;
    final out = BytesBuilder(copy: false);
    await _decrypt(encrypted, (chunk) async => out.add(chunk));
    return out.takeBytes();
  }

  /// Streams the plaintext of an evidence file into [out], one chunk at a time.
  Future<void> decryptToFile(File encrypted, File out) async {
    final legacy = await _migrateIfLegacy(encrypted);
    if (legacy != null) {
      await out.writeAsBytes(legacy, flush: true);
      return;
    }
    final dst = await out.open(mode: FileMode.write);
    try {
      await _decrypt(encrypted, (chunk) => dst.writeFrom(chunk));
    } finally {
      await dst.close();
    }
  }

  Future<String> _encrypt(Future<Uint8List> Function(int n) read, File out) async {
    final aes = Encrypter(AES(await _getKey(), mode: AESMode.gcm));
    final fileId = IV.fromSecureRandom(16).bytes;
    late Digest digest;
    final hash = sha256.startChunkedConversion(
      ChunkedConversionSink<Digest>.withCallback((d) => digest = d.single),
    );
    final dst = await out.open(mode: FileMode.write);
    try {
      await dst.writeFrom([..._magic, _version, ...fileId]);
      var chunk = await read(chunkSize);
      for (var index = 0;; index++) {
        final next = chunk.length == chunkSize ? await read(chunkSize) : Uint8List(0);
        final last = next.isEmpty;
        hash.add(chunk);
        final nonce = IV.fromSecureRandom(_nonceLength);
        final sealed = aes.encryptBytes(chunk, iv: nonce, associatedData: _aad(fileId, index, last));
        await dst.writeFrom(nonce.bytes);
        await dst.writeFrom(sealed.bytes);
        if (last) break;
        chunk = next;
      }
      await dst.flush();
    } finally {
      await dst.close();
    }
    hash.close();
    return digest.toString();
  }

  Future<void> _decrypt(File encrypted, Future<void> Function(Uint8List chunk) emit) async {
    final aes = Encrypter(AES(await _getKey(), mode: AESMode.gcm));
    const sealedSize = _nonceLength + chunkSize + _tagLength;
    final src = await encrypted.open();
    try {
      final header = await _readFull(src, _headerLength);
      if (!_isCurrent(header) || header[4] != _version) {
        throw const FormatException('Unknown evidence file format');
      }
      final fileId = header.sublist(5);
      var chunk = await _readFull(src, sealedSize);
      for (var index = 0;; index++) {
        if (chunk.length < _nonceLength + _tagLength) {
          throw const FormatException('Evidence file is cut short');
        }
        final next = chunk.length == sealedSize ? await _readFull(src, sealedSize) : Uint8List(0);
        final last = next.isEmpty;
        final plain = aes.decryptBytes(
          Encrypted(chunk.sublist(_nonceLength)),
          iv: IV(chunk.sublist(0, _nonceLength)),
          associatedData: _aad(fileId, index, last),
        );
        await emit(Uint8List.fromList(plain));
        if (last) return;
        chunk = next;
      }
    } finally {
      await src.close();
    }
  }

  static Uint8List _aad(Uint8List fileId, int index, bool last) {
    final aad = ByteData(fileId.length + 5);
    for (var i = 0; i < fileId.length; i++) {
      aad.setUint8(i, fileId[i]);
    }
    aad.setUint32(fileId.length, index);
    aad.setUint8(fileId.length + 4, last ? 1 : 0);
    return aad.buffer.asUint8List();
  }

  static bool _isCurrent(Uint8List header) {
    if (header.length != _headerLength) return false;
    for (var i = 0; i < _magic.length; i++) {
      if (header[i] != _magic[i]) return false;
    }
    return true;
  }

  /// Reads exactly [n] bytes unless the file ends first, so chunk boundaries
  /// never depend on how the OS splits reads.
  static Future<Uint8List> _readFull(RandomAccessFile file, int n) async {
    final out = BytesBuilder(copy: false);
    while (out.length < n) {
      final part = await file.read(n - out.length);
      if (part.isEmpty) break;
      out.add(part);
    }
    return out.takeBytes();
  }

  /// Returns the plaintext of an old-format file after rewriting it in the
  /// current format, or null if the file is already current. The old file is
  /// replaced only once the new one decrypts to the same SHA-256; if anything
  /// fails, the old file stays as it was and still opens.
  Future<Uint8List?> _migrateIfLegacy(File encrypted) async {
    final src = await encrypted.open();
    final Uint8List head;
    try {
      head = await _readFull(src, _headerLength);
    } finally {
      await src.close();
    }
    if (_isCurrent(head)) return null;

    final plain = await _decryptLegacy(await encrypted.readAsString());
    // A unique name, so two screens reading the same old file cannot collide.
    final tmp = File('${encrypted.path}.${const Uuid().v4()}.tmp');
    try {
      var offset = 0;
      final hash = await _encrypt((n) async {
        final end = min(offset + n, plain.length);
        final part = Uint8List.sublistView(plain, offset, end);
        offset = end;
        return part;
      }, tmp);
      final check = BytesBuilder(copy: false);
      await _decrypt(tmp, (chunk) async => check.add(chunk));
      if (hash != sha256.convert(check.takeBytes()).toString()) {
        throw StateError('Rewritten evidence file does not match the original');
      }
      await tmp.rename(encrypted.path);
    } catch (_) {
      try {
        await tmp.delete();
      } catch (_) {}
    }
    return plain;
  }

  Future<Uint8List> _decryptLegacy(String text) async {
    final parts = text.split(':');
    // Very early builds stored base64 without encryption.
    if (parts.length != 2) return base64Decode(text);
    final legacy = Encrypter(AES(await _getKey()));
    return base64Decode(legacy.decrypt(Encrypted.fromBase64(parts[1]), iv: IV.fromBase64(parts[0])));
  }
}
