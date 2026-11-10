import 'package:flutter/foundation.dart';

/// Web uses its deployed host; native uses the same HTTPS API explicitly.
Uri get applicationOrigin => kIsWeb
    ? Uri.base.replace(path: '', query: '', fragment: '')
    : Uri.parse(
        const String.fromEnvironment(
          'API_ORIGIN',
          defaultValue: 'https://49.233.179.83',
        ),
      );
