// dart:io implementation of the share transport (mobile / desktop).
//
// Host  = an HttpServer upgraded to WebSocket + a Bonjour/mDNS advertisement.
// Client = a WebSocket connection.
// Discovery = a Bonjour/mDNS browser for the well-known service type.
//
// Bonjour (rather than raw UDP broadcast) is used so discovery works on iOS,
// where broadcast/multicast is blocked without a special Apple entitlement but
// Bonjour is allowed via the NSBonjourServices / NSLocalNetworkUsageDescription
// Info.plist keys.

import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';

import 'transport.dart';
import 'ws_client.dart';

bool get canHostSessions => true;
bool get canJoinSessions => true;

Future<ShareHost> startHost(
    {required String name, required SharedView initial, SharedSong? initialSong}) async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 0, shared: true);
  final addresses = await _localIpv4s();
  return _IoHost(server, name, initial, initialSong, addresses);
}

Future<ShareClient> connectClient(DiscoveredSession session) => openWsClient(session);

ShareDiscovery startDiscovery() => _IoDiscovery();

/// The device's non-loopback IPv4 addresses (for building join URLs).
Future<List<String>> _localIpv4s() async {
  try {
    final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false);
    return [for (final i in ifaces) for (final a in i.addresses) a.address];
  } catch (_) {
    return const [];
  }
}

class _IoHost implements ShareHost {
  final HttpServer _server;
  final String name;
  SharedView _current;
  SharedSong? _song;
  final List<String> _addresses;

  final _clients = <WebSocket>{};
  final _countCtrl = StreamController<int>.broadcast();
  BonsoirBroadcast? _broadcast;

  _IoHost(this._server, this.name, this._current, this._song, this._addresses) {
    _server.listen(_onRequest);
    _advertise();
  }

  @override
  int get wsPort => _server.port;

  // A plain http URL: opening it in a browser loads the follow-along page; the
  // native app's "join by address" field accepts it too (it maps http→ws).
  @override
  List<String> get joinUrls => [for (final a in _addresses) 'http://$a:${_server.port}'];

  @override
  Stream<int> get clientCount => _countCtrl.stream;

