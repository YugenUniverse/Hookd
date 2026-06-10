import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Returns the correct [ImageProvider] for an avatar string, which may be:
/// - a remote URL (http/https) → [NetworkImage]
/// - a base64 data URI (data:image/...;base64,...) → [MemoryImage]
/// Returns null if the string is empty or cannot be decoded.
ImageProvider? avatarImageProvider(String? avatar) {
  if (avatar == null || avatar.isEmpty) return null;

  if (avatar.startsWith('data:')) {
    final commaIdx = avatar.indexOf(',');
    if (commaIdx == -1) return null;
    try {
      final Uint8List bytes = base64Decode(avatar.substring(commaIdx + 1));
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  return NetworkImage(avatar);
}
