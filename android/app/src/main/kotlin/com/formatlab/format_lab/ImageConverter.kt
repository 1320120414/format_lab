package com.formatlab.format_lab

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.OutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.Locale

/**
 * 图片转换全部在本机完成：
 * 系统 ImageDecoder 负责解码（含 HEIC / AVIF / 动图首帧），Bitmap 负责缩放，
 * 编码后写进 MediaStore 的 Pictures/FormatLab，同时在缓存目录留一份给界面预览和分享。
 */
object ImageConverter {

    private const val GALLERY_FOLDER = "FormatLab"

    fun probe(inputPath: String): Map<String, Any> {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(inputPath, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            throw IOException("无法识别这个文件，可能不是图片")
        }
        return mapOf(
            "width" to bounds.outWidth,
            "height" to bounds.outHeight,
            "bytes" to File(inputPath).length(),
        )
    }

    fun convert(
        context: Context,
        inputPath: String,
        format: String,
        width: Int,
        height: Int,
        quality: Int,
        folder: String,
    ): Map<String, Any> {
        val sourceFile = File(inputPath)
        if (!sourceFile.exists()) throw IOException("源文件不存在")

        val key = format.lowercase(Locale.US)
        val target = resolveTarget(inputPath, width, height)
        val decoded = decode(sourceFile, inputPath, target)

        val extension = when (key) {
            "jpeg", "jpg" -> "jpg"
            "png" -> "png"
            "bmp" -> "bmp"
            "webp" -> "webp"
            else -> throw IOException("不支持的输出格式：$format")
        }
        val mime = when (extension) {
            "jpg" -> "image/jpeg"
            "png" -> "image/png"
            "bmp" -> "image/bmp"
            else -> "image/webp"
        }

        // JPEG / BMP 没有透明通道，透明区域直接铺白，避免变成黑块。
        val bitmap = if ((extension == "jpg" || extension == "bmp") && decoded.hasAlpha()) {
            flattenOntoWhite(decoded)
        } else {
            decoded
        }

        val outDir = File(context.cacheDir, "converted").apply { mkdirs() }
        cleanupOldFiles(outDir)
        val outFile = File(outDir, "${sourceFile.nameWithoutExtension}.$extension")

        FileOutputStream(outFile).use { out ->
            when (extension) {
                "bmp" -> encodeBmp(bitmap, out)
                else -> {
                    val compressFormat = when (extension) {
                        "jpg" -> Bitmap.CompressFormat.JPEG
                        "png" -> Bitmap.CompressFormat.PNG
                        else -> webpFormat()
                    }
                    val ok = bitmap.compress(compressFormat, quality.coerceIn(1, 100), out)
                    if (!ok) throw IOException("编码失败，请换一种输出格式")
                }
            }
        }

        val outWidth = bitmap.width
        val outHeight = bitmap.height
        if (bitmap !== decoded) bitmap.recycle()
        decoded.recycle()

        val uri = insertMedia(context, outFile, outFile.name, mime, "image", folder)

        return mapOf(
            "path" to outFile.absolutePath,
            "uri" to uri.toString(),
            "width" to outWidth,
            "height" to outHeight,
            "bytes" to outFile.length(),
        )
    }

    /** Dart 侧生成的 GIF、FFmpeg 转好的音视频，统一交给原生写进相册。 */
    fun saveMedia(
        context: Context,
        path: String,
        displayName: String,
        mime: String,
        kind: String,
        folder: String,
    ): Map<String, Any> {
        val file = File(path)
        if (!file.exists()) throw IOException("文件不存在")
        val uri = insertMedia(context, file, displayName, mime, kind, folder)
        return mapOf(
            "uri" to uri.toString(),
            "bytes" to file.length(),
        )
    }

    private fun resolveTarget(
        inputPath: String,
        requestedWidth: Int,
        requestedHeight: Int,
    ): Pair<Int, Int>? {
        if (requestedWidth <= 0 && requestedHeight <= 0) return null

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(inputPath, bounds)
        val sourceWidth = bounds.outWidth
        val sourceHeight = bounds.outHeight
        if (sourceWidth <= 0 || sourceHeight <= 0) return null

        return when {
            requestedWidth > 0 && requestedHeight > 0 ->
                Pair(requestedWidth, requestedHeight)
            requestedWidth > 0 -> Pair(
                requestedWidth,
                (requestedWidth.toLong() * sourceHeight / sourceWidth).toInt().coerceAtLeast(1),
            )
            else -> Pair(
                (requestedHeight.toLong() * sourceWidth / sourceHeight).toInt().coerceAtLeast(1),
                requestedHeight,
            )
        }
    }

