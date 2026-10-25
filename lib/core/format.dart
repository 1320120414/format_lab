String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  var size = bytes.toDouble();
  var index = 0;
  while (size >= 1024 && index < units.length - 1) {
    size /= 1024;
    index++;
  }
  final digits = index == 0 || size >= 100 ? 0 : 1;
  return '${size.toStringAsFixed(digits)} ${units[index]}';
}

String formatDelta(int before, int after) {
  if (before <= 0 || after <= 0) return formatBytes(after);
  return '${formatBytes(before)} → ${formatBytes(after)}';
}

int savingsPercent(int before, int after) {
  if (before <= 0 || after <= 0) return 0;
  final percent = ((before - after) / before * 100).round();
  return percent;
}

String formatMoment(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(time.year, time.month, time.day);
  final diffDays = today.difference(target).inDays;
  final hh = time.hour.toString().padLeft(2, '0');
  final mm = time.minute.toString().padLeft(2, '0');

  if (diffDays == 0) return '今天 $hh:$mm';
  if (diffDays == 1) return '昨天 $hh:$mm';
  if (diffDays < 7) return '$diffDays 天前';
  return '${time.month} 月 ${time.day} 日';
}

String dimensionLabel(int? width, int? height) {
  if (width == null || height == null || width <= 0 || height <= 0) return '';
  return '$width × $height';
}
