import 'dart:convert';
import 'dart:typed_data';
import 'package:scene/scene.dart';

/// The same container contract as scene.readFsceneb, with asynchronous gzip
/// decoding and a yield between chunks. Inflated chunks own their storage, so
/// payload views need not make a second copy of a large decompressed buffer.
Future<SceneDocument> readFscenebYielding(
  Uint8List bytes, {
  required Future<Uint8List> Function(Uint8List) inflate,
}) async {
  if (bytes.length < 16 || ascii.decode(bytes.sublist(0, 4)) != 'FSCB') {
    throw const FscenebFormatException('Invalid scene container header');
  }
  final view = ByteData.sublistView(bytes);
  if (view.getUint32(4, Endian.little) > kFscenebVersion) {
    throw const FscenebFormatException('Unsupported scene container version');
  }
  final total = view.getUint32(8, Endian.little);
  if (total < 16 || total > bytes.length) {
    throw const FscenebFormatException('Invalid scene container length');
  }
  String? manifest;
  final blobs = <LocalId, Uint8List>{}, unknown = <UnknownChunk>[];
  var offset = 16, index = 0;
  while (offset + 8 <= total) {
    final length = view.getUint32(offset, Endian.little);
    final type = ascii.decode(
      Uint8List.sublistView(bytes, offset + 4, offset + 8),
    );
    final start = offset + 8, end = start + length;
    if (end > total)
      throw const FscenebFormatException('Truncated scene chunk');
    var data = Uint8List.sublistView(bytes, start, end);
    if (type == 'JSON') {
      manifest = utf8.decode(data);
    } else if (type == 'BLOB' || type == 'GZBL') {
      if (type == 'GZBL') data = await inflate(data);
      if (data.length < 4)
        throw const FscenebFormatException('Truncated payload');
      final tokenEnd =
          4 + ByteData.sublistView(data).getUint32(0, Endian.little);
      if (tokenEnd > data.length)
        throw const FscenebFormatException('Invalid payload ID');
      final id = LocalId.parse(
        ascii.decode(Uint8List.sublistView(data, 4, tokenEnd)),
      );
      final payload = Uint8List.sublistView(data, tokenEnd);
      // Uncompressed views would pin the entire input container in memory.
      if (type == 'GZBL') {
        // Move the owned inflated payload over its variable-length ID header.
        // A view starting after that header can be unaligned for Float32List /
        // matrix consumers even though its bytes are otherwise identical.
        data.setRange(0, payload.length, payload);
        blobs[id] = Uint8List.sublistView(data, 0, payload.length);
      } else {
        blobs[id] = Uint8List.fromList(payload);
      }
    } else {
      unknown.add(
        UnknownChunk(index: index, type: type, data: Uint8List.fromList(data)),
      );
    }
    offset = start + length + ((-length) & 7);
    index++;
    await Future<void>.delayed(Duration.zero);
  }
  if (manifest == null)
    throw const FscenebFormatException('Missing scene manifest');
  final document = readFscene(manifest);
  blobs.forEach((id, bytes) {
    document.payload(id)?.bytes = bytes;
  });
  document.unknownChunks.addAll(unknown);
  return document;
}
