import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
void main(){TestWidgetsFlutterBinding.ensureInitialized();test('All 96 course illustrations decode with the production SVG renderer',()async{final files=Directory('assets/avatar/images').listSync().whereType<File>().where((f)=>f.path.split(Platform.pathSeparator).last.startsWith('cover-')&&f.path.endsWith('.svg')).toList();expect(files.length,96);for(final file in files){final picture=await vg.loadPicture(SvgStringLoader(file.readAsStringSync()),null);expect(picture.size.width,320,reason:file.path);picture.picture.dispose();}});}
