class BrowserGraphicsWatch {
  String get lastReason => 'G1';
  BrowserGraphicsWatch(void Function() onLost, {void Function()? onFrame});
  void dispose() {}
}

void reloadForGraphicsRecovery() {}
