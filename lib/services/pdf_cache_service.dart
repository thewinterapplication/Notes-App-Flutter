import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/pdf_file.dart';

class PdfCacheResult {
  final String filePath;
  final bool fromCache;

  const PdfCacheResult({required this.filePath, required this.fromCache});
}

class PdfDownloadException implements Exception {
  final int? statusCode;
  final String message;

  const PdfDownloadException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class PdfCacheService {
  static const Duration _requestTimeout = Duration(seconds: 45);
  static const int _progressLogIntervalBytes = 512 * 1024; // 512 KB
  // %%EOF bytes — first occurrence in a linearized PDF marks the end of the
  // first-page section, which is a valid standalone PDF Android can open.
  static const List<int> _pdfEofMarker = [0x25, 0x25, 0x45, 0x4F, 0x46];
  static final Map<String, Future<PdfCacheResult>> _activeDownloads = {};
  static final Map<String, Future<Uint8List>> _activePageFetches = {};
  static final http.Client _pageHttpClient = http.Client();

  static String _formatLogDetails(Map<String, Object?> details) {
    return details.entries
        .where((entry) => entry.value != null)
        .map((entry) {
          final value = entry.value;
          final rendered = value is String ? jsonEncode(value) : value;
          return '${entry.key}=$rendered';
        })
        .join(' ');
  }

  static void _log(String message, [Map<String, Object?> details = const {}]) {
    final suffix = _formatLogDetails(details);
    debugPrint('[PDFCache] $message${suffix.isEmpty ? '' : ' $suffix'}');
  }

  static void _logError(
    String message,
    Object error, [
    Map<String, Object?> details = const {},
  ]) {
    final suffix = _formatLogDetails(details);
    debugPrint(
      '[PDFCache] $message${suffix.isEmpty ? '' : ' $suffix'} error=$error',
    );
  }

  static String _shorten(String value, [int maxLength = 500]) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength)}...';
  }

  static Future<PdfCacheResult> getOrDownloadPdf({
    required PdfFile pdfFile,
    required String userPhone,
    void Function(int receivedBytes, int? totalBytes)? onProgress,
    void Function(String partialPath)? onPartialReady,
  }) {
    final cacheKey = pdfFile.cacheKey;
    final inFlight = _activeDownloads[cacheKey];
    if (inFlight != null) {
      _log('reuse-active-download', {
        'documentId': pdfFile.id,
        'cacheKey': cacheKey,
        'downloadUrl': pdfFile.downloadUrl,
      });
      return inFlight;
    }

    _log('request-start', {
      'documentId': pdfFile.id,
      'cacheKey': cacheKey,
      'downloadUrl': pdfFile.downloadUrl,
    });

    final future = _getOrDownloadPdfInternal(
      pdfFile: pdfFile,
      userPhone: userPhone,
      onProgress: onProgress,
      onPartialReady: onPartialReady,
    );

    _activeDownloads[cacheKey] = future;
    void clearActiveDownload() {
      _activeDownloads.remove(cacheKey);
      _log('request-finished', {
        'documentId': pdfFile.id,
        'cacheKey': cacheKey,
      });
    }

    unawaited(
      future.then<void>(
        (_) => clearActiveDownload(),
        onError: (_) => clearActiveDownload(),
      ),
    );

    return future;
  }

  static Future<PdfCacheResult> _getOrDownloadPdfInternal({
    required PdfFile pdfFile,
    required String userPhone,
    void Function(int receivedBytes, int? totalBytes)? onProgress,
    void Function(String partialPath)? onPartialReady,
  }) async {
    final cacheDirectory = await _getCacheDirectory();
    final finalFile = File(
      '${cacheDirectory.path}${Platform.pathSeparator}${pdfFile.cacheKey}.pdf',
    );
    final partFile = File(
      '${cacheDirectory.path}${Platform.pathSeparator}${pdfFile.cacheKey}.part',
    );
    final metadataFile = File(
      '${cacheDirectory.path}${Platform.pathSeparator}${pdfFile.cacheKey}.json',
    );

    _log('cache-paths-ready', {
      'documentId': pdfFile.id,
      'cacheKey': pdfFile.cacheKey,
      'finalPath': finalFile.path,
      'partPath': partFile.path,
      'metadataPath': metadataFile.path,
    });

    final metadata = await _readMetadata(metadataFile);
    final sourceChanged =
        metadata != null &&
        metadata['downloadUrl'] is String &&
        metadata['downloadUrl'] != pdfFile.downloadUrl;

    if (sourceChanged) {
      _log('source-changed-clear-cache', {
        'documentId': pdfFile.id,
        'cacheKey': pdfFile.cacheKey,
        'oldDownloadUrl': metadata['downloadUrl'],
        'newDownloadUrl': pdfFile.downloadUrl,
      });
      await _safeDelete(finalFile);
      await _safeDelete(partFile);
      await _safeDelete(metadataFile);
    }

    if (await finalFile.exists()) {
      final cachedBytes = await finalFile.length();
      _log('cache-hit', {
        'documentId': pdfFile.id,
        'cacheKey': pdfFile.cacheKey,
        'bytes': cachedBytes,
        'path': finalFile.path,
      });
      return PdfCacheResult(filePath: finalFile.path, fromCache: true);
    }

    final resumedBytes = await partFile.exists() ? await partFile.length() : 0;
    _log('cache-miss', {
      'documentId': pdfFile.id,
      'cacheKey': pdfFile.cacheKey,
      'resumeFromBytes': resumedBytes,
      'metadataTotalBytes': metadata?['totalBytes'],
      'metadataEtag': metadata?['eTag'],
    });
    await _writeMetadata(
      metadataFile,
      _buildMetadata(
        pdfFile: pdfFile,
        cachedBytes: resumedBytes,
        totalBytes: metadata?['totalBytes'] as int?,
        eTag: metadata?['eTag'] as String?,
        completed: false,
      ),
    );

    return await _downloadToDisk(
      pdfFile: pdfFile,
      userPhone: userPhone,
      finalFile: finalFile,
      partFile: partFile,
      metadataFile: metadataFile,
      resumeFrom: resumedBytes,
      onProgress: onProgress,
      onPartialReady: onPartialReady,
    );
  }

  static Future<PdfCacheResult> _downloadToDisk({
    required PdfFile pdfFile,
    required String userPhone,
    required File finalFile,
    required File partFile,
    required File metadataFile,
    required int resumeFrom,
    void Function(int receivedBytes, int? totalBytes)? onProgress,
    void Function(String partialPath)? onPartialReady,
  }) async {
    final client = http.Client();
    IOSink? sink;

    try {
      final request = http.Request('GET', Uri.parse(pdfFile.downloadUrl));
      if (userPhone.trim().isNotEmpty) {
        request.headers['X-User-Phone'] = userPhone.trim();
      }
      if (resumeFrom > 0) {
        request.headers['Range'] = 'bytes=$resumeFrom-';
      }

      _log('http-request-start', {
        'documentId': pdfFile.id,
        'downloadUrl': pdfFile.downloadUrl,
        'resumeFromBytes': resumeFrom,
        'range': request.headers['Range'],
        'hasUserPhone': userPhone.trim().isNotEmpty,
      });

      final response = await client.send(request).timeout(_requestTimeout);

      _log('http-response-received', {
        'documentId': pdfFile.id,
        'statusCode': response.statusCode,
        'contentLength': response.headers['content-length'],
        'xFileSize': response.headers['x-file-size'],
        'contentRange': response.headers['content-range'],
        'acceptRanges': response.headers['accept-ranges'],
        'etag': response.headers['etag'],
      });

      if (response.statusCode >= 400) {
        final errorBody = await response.stream.bytesToString();
        _log('http-error-response', {
          'documentId': pdfFile.id,
          'statusCode': response.statusCode,
          'body': _shorten(errorBody),
        });
        throw PdfDownloadException(
          _extractErrorMessage(errorBody, response.statusCode),
          statusCode: response.statusCode,
        );
      }

      final isResuming = response.statusCode == 206 && resumeFrom > 0;
      final initialBytes = isResuming ? resumeFrom : 0;

      if (!isResuming && await partFile.exists()) {
        _log('discard-stale-partial', {
          'documentId': pdfFile.id,
          'path': partFile.path,
          'statusCode': response.statusCode,
          'resumeFromBytes': resumeFrom,
        });
        await partFile.delete();
      }

      sink = partFile.openWrite(
        mode: isResuming ? FileMode.append : FileMode.writeOnly,
      );

      final totalBytes = _resolveTotalBytes(
        response.headers,
        initialBytes: initialBytes,
      );

      var downloadedBytes = initialBytes;
      var nextProgressLogBytes =
          ((downloadedBytes ~/ _progressLogIntervalBytes) + 1) *
          _progressLogIntervalBytes;
      var partialReadyCalled = false;
      // A linearized PDF has two %%EOF markers:
      //   #1 (~few hundred bytes) – end of primary xref/trailer only, no page content
      //   #2 (~first-page end offset) – end of first-page section (valid standalone PDF)
      // We trigger onPartialReady on the SECOND %%EOF so the .part file is
      // a complete valid PDF for page 1 that Android's PdfRenderer can open.
      var eofCount = 0;
      // Keeps the last 4 bytes of the previous chunk to detect %%EOF split
      // across a chunk boundary (marker is 5 bytes; overlap is 4 bytes, so a
      // complete marker can never fit entirely in the overlap → no double-counting).
      var eofScanBuffer = <int>[];
      onProgress?.call(downloadedBytes, totalBytes);
      _log('download-start', {
        'documentId': pdfFile.id,
        'statusCode': response.statusCode,
        'resumed': isResuming,
        'initialBytes': initialBytes,
        'totalBytes': totalBytes,
        'partPath': partFile.path,
      });

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        onProgress?.call(downloadedBytes, totalBytes);

        if (downloadedBytes >= nextProgressLogBytes ||
            (totalBytes != null && downloadedBytes >= totalBytes)) {
          _log('download-progress', {
            'documentId': pdfFile.id,
            'receivedBytes': downloadedBytes,
            'totalBytes': totalBytes,
            'chunkBytes': chunk.length,
          });
          while (downloadedBytes >= nextProgressLogBytes) {
            nextProgressLogBytes += _progressLogIntervalBytes;
          }
        }

        if (!partialReadyCalled && onPartialReady != null) {
          final combined = [...eofScanBuffer, ...chunk];
          eofCount += _countPdfEofs(combined);
          // Keep last 4 bytes for next boundary check.
          eofScanBuffer = chunk.length >= 4
              ? chunk.sublist(chunk.length - 4).toList()
              : chunk.toList();

          if (eofCount >= 2) {
            // Second %%EOF = end of first-page section = valid partial PDF.
            partialReadyCalled = true;
            await sink.flush();
            _log('partial-eof-ready', {
              'documentId': pdfFile.id,
              'receivedBytes': downloadedBytes,
              'partPath': partFile.path,
            });
            onPartialReady(partFile.path);
          }
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (totalBytes != null && downloadedBytes < totalBytes) {
        _log('download-incomplete', {
          'documentId': pdfFile.id,
          'receivedBytes': downloadedBytes,
          'totalBytes': totalBytes,
        });
        throw PdfDownloadException('Download interrupted before completion.');
      }

      if (await finalFile.exists()) {
        _log('replace-existing-final', {
          'documentId': pdfFile.id,
          'path': finalFile.path,
        });
        await finalFile.delete();
      }

      await partFile.rename(finalFile.path);
      await _writeMetadata(
        metadataFile,
        _buildMetadata(
          pdfFile: pdfFile,
          cachedBytes: downloadedBytes,
          totalBytes: totalBytes,
          eTag: response.headers['etag'],
          completed: true,
        ),
      );

      _log('download-complete', {
        'documentId': pdfFile.id,
        'receivedBytes': downloadedBytes,
        'totalBytes': totalBytes,
        'finalPath': finalFile.path,
        'etag': response.headers['etag'],
      });

      return PdfCacheResult(filePath: finalFile.path, fromCache: false);
    } on TimeoutException catch (error) {
      _logError('download-timeout', error, {
        'documentId': pdfFile.id,
        'downloadUrl': pdfFile.downloadUrl,
        'timeoutSeconds': _requestTimeout.inSeconds,
      });
      throw const PdfDownloadException('Download timed out. Please try again.');
    } on SocketException catch (error) {
      _logError('download-socket-error', error, {
        'documentId': pdfFile.id,
        'downloadUrl': pdfFile.downloadUrl,
      });
      throw const PdfDownloadException(
        'Check your internet connection and try again.',
      );
    } on HttpException catch (error) {
      _logError('download-http-error', error, {
        'documentId': pdfFile.id,
        'downloadUrl': pdfFile.downloadUrl,
      });
      throw PdfDownloadException(error.message);
    } on PdfDownloadException catch (error) {
      _logError('download-failed', error, {
        'documentId': pdfFile.id,
        'downloadUrl': pdfFile.downloadUrl,
        'statusCode': error.statusCode,
      });
      rethrow;
    } catch (error) {
      _logError('download-unexpected-error', error, {
        'documentId': pdfFile.id,
        'downloadUrl': pdfFile.downloadUrl,
      });
      rethrow;
    } finally {
      await sink?.close();
      client.close();
    }
  }

  static Future<Directory> _getCacheDirectory() async {
    final baseDirectory = await getApplicationSupportDirectory();
    final cacheDirectory = Directory(
      '${baseDirectory.path}${Platform.pathSeparator}pdf_cache',
    );

    if (!await cacheDirectory.exists()) {
      await cacheDirectory.create(recursive: true);
    }

    return cacheDirectory;
  }

  static int? _resolveTotalBytes(
    Map<String, String> headers, {
    required int initialBytes,
  }) {
    final contentRange = headers['content-range'];
    if (contentRange != null && contentRange.contains('/')) {
      final totalSegment = contentRange.split('/').last.trim();
      final total = int.tryParse(totalSegment);
      if (total != null) {
        return total;
      }
    }

    final contentLength = int.tryParse(headers['content-length'] ?? '')
        ?? int.tryParse(headers['x-file-size'] ?? '');
    if (contentLength == null) {
      return null;
    }

    return initialBytes > 0 ? initialBytes + contentLength : contentLength;
  }

  static String _extractErrorMessage(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'] ?? decoded['error'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } catch (_) {
      // Fall through to generic messages.
    }

    if (statusCode == 401) {
      return 'Please login to open this premium PDF.';
    }

    if (statusCode == 403) {
      return 'An active subscription is required to open this premium PDF.';
    }

    if (statusCode == 404) {
      return 'This PDF is no longer available.';
    }

    return 'Unable to load this PDF right now.';
  }

  static Map<String, dynamic> _buildMetadata({
    required PdfFile pdfFile,
    required int cachedBytes,
    required bool completed,
    int? totalBytes,
    String? eTag,
  }) {
    return {
      'documentId': pdfFile.id,
      'downloadUrl': pdfFile.downloadUrl,
      'fileUrl': pdfFile.fileUrl,
      'cachedBytes': cachedBytes,
      'totalBytes': totalBytes,
      'eTag': eTag,
      'completed': completed,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  static Future<Map<String, dynamic>?> _readMetadata(File file) async {
    if (!await file.exists()) {
      return null;
    }

    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      _log('metadata-invalid-delete', {'path': file.path});
      await _safeDelete(file);
    }

    return null;
  }

  static Future<void> _writeMetadata(
    File file,
    Map<String, dynamic> metadata,
  ) async {
    await file.writeAsString(jsonEncode(metadata), flush: true);
  }

  static Future<void> _safeDelete(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<Uint8List> fetchPage({
    required PdfFile pdfFile,
    required String userPhone,
    required int pageNumber,
  }) async {
    final cacheDir = await _getCacheDirectory();
    final pageFile = File(
      '${cacheDir.path}${Platform.pathSeparator}${pdfFile.cacheKey}_p$pageNumber.pdf',
    );

    if (await pageFile.exists()) {
      return await pageFile.readAsBytes();
    }

    final fetchKey = '${pdfFile.cacheKey}_p$pageNumber';
    final inFlight = _activePageFetches[fetchKey];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _fetchPageInternal(
      pdfFile: pdfFile,
      userPhone: userPhone,
      pageNumber: pageNumber,
      pageFile: pageFile,
    );
    _activePageFetches[fetchKey] = future;
    try {
      return await future;
    } finally {
      _activePageFetches.remove(fetchKey);
    }
  }

  static Future<Uint8List> _fetchPageInternal({
    required PdfFile pdfFile,
    required String userPhone,
    required int pageNumber,
    required File pageFile,
  }) async {
    final pageUrl = pdfFile.buildPageUrl(pageNumber);
    _log('page-fetch-start', {
      'documentId': pdfFile.id,
      'pageNumber': pageNumber,
      'pageUrl': pageUrl,
    });

    final request = http.Request('GET', Uri.parse(pageUrl));
    if (userPhone.trim().isNotEmpty) {
      request.headers['X-User-Phone'] = userPhone.trim();
    }

    final response =
        await _pageHttpClient.send(request).timeout(_requestTimeout);
    if (response.statusCode >= 400) {
      final body = await response.stream.bytesToString();
      throw PdfDownloadException(
        _extractErrorMessage(body, response.statusCode),
        statusCode: response.statusCode,
      );
    }

    final bytes = Uint8List.fromList(await response.stream.toBytes());
    await pageFile.writeAsBytes(bytes, flush: true);

    _log('page-fetch-complete', {
      'documentId': pdfFile.id,
      'pageNumber': pageNumber,
      'bytes': bytes.length,
    });

    return bytes;
  }

  /// Counts all non-overlapping %%EOF occurrences in [bytes].
  /// Used to detect the second %%EOF in a linearized PDF stream,
  /// which marks the end of the first-page section (valid standalone PDF).
  static int _countPdfEofs(List<int> bytes) {
    int count = 0;
    final limit = bytes.length - _pdfEofMarker.length;
    for (var i = 0; i <= limit; i++) {
      if (bytes[i] == _pdfEofMarker[0] &&
          bytes[i + 1] == _pdfEofMarker[1] &&
          bytes[i + 2] == _pdfEofMarker[2] &&
          bytes[i + 3] == _pdfEofMarker[3] &&
          bytes[i + 4] == _pdfEofMarker[4]) {
        count++;
        i += 4; // skip past marker to avoid overlapping counts
      }
    }
    return count;
  }
}
