part of '../main.dart';

Future<Uint8List> readLimitedResponse(
  HttpClientResponse response, {
  required int maxBytes,
  Duration timeout = const Duration(seconds: 8),
}) async {
  if (response.contentLength > maxBytes) {
    throw const HttpException('Response exceeds the size limit');
  }
  // A deadline for the whole body also catches servers that drip-feed data.
  final builder = await response
      .fold<BytesBuilder>(BytesBuilder(copy: false), (builder, chunk) {
        if (builder.length + chunk.length > maxBytes) {
          throw const HttpException('Response exceeds the size limit');
        }
        return builder..add(chunk);
      })
      .timeout(timeout);
  return builder.takeBytes();
}