  Future<void> _onRequest(HttpRequest req) async {
    // A normal browser navigation (GET, not a WebSocket handshake): serve the
    // self-contained follow-along page so a shared http link "just works".
    if (!WebSocketTransformer.isUpgradeRequest(req)) {
      if (req.method == 'GET' && req.uri.path == '/') {
        req.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..headers.set('Cache-Control', 'no-store');
        req.response.write(_followerPageHtml(name));
        await req.response.close();
      } else {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
      return;
    }
    final ws = await WebSocketTransformer.upgrade(req);
    _clients.add(ws);
    _emitCount();
    ws.add(ShareMessage.hello(name, _current, song: _song).encode());
    void drop() {
      if (_clients.remove(ws)) _emitCount();
    }

    ws.listen((_) {}, onDone: drop, onError: (_) => drop(), cancelOnError: true);
  }

  void _emitCount() {
    if (!_countCtrl.isClosed) _countCtrl.add(_clients.length);
  }

  @override
  void update(SharedView view, {SharedSong? song}) {
    _current = view;
    if (song != null) _song = song;
    final msg = ShareMessage.viewUpdate(view, song: song).encode();
    for (final c in _clients) {
      try {
        c.add(msg);
      } catch (_) {/* client mid-disconnect */}
    }
  }

  // Advertise the session over Bonjour/mDNS so other devices on the same Wi-Fi
  // discover it automatically (the "session nearby" banner). The display name is
  // carried both as the service instance name and a TXT attribute for safety.
  Future<void> _advertise() async {
    try {
      final b = BonsoirBroadcast(
        service: BonsoirService(
          name: name,
          type: kBonjourServiceType,
          port: wsPort,
          attributes: {'name': name},
        ),
      );
      _broadcast = b; // assign before await so close() can stop a pending start
      await b.initialize();
      await b.start();
    } catch (_) {/* advertising unavailable; manual connect still works */}
  }

  @override
  Future<void> close() async {
    try {
      await _broadcast?.stop();
    } catch (_) {/* never started / already stopped */}
    for (final c in _clients) {
      try {
        c.add(ShareMessage.bye().encode());
        await c.close();
      } catch (_) {}
    }
    _clients.clear();
    if (!_countCtrl.isClosed) await _countCtrl.close();
    await _server.close(force: true);
  }
}

/// Minimal HTML escape for text interpolated into the page markup.
String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

/// A self-contained follow-along page served at `http://host:port/`. It opens a
/// WebSocket back to the same origin (so there is no mixed-content problem) and
/// live-mirrors the song the host is sharing — title, credit and lyrics — for
/// anyone on the same network, no app install required.
String _followerPageHtml(String sessionName) {
  final name = _esc(sessionName);
  return '''<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>$name · Indirimbo</title>
<style>
  :root{
    --paper:#F4EEE1; --ink:#2B2722; --accent:#B0512F; --muted:#9C8C76;
    --hairline:#DED3BF; --chorus:#FBF6EC;
  }
  *{box-sizing:border-box}
  html,body{margin:0;background:var(--paper);color:var(--ink);
    font-family:Georgia,'Iowan Old Style','Times New Roman',serif;
    -webkit-text-size-adjust:100%}
  header{position:sticky;top:0;z-index:2;
    background:linear-gradient(135deg,#A6492B,#7E3320);color:#fff;
    padding:calc(env(safe-area-inset-top) + 12px) 18px 12px;
    display:flex;align-items:center;gap:10px;
    box-shadow:0 2px 10px rgba(0,0,0,.12)}
  .badge{display:inline-flex;align-items:center;gap:6px;
    background:rgba(255,255,255,.18);border-radius:20px;
    padding:4px 10px;font:700 10px/1 system-ui,sans-serif;letter-spacing:1.4px}
  .dot{width:7px;height:7px;border-radius:50%;background:#FF5A4D}
  .badge.off .dot{background:rgba(255,255,255,.5)}
  .badge.off{background:rgba(0,0,0,.18)}
  header .name{font:700 16px/1.2 Georgia,serif;flex:1;
    white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
  main{max-width:680px;margin:0 auto;padding:26px 22px 80px}
  .meta{color:var(--accent);font:700 12px/1.2 system-ui,sans-serif;
    letter-spacing:.8px;text-transform:uppercase}
  h1{font-size:clamp(26px,7vw,40px);line-height:1.15;margin:8px 0 6px;font-weight:700}
  .author{color:var(--muted);font-style:italic;font-size:14px;margin:0 0 18px}
  .rule{display:flex;align-items:center;gap:0;margin:18px 0 26px}
  .rule i{height:2px;width:36px;background:var(--accent)}
  .rule b{height:1px;flex:1;background:var(--hairline)}
  .stanza{margin:0 0 22px;white-space:pre-wrap;font-size:19px;line-height:1.6}
  .stanza .n{display:block;color:var(--muted);
    font:700 11px/1 system-ui,sans-serif;letter-spacing:1px;margin-bottom:6px}
  .stanza.chorus{background:var(--chorus);border-left:3px solid var(--accent);
    border-radius:8px;padding:14px 16px;font-style:italic}
  .waiting{text-align:center;color:var(--muted);margin-top:18vh;font-size:16px}
  .spin{width:24px;height:24px;margin:0 auto 14px;border-radius:50%;
    border:2.5px solid var(--hairline);border-top-color:var(--accent);
    animation:spin 1s linear infinite}
  @keyframes spin{to{transform:rotate(360deg)}}
  footer{position:fixed;left:0;right:0;bottom:0;text-align:center;
    padding:8px 0 calc(env(safe-area-inset-bottom) + 8px);
    font:600 11px/1 system-ui,sans-serif;color:var(--muted);
    background:linear-gradient(to top,var(--paper),rgba(244,238,225,0))}
  #follow{position:fixed;left:50%;transform:translateX(-50%);
    bottom:calc(env(safe-area-inset-bottom) + 26px);z-index:4;display:none;
    align-items:center;gap:8px;background:var(--accent);color:#fff;border:none;
    border-radius:30px;padding:12px 20px;cursor:pointer;
    font:700 14px/1 system-ui,sans-serif;
    box-shadow:0 5px 18px rgba(0,0,0,.28)}
  #follow.show{display:inline-flex}
  #follow:active{transform:translateX(-50%) scale(.97)}
  #follow svg{width:16px;height:16px;fill:none;stroke:#fff;stroke-width:2.2}
</style>
</head>
<body>
<header>
  <span class="badge" id="badge"><span class="dot"></span><span id="state">EN DIRECT</span></span>
  <span class="name" id="sname">$name</span>
</header>
<main id="main">
  <div class="waiting" id="waiting"><div class="spin"></div>En attente du partage…</div>
  <article id="song" style="display:none">
    <div class="meta" id="meta"></div>
    <h1 id="title"></h1>
    <p class="author" id="author" style="display:none"></p>
    <div class="rule"><i></i><b></b></div>
    <div id="stanzas"></div>
  </article>
</main>
<footer>Indirimbo · Partage en direct</footer>
<button id="follow" aria-label="Suivre le partage">
  <svg viewBox="0 0 24 24"><polyline points="23 4 23 10 17 10"></polyline>
    <path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"></path></svg>
  <span>Suivre le partage</span>
</button>
<script>
(function(){
  var badge=document.getElementById('badge'),state=document.getElementById('state'),
      sname=document.getElementById('sname'),waiting=document.getElementById('waiting'),
      songEl=document.getElementById('song'),meta=document.getElementById('meta'),
      title=document.getElementById('title'),author=document.getElementById('author'),
      stanzas=document.getElementById('stanzas'),followBtn=document.getElementById('follow');
  var curId=null, ws=null, retry=null;
  // Mirror the host's scroll only while "following". The viewer can scroll on
  // their own — that pauses following until they tap the button (or the song
  // changes, which always re-syncs).
  var following=true, lastScroll=0, programmatic=false, progTimer=null;
  function online(on){
    badge.className = on ? 'badge' : 'badge off';
    state.textContent = on ? 'EN DIRECT' : 'Reconnexion…';
  }
  function setFollowing(on){
    following=on;
    followBtn.className = on ? '' : 'show';
  }
  function render(song){
    waiting.style.display='none'; songEl.style.display='block';
    document.title=(song.title||'Indirimbo')+' · Indirimbo';
    meta.textContent=(song.collection||'')+(song.label?(' · N° '+song.label):'');
    title.textContent=song.title||'';
    if(song.author){author.style.display='block';author.textContent=song.author;}
    else author.style.display='none';
    stanzas.innerHTML='';
    var n=0;
    (song.stanzas||[]).forEach(function(s){
      var d=document.createElement('div');
      d.className='stanza'+(s.c?' chorus':'');
      if(!s.c){n++;var lab=document.createElement('span');lab.className='n';
        lab.textContent=n;d.appendChild(lab);}
      else{var lab2=document.createElement('span');lab2.className='n';
        lab2.textContent='REFRAIN';d.appendChild(lab2);}
      d.appendChild(document.createTextNode(s.t||''));
      stanzas.appendChild(d);
    });
  }
  function applyScroll(frac){
    if(typeof frac!=='number')return;
    var h=document.documentElement.scrollHeight-window.innerHeight;
    if(h<=0)return;
    // Flag our own scroll so the input listeners don't treat it as the viewer
    // taking over.
    programmatic=true;
    clearTimeout(progTimer);
    progTimer=setTimeout(function(){programmatic=false;},700);
    window.scrollTo({top:frac*h,behavior:'smooth'});
  }
  function pause(){ if(following && !programmatic) setFollowing(false); }
  function resume(){ setFollowing(true); applyScroll(lastScroll); }
  // Treat real input gestures as the viewer scrolling on their own.
  window.addEventListener('wheel', pause, {passive:true});
  window.addEventListener('touchmove', pause, {passive:true});
  window.addEventListener('keydown', function(e){
    if([' ','PageUp','PageDown','ArrowUp','ArrowDown','Home','End'].indexOf(e.key)>=0) pause();
  });
  followBtn.addEventListener('click', resume);
  function onMsg(d){
    var m; try{m=JSON.parse(d);}catch(e){return;}
    if(m.name) sname.textContent=m.name;
    if(m.song && m.song.id!==curId){
      curId=m.song.id; render(m.song);
      setFollowing(true); lastScroll=0;
      window.scrollTo(0,0); // new song: always re-sync to the top
    }
    if(m.view && typeof m.view.scroll==='number'){
      lastScroll=m.view.scroll;
      if(following) applyScroll(lastScroll);
    }
    if(m.t==='bye'){ online(false); }
  }
  function connect(){
    try{ ws=new WebSocket((location.protocol==='https:'?'wss://':'ws://')+location.host+'/'); }
    catch(e){ schedule(); return; }
    ws.onopen=function(){ online(true); };
    ws.onmessage=function(e){ onMsg(e.data); };
    ws.onclose=function(){ online(false); schedule(); };
    ws.onerror=function(){ try{ws.close();}catch(e){} };
  }
  function schedule(){ if(retry)return; retry=setTimeout(function(){retry=null;connect();},2000); }
  connect();
})();
</script>
</body>
</html>''';
}

class _IoDiscovery implements ShareDiscovery {
  final _ctrl = StreamController<List<DiscoveredSession>>.broadcast();
  // Keyed by the Bonjour service instance name so "lost" events can drop the
  // matching entry (a "found"/"lost" event has the name but not yet the host).
  final _byName = <String, DiscoveredSession>{};
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _sub;

