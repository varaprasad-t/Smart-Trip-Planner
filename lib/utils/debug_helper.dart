import 'package:flutter/material.dart';

String debugSafeFirstChar(String? str, {String fallback = 'T'}) {
  if (str == null) {
    debugPrint("⚠️ [0] called on NULL string");
    return fallback;
  }
  if (str.isEmpty) {
    debugPrint("⚠️ [0] called on EMPTY string");
    return fallback;
  }
  return str[0];
}
