import 'package:flutter_test/flutter_test.dart';
import 'package:format_lab/domain/models.dart';
import 'package:format_lab/infrastructure/ffmpeg_engine.dart';

void main() {
  test('音频转 MP3 使用 libmp3lame 并带上码率', () {
    final plan = planFor(
      const AudioConvertSpec(format: AudioFormat.mp3, bitrateKbps: 256),
      inputPath: '/tmp/in.wav',
      outputPath: '/tmp/out.mp3',
    );
    final args = plan.arguments.join(' ');

    expect(plan.extension, 'mp3');
    expect(plan.mime, 'audio/mpeg');
    expect(plan.kind, MediaKind.audio);
    expect(args, contains('libmp3lame'));
    expect(args, contains('-b:a 256k'));
    expect(args, contains('-vn'));
  });

  test('WAV 不写码率，改用 PCM', () {
    final plan = planFor(
      const ExtractAudioSpec(format: AudioFormat.wav),
      inputPath: '/tmp/in.mp4',
      outputPath: '/tmp/out.wav',
    );
    final args = plan.arguments.join(' ');

    expect(args, contains('pcm_s16le'));
    expect(args, isNot(contains('-b:a')));
    expect(plan.extension, 'wav');
  });

  test('视频压缩按档位取 crf 并限制分辨率', () {
    final plan = planFor(
      const VideoCompressSpec(
        preset: VideoPreset.small,
        resolution: VideoResolution.p720,
      ),
      inputPath: '/tmp/in.mov',
      outputPath: '/tmp/out.mp4',
    );
    final args = plan.arguments.join(' ');

    expect(plan.extension, 'mp4');
    expect(plan.kind, MediaKind.video);
    expect(args, contains('libx264'));
    expect(args, contains('-crf 29'));
    expect(args, contains('min(iw,1280)'));
  });

  test('转封装只换容器不重编码', () {
    final plan = planFor(
      const VideoRemuxSpec(container: VideoContainer.mkv),
      inputPath: '/tmp/in.mp4',
      outputPath: '/tmp/out.mkv',
    );

    expect(plan.arguments, contains('copy'));
    expect(plan.arguments.join(' '), isNot(contains('libx264')));
    expect(plan.extension, 'mkv');
  });
}
