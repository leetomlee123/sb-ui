import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class ProxyDioHelper {
  /// Configures a [Dio] instance to route HTTP/HTTPS requests through the local
  /// sing-box mixed proxy port when the core is running, with automatic fallback
  /// to DIRECT connection if the proxy port is unreachable.
  static void configureProxy(Dio dio, {int? proxyPort}) {
    final adapter = dio.httpClientAdapter;
    if (adapter is IOHttpClientAdapter) {
      adapter.createHttpClient = () {
        final client = HttpClient();
        if (proxyPort != null && proxyPort > 0) {
          client.findProxy = (uri) => 'PROXY 127.0.0.1:$proxyPort; DIRECT';
        } else {
          client.findProxy = (uri) => 'DIRECT';
        }
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      };
    }
  }
}
