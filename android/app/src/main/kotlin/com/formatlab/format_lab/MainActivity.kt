package com.formatlab.format_lab

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    private val channelName = "formatlab/image"
    private val executor = Executors.newFixedThreadPool(2)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "convert" -> {
                        val inputPath = call.argument<String>("inputPath")
                        val format = call.argument<String>("format")
                        val width = call.argument<Int>("width") ?: 0
                        val height = call.argument<Int>("height") ?: 0
                        val quality = call.argument<Int>("quality") ?: 90
                        val folder = call.argument<String>("folder") ?: "FormatLab"

                        if (inputPath == null || format == null) {
                            result.error("bad_args", "缺少 inputPath 或 format", null)
                            return@setMethodCallHandler
                        }

                        executor.execute {
                            try {
                                val payload = ImageConverter.convert(
                                    context = applicationContext,
                                    inputPath = inputPath,
                                    format = format,
                                    width = width,
                                    height = height,
                                    quality = quality,
                                    folder = folder,
                                )
                                runOnUiThread { result.success(payload) }
                            } catch (t: Throwable) {
                                runOnUiThread {
                                    result.error("convert_failed", t.message ?: "转换失败", null)
                                }
                            }
                        }
                    }

                    "saveMedia" -> {
                        val path = call.argument<String>("path")
                        val displayName = call.argument<String>("displayName")
                        val mime = call.argument<String>("mime") ?: "application/octet-stream"
                        val kind = call.argument<String>("kind") ?: "image"
                        val folder = call.argument<String>("folder") ?: "FormatLab"

                        if (path == null || displayName == null) {
                            result.error("bad_args", "缺少 path 或 displayName", null)
                            return@setMethodCallHandler
                        }

                        executor.execute {
                            try {
                                val payload = ImageConverter.saveMedia(
                                    context = applicationContext,
                                    path = path,
                                    displayName = displayName,
                                    mime = mime,
                                    kind = kind,
                                    folder = folder,
                                )
                                runOnUiThread { result.success(payload) }
                            } catch (t: Throwable) {
                                runOnUiThread {
                                    result.error("save_failed", t.message ?: "保存失败", null)
                                }
                            }
                        }
                    }

                    "probe" -> {
                        val inputPath = call.argument<String>("inputPath")
                        if (inputPath == null) {
                            result.error("bad_args", "缺少 inputPath", null)
                            return@setMethodCallHandler
                        }
                        executor.execute {
                            try {
                                val payload = ImageConverter.probe(inputPath)
                                runOnUiThread { result.success(payload) }
                            } catch (t: Throwable) {
                                runOnUiThread {
                                    result.error("probe_failed", t.message ?: "读取失败", null)
                                }
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        executor.shutdown()
        super.onDestroy()
    }
}
