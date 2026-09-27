import 'package:web/web.dart' as web;

void showSongInAddressBar(String id, String title) {
  final params = {...Uri.base.queryParameters, 'song': id};
  web.window.history.replaceState(
    null,
    '',
    Uri.base.replace(queryParameters: params).toString(),
  );
  web.document.title = '$title — Indirimbo Zikundwa';
}

void clearSongFromAddressBar(String id) {
  if (Uri.base.queryParameters['song'] != id) return;
  final params = {...Uri.base.queryParameters}..remove('song');
  final url = params.isEmpty
      ? Uri.base.path
      : Uri.base.replace(queryParameters: params).toString();
  web.window.history.replaceState(null, '', url);
  web.document.title = 'Indirimbo Zikundwa';
}
