import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every repaired trouser vertex is normalized and bound only to lower-body joints', () {
    const path = 'assets/avatar/models/storm-clothing-bindings';
    final manifest = jsonDecode(File('$path.json').readAsStringSync());
    final bytes = File('$path.bin').readAsBytesSync(),
        data = ByteData.sublistView(bytes);
    expect(sha256.convert(bytes).toString(), manifest['bindingsSha256']);
    final names = List<String>.from(manifest['jointNames']);
    var checked = 0;
    for (final part in manifest['parts']) {
      for (var v = 0; v < part['vertices']; v++) {
        var sum = 0.0;
        for (var k = 0; k < 4; k++) {
          final offset = (part['floatOffset'] + v * 8) as int;
          final joint = data.getFloat32((offset + k) * 4, Endian.little);
          final weight = data.getFloat32((offset + 4 + k) * 4, Endian.little);
          expect(joint, inInclusiveRange(0, names.length - 1));
          expect(weight.isFinite, true);
          expect(weight, greaterThanOrEqualTo(0));
          if (weight > 1e-5) {
            expect(
              names[joint.toInt()],
              matches(r'^DEF-(Spine[12]$|Thigh_|Knee_|PantLeg)'),
            );
          }
          sum += weight;
        }
        expect(sum, closeTo(1, .0001));
        checked++;
      }
    }
    expect(checked, 15392);
  });
}
