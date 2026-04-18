import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/theme.dart';
import '../utils/url_launcher.dart';

/// شاشة عرض مسبق لصفحة الوظيفة داخل التطبيق عبر WebView.
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, required this.url, required this.title});

  final String url;
  final String title;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _finished = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/122.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p),
          onPageFinished: (_) => setState(() => _finished = true),
          onWebResourceError: (err) {
            setState(() => _error = err.description);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _openExternal() async {
    await openExternalUrl(widget.url);
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ الرابط'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
          IconButton(
            tooltip: 'نسخ الرابط',
            icon: const Icon(Icons.link_outlined),
            onPressed: _copyLink,
          ),
          IconButton(
            tooltip: 'فتح في المتصفح',
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openExternal,
          ),
        ],
        bottom: _finished || _progress >= 100
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _progress / 100,
                  minHeight: 3,
                  color: AppTheme.primary,
                ),
              ),
      ),
      body: _error != null
          ? _ErrorView(message: _error!, onOpenBrowser: _openExternal)
          : WebViewWidget(controller: _controller),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onOpenBrowser});
  final String message;
  final VoidCallback onOpenBrowser;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 60, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            const Text(
              'تعذر عرض الصفحة داخل التطبيق',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'بعض المواقع تمنع العرض المضمّن. افتحها في المتصفح.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onOpenBrowser,
              icon: const Icon(Icons.open_in_new),
              label: const Text('فتح في المتصفح'),
            ),
          ],
        ),
      ),
    );
  }
}