  _IoDiscovery() {
    _start();
  }

  Future<void> _start() async {
    try {
      final d = BonsoirDiscovery(type: kBonjourServiceType);
      _discovery = d;
      await d.initialize();
      _sub = d.eventStream?.listen(_onEvent);
      await d.start();
    } catch (_) {/* discovery unavailable */}
  }

  void _onEvent(BonsoirDiscoveryEvent event) {
    switch (event) {
      // A service appeared: ask the platform to resolve its address + port.
      case BonsoirDiscoveryServiceFoundEvent():
        _discovery?.serviceResolver.resolveService(event.service);
      // Resolution finished: we now have an address we can connect to.
      case BonsoirDiscoveryServiceResolvedEvent():
        final service = event.service;
        final host = _pickHost(service);
        if (host == null) return;
        _byName[service.name] = DiscoveredSession(
          name: service.attributes['name'] ?? service.name,
          host: host,
          wsPort: service.port,
        );
        _emit();
      // The host went away.
      case BonsoirDiscoveryServiceLostEvent():
        if (_byName.remove(event.service.name) != null) _emit();
      default:
        break;
    }
  }

  // Prefer an IPv4 address (simplest for ws:// URLs); fall back to any address
  // or the mDNS hostname.
  String? _pickHost(BonsoirService s) {
    for (final a in s.hostAddresses) {
      if (a.contains('.') && !a.contains(':')) return a;
    }
    return s.hostAddress ?? s.hostname;
  }

  void _emit() {
    if (!_ctrl.isClosed) _ctrl.add(_byName.values.toList());
  }

  @override
  Stream<List<DiscoveredSession>> get sessions => _ctrl.stream;

  @override
  Future<void> close() async {
    await _sub?.cancel();
    try {
      await _discovery?.stop();
    } catch (_) {}
    if (!_ctrl.isClosed) await _ctrl.close();
  }
}
