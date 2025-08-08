import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservation_app/pdf_view_screen.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

// --- ダミー WebView プラットフォームを作成 ---
class FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
      PlatformWebViewControllerCreationParams params) {
    return _FakePlatformWebViewController(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
      PlatformWebViewWidgetCreationParams params) {
    return _FakePlatformWebViewWidget(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
      PlatformNavigationDelegateCreationParams params) {
    return _FakePlatformNavigationDelegate(params);
  }
}

// --- Fake WebViewController 実装 ---
class _FakePlatformWebViewController extends PlatformWebViewController {
  _FakePlatformWebViewController(PlatformWebViewControllerCreationParams params)
      : super.implementation(params);

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
      PlatformNavigationDelegate handler) async {}
}

class _FakePlatformWebViewWidget extends PlatformWebViewWidget {
  _FakePlatformWebViewWidget(PlatformWebViewWidgetCreationParams params)
      : super.implementation(params);

  @override
  Widget build(BuildContext context) {
    return const Placeholder(); // WebViewWidgetの代替表示
  }
}

// --- Fake NavigationDelegate 実装 ---
class _FakePlatformNavigationDelegate extends PlatformNavigationDelegate {
  _FakePlatformNavigationDelegate(
      PlatformNavigationDelegateCreationParams params)
      : super.implementation(params);

  @override
  Future<void> setOnPageStarted(
      void Function(String url)? onPageStarted) async {
    // do nothing
  }

  @override
  Future<void> setOnPageFinished(
      void Function(String url)? onPageFinished) async {
    // do nothing
  }

  @override
  Future<void> setOnWebResourceError(
      void Function(WebResourceError error)? onWebResourceError) async {
    // do nothing
  }
}

void main() {
  group('PdfViewerScreen tests', () {
    setUp(() {
      WebViewPlatform.instance = FakeWebViewPlatform();
    });

    testWidgets('PDFビュー画面の初期表示が正しく構築される', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PdfViewerScreen(url: 'https://example.com/sample.pdf'),
        ),
      );

      // タイトルが表示されているか
      expect(find.text('PDF表示'), findsOneWidget);

      // ローディングインジケーターが表示されているか
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // エラーメッセージが表示されていないか
      expect(find.textContaining('PDFの読み込みに失敗しました'), findsNothing);
    });
  });
}