    private fun decode(sourceFile: File, inputPath: String, target: Pair<Int, Int>?): Bitmap {
        try {
            val source = ImageDecoder.createSource(sourceFile)
            return ImageDecoder.decodeBitmap(source) { decoder, _, _ ->
                // 硬件 Bitmap 无法 compress，必须显式改用软件位图。
                decoder.setAllocator(ImageDecoder.ALLOCATOR_SOFTWARE)
                if (target != null) {
                    decoder.setTargetSize(target.first, target.second)
                }
            }
        } catch (_: Throwable) {
            // 少数机型对 HEIC / HDR 支持不完整，退回 BitmapFactory 再试一次。
            val options = BitmapFactory.Options().apply {
                inSampleSize = sampleSizeFor(inputPath, target)
            }
            val decoded = BitmapFactory.decodeFile(inputPath, options)
                ?: throw IOException("解码失败，这个文件可能已损坏")
            if (target == null) return decoded
            if (decoded.width == target.first && decoded.height == target.second) return decoded
            val scaled = Bitmap.createScaledBitmap(decoded, target.first, target.second, true)
            if (scaled !== decoded) decoded.recycle()
            return scaled
        }
    }

    private fun flattenOntoWhite(source: Bitmap): Bitmap {
        val flattened = Bitmap.createBitmap(source.width, source.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(flattened)
        canvas.drawColor(Color.WHITE)
        canvas.drawBitmap(source, 0f, 0f, null)
        return flattened
    }

    /** 手写 24 位 BMP 编码：Android 没有内置的 BMP 编码器。 */
    private fun encodeBmp(bitmap: Bitmap, out: OutputStream) {
        val width = bitmap.width
        val height = bitmap.height
        val rowSize = (width * 3 + 3) / 4 * 4
        val pixelSize = rowSize * height
        val fileSize = 54 + pixelSize

        val header = ByteBuffer.allocate(54).order(ByteOrder.LITTLE_ENDIAN)
        header.put('B'.code.toByte())
        header.put('M'.code.toByte())
        header.putInt(fileSize)
        header.putShort(0)
        header.putShort(0)
        header.putInt(54)
        header.putInt(40)
        header.putInt(width)
        header.putInt(height)
        header.putShort(1)
        header.putShort(24)
        header.putInt(0)
        header.putInt(pixelSize)
        header.putInt(2835)
        header.putInt(2835)
        header.putInt(0)
        header.putInt(0)
        out.write(header.array())

        val pixels = IntArray(width)
        val row = ByteArray(rowSize)
        for (y in height - 1 downTo 0) {
            bitmap.getPixels(pixels, 0, width, 0, y, width, 1)
            var index = 0
            for (x in 0 until width) {
                val color = pixels[x]
                row[index++] = (color and 0xFF).toByte()
                row[index++] = (color shr 8 and 0xFF).toByte()
                row[index++] = (color shr 16 and 0xFF).toByte()
            }
            while (index < rowSize) {
                row[index++] = 0
            }
            out.write(row)
        }
        out.flush()
    }

    @Suppress("DEPRECATION")
    private fun webpFormat(): Bitmap.CompressFormat =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Bitmap.CompressFormat.WEBP_LOSSY
        } else {
            Bitmap.CompressFormat.WEBP
        }

    private fun sampleSizeFor(inputPath: String, target: Pair<Int, Int>?): Int {
        if (target == null) return 1
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(inputPath, bounds)
        var sample = 1
        var width = bounds.outWidth
        var height = bounds.outHeight
        while (width / 2 >= target.first && height / 2 >= target.second) {
            width /= 2
            height /= 2
            sample *= 2
        }
        return sample
    }

    private fun insertMedia(
        context: Context,
        file: File,
        displayName: String,
        mime: String,
        kind: String,
        folder: String,
    ): Uri {
        val resolver = context.contentResolver
        val safeFolder = sanitizeFolder(folder)
        val collection: Uri
        val relativePath: String
        when (kind) {
            "video" -> {
                collection = MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                relativePath = Environment.DIRECTORY_MOVIES + File.separator + safeFolder
            }
            "audio" -> {
                collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
                relativePath = Environment.DIRECTORY_MUSIC + File.separator + safeFolder
            }
            else -> {
                collection = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                relativePath = Environment.DIRECTORY_PICTURES + File.separator + safeFolder
            }
        }

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val uri = resolver.insert(collection, values)
            ?: throw IOException("无法写入相册")

        try {
            resolver.openOutputStream(uri)?.use { out ->
                file.inputStream().use { input -> input.copyTo(out) }
            } ?: throw IOException("无法写入相册")
        } catch (t: Throwable) {
            resolver.delete(uri, null, null)
            throw t
        }

        values.clear()
        values.put(MediaStore.MediaColumns.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
        return uri
    }

    private fun sanitizeFolder(folder: String): String {
        val cleaned = folder.replace(Regex("[\\\\/:*?\"<>|\\s]"), "").replace("..", "")
        if (cleaned.isEmpty()) return GALLERY_FOLDER
        return if (cleaned.length > 32) cleaned.substring(0, 32) else cleaned
    }

    private fun cleanupOldFiles(dir: File) {
        val cutoff = System.currentTimeMillis() - 24L * 60 * 60 * 1000
        dir.listFiles()?.forEach { file ->
            if (file.lastModified() < cutoff) file.delete()
        }
    }
}
