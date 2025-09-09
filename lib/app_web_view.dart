import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:url_launcher/url_launcher.dart';

class AppWebView extends StatefulWidget {
  final String initialUrl;
  final Map<String, String>? headers;
  const AppWebView({super.key, required this.initialUrl, this.headers});

  @override
  State<AppWebView> createState() => _AppWebViewState();
}

class _AppWebViewState extends State<AppWebView> {
  late final InAppWebViewController? _c;

  @override
  void initState() {
    super.initState();
  }

  Future<void> setBrightness(double value) async {
    try {
      await ScreenBrightness().setScreenBrightness(value);
    } catch (e) {
      log('調整亮度失敗: $e');
    }
  }

  Future<void> resetBrightness() async {
    try {
      await ScreenBrightness().resetScreenBrightness();
    } catch (e) {
      log('恢復亮度失敗: $e');
    }
  }

  Future<void> _handleMethod(String method, List args) async {
    log('Method:$method', name: 'Handle_Method');
    switch (method) {
      case 'AppScreenLight':
        final enable = (args.isNotEmpty ? args[0] : false) == true;
        await setBrightness(enable ? 1.0 : -1.0);
        await Future.delayed(Duration(seconds: 3));
        await resetBrightness();
        break;

      case 'AppCloseWebview':
        if (mounted) Navigator.of(context).maybePop();
        break;

      case 'AppOpenWeb':
        final bool inApp = (args.isNotEmpty && args[0] == true);
        final String url = (args.length >= 2 ? args[1] as String : '');
        if (url.isEmpty) return;

        if (inApp) {
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AppWebView(initialUrl: url)),
          );
        } else {
          final uri = Uri.parse(url);
          if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
            // fallback：改用 in-app
            if (!mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AppWebView(initialUrl: url)),
            );
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Portal')),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(widget.initialUrl),
          headers: widget.headers,
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          cacheEnabled: true,
        ),

        onLoadStart: (controller, url) {
          log("開始載入: $url");
        },
        onWebViewCreated: (c) async {
          _c = c;

          // 1) Dart收訊息的地方：handlerName = 'InbrJsInterface'
          _c?.addJavaScriptHandler(
            handlerName: 'InbrJsInterface',
            callback: (args) async {
              // JS 端 callHandler('InbrJsInterface', { method:'X', args:[...] })
              final payload = (args.isNotEmpty ? args.first : {}) as Map? ?? {};
              final method = payload['method']?.toString() ?? '';
              final List<dynamic> a = (payload['args'] as List?) ?? const [];

              log(
                'On message received: $method, args=$a',
                name: 'InbrJsInterface',
              );

              try {
                await _handleMethod(method, a);
                return {'ok': true};
              } catch (e, st) {
                log('error: $e\n$st', name: 'InbrJsInterface');
                return {'ok': false, 'error': e.toString()};
              }
            },
          );

          // 2) 先注入一次（建立時）
          await _c?.evaluateJavascript(source: _polyfillFixed);
        },

        onLoadStop: (controller, url) async {
          log("載入完成: $url");
          // 3) 重新注入一次（每次導航後環境都可能重置）
          await controller.evaluateJavascript(source: _polyfillFixed);

          // （可選）這裡也能做一個自測 ping
          await controller.evaluateJavascript(
            source:
                "window.InbrJsInterface && InbrJsInterface.__ping && InbrJsInterface.__ping();",
          );
        },
        onReceivedError: (controller, request, error) {
          log('RECEIVED_ERROR');
          log(request.headers.toString());
          log(error.description);
        },
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          final uri = navigationAction.request.url;
          if (uri != null && uri.toString().contains("success")) {
            // 例如登入成功跳轉的網址
            debugPrint("偵測到登入成功: $uri");
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text("登入成功！")));
          }
          return NavigationActionPolicy.ALLOW;
        },
      ),
    );
  }
}

const _polyfillFixed = r'''
              (function(){
                if (!window.InbrJsInterface) window.InbrJsInterface = {};

                async function send(method, argsArray){
                  try{
                    return await window.flutter_inappwebview.callHandler(
                      'InbrJsInterface',
                      { method: String(method||''), args: Array.isArray(argsArray)? argsArray : [] }
                    );
                  }catch(e){
                    console.error('[InbrJsInterface] call failed:', e);
                    throw e;
                  }
                }

                // 對齊你原生的介面：InbrJsInterface.AppScreenLight(on)
                if (typeof window.InbrJsInterface.AppScreenLight !== 'function') {
                  window.InbrJsInterface.AppScreenLight = function(on){
                    return send('AppScreenLight', [!!on]);
                  };
                }

                // InbrJsInterface.AppCloseWebview()
                if (typeof window.InbrJsInterface.AppCloseWebview !== 'function') {
                  window.InbrJsInterface.AppCloseWebview = function(){
                    return send('AppCloseWebview', []);
                  };
                }

                // InbrJsInterface.AppOpenWeb(inapp, url)
                if (typeof window.InbrJsInterface.AppOpenWeb !== 'function') {
                  window.InbrJsInterface.AppOpenWeb = function(inapp, url){
                    return send('AppOpenWeb', [!!inapp, String(url||'')]);
                  };
                }

                // 能見度 / 自測
                window.InbrJsInterface.transport = 'callHandler';
                window.InbrJsInterface.version = '1.0.1';
                window.InbrJsInterface.capabilities = ['AppScreenLight','AppCloseWebview','AppOpenWeb'];
                window.InbrJsInterface.__ping = function(){
                  console.log('[InbrJsInterface] ready via callHandler');
                };
              })();
              ''';
