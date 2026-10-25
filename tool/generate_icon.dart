import 'dart:io';

import 'package:image/image.dart' as img;

/// 生成应用图标资源：
/// - icon.png            纯色底 + 白色双箭头（用于传统图标 / Windows 图标）
/// - icon_background.png 纯色底（自适应图标背景层）
/// - icon_foreground.png 透明底 + 双箭头（自适应图标前景层，留安全区）
void main() {
  const size = 1024;

  final background = _flat(size);
  File('assets/icon/icon_background.png')
      .writeAsBytesSync(img.encodePng(background));

  final foreground = img.Image(width: size, height: size, numChannels: 4);
  _drawGlyph(foreground, scale: 0.78);
  File('assets/icon/icon_foreground.png')
      .writeAsBytesSync(img.encodePng(foreground));

  final combined = _flat(size);
  _drawGlyph(combined, scale: 1);
  File('assets/icon/icon.png').writeAsBytesSync(img.encodePng(combined));

  stdout.writeln('icons generated');
}

/// 纯色底：不带任何渐变或光晕，缩到小尺寸也不会脏。
img.Image _flat(int size) {
  // 和应用主色一致：AppPalette.accent
  const accent = [0x0A, 0x7A, 0xFF];
  final image = img.Image(width: size, height: size, numChannels: 4);
  return img.fill(
    image,
    color: img.ColorRgba8(accent[0], accent[1], accent[2], 255),
  );
}

/// 双箭头交换符号。scale 用于给自适应图标留出安全区。
void _drawGlyph(img.Image image, {required double scale}) {
  final white = img.ColorRgba8(255, 255, 255, 255);
  final center = 512.0;
  int tx(num value) => (center + (value - center) * scale).round();

  // 上箭头：粗横条 + 三角头，指向右。
  img.fillRect(
    image,
    x1: tx(196),
    y1: tx(392),
    x2: tx(688),
    y2: tx(468),
    radius: 38 * scale,
    color: white,
  );
  img.fillPolygon(
    image,
    vertices: [
      img.Point(tx(672), tx(348)),
      img.Point(tx(672), tx(512)),
      img.Point(tx(826), tx(430)),
    ],
    color: white,
  );

  // 下箭头：指向左。
  img.fillRect(
    image,
    x1: tx(336),
    y1: tx(556),
    x2: tx(828),
    y2: tx(632),
    radius: 38 * scale,
    color: white,
  );
  img.fillPolygon(
    image,
    vertices: [
      img.Point(tx(352), tx(512)),
      img.Point(tx(352), tx(676)),
      img.Point(tx(198), tx(594)),
    ],
    color: white,
  );
}
