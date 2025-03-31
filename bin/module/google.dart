import 'package:dio/dio.dart';
import 'package:puppeteer/puppeteer.dart';

class Google {
  static final Google _instance = Google._internal();
  late final Page page;
  final Dio dio = Dio();
  bool isReady = false;

  factory Google() {
    return _instance;
  }

  Google._internal() {
    (() async {
      page = await puppeteer
          .launch(headless: true)
          .then((browser) => browser.newPage());
      await page.setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      );
      isReady = true;
    })();
  }

  Future<String> searchLyrics(String artist, String title) async {
    final response = await dio.get(
      'https://private-anon-488effc76d-lyricsovh.apiary-proxy.com/v1/$artist/$title',
    );
    if (response.statusCode != 200) return '가사 없음';
    return response.data['lyrics'] ?? '가사 없음';
  }

  Future<String> searchImage(String query, int index) async {
    if (!isReady) throw "browser is not ready";
    await page.goto('https://www.google.com/search?tbm=isch&q=$query');
    final base64image = await page.evaluate<String?>(
      '''(n) => {
    const images = [...document.querySelectorAll('img')];
    const removeCount = n % images.length;
    images.splice(0, removeCount);
    for (const img of images) {
      if (img.src.startsWith('data:image/')) {
        return img.src;
      }
    }
    return null;
  }''',
      args: [index],
    );
    return base64image ?? '';
  }
}
