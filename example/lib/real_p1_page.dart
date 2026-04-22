import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nrf_mesh_flutter/nrf_mesh_flutter.dart';

class RealP1Page extends StatefulWidget {
  const RealP1Page({super.key});

  @override
  State<RealP1Page> createState() => _RealP1PageState();
}

class _RealP1PageState extends State<RealP1Page> {
  final _mesh = PlatoJobsNrfMeshManager.instance;

  StreamSubscription<UnprovisionedDevice>? _scanSub;
  StreamSubscription<MeshMessage>? _msgSub;
  final List<UnprovisionedDevice> _proxies = [];
  bool _scanning = false;
  bool _connecting = false;

  final _importPathCtrl = TextEditingController();
  final _proxyUnicastCtrl = TextEditingController(text: '0x0001');

  // Target + operation params.
  final _elementAddressCtrl = TextEditingController(text: '0x0001');
  final _modelIdCtrl = TextEditingController(text: '0x1000');
  final _appKeyIndexCtrl = TextEditingController(text: '0');
  final _subAddressCtrl = TextEditingController(text: '0xC000');
  final _pubAddressCtrl = TextEditingController(text: '0xC000');
  final _ttlCtrl = TextEditingController(text: '5');

  // Access (P2)
  final _accessDstCtrl = TextEditingController(text: '0xC000');
  final _accessAppKeyIndexCtrl = TextEditingController(text: '0');
  final _levelCtrl = TextEditingController(text: '0');

  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _msgSub = _mesh.messageStream.listen(
      (m) => _log(
        'RX ${m.runtimeType} opcode=${m.opcode} addr=${m.address} appKeyIndex=${m.appKeyIndex} params=${m.parameters}',
      ),
      onError: (e) => _log('messageStream error: $e'),
    );
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _msgSub?.cancel();
    _importPathCtrl.dispose();
    _proxyUnicastCtrl.dispose();
    _elementAddressCtrl.dispose();
    _modelIdCtrl.dispose();
    _appKeyIndexCtrl.dispose();
    _subAddressCtrl.dispose();
    _pubAddressCtrl.dispose();
    _ttlCtrl.dispose();
    _accessDstCtrl.dispose();
    _accessAppKeyIndexCtrl.dispose();
    _levelCtrl.dispose();
    super.dispose();
  }

  void _log(String msg) {
    setState(() {
      _logs.insert(0, '[${DateTime.now().toIso8601String()}] $msg');
    });
  }

  int _parseInt(String s) {
    final t = s.trim().toLowerCase();
    if (t.startsWith('0x')) {
      return int.parse(t.substring(2), radix: 16);
    }
    return int.parse(t);
  }

  Future<void> _startScan() async {
    _log('Start scan (Proxy service / discovered devices).');
    await _scanSub?.cancel();
    _proxies.clear();
    setState(() => _scanning = true);

    _scanSub = _mesh.scanForDevices().listen(
      (d) {
        if (_proxies.any((e) => e.deviceId == d.deviceId)) return;
        setState(() => _proxies.add(d));
      },
      onError: (e) => _log('Scan stream error: $e'),
    );
  }

  Future<void> _stopScan() async {
    _log('Stop scan.');
    await _mesh.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    setState(() => _scanning = false);
  }

  Future<void> _importMeshDb() async {
    final path = _importPathCtrl.text.trim();
    if (path.isEmpty) {
      _log('Import path is empty.');
      return;
    }
    try {
      _log('Import network from path: $path');
      final ok = await _mesh.importNetwork(path);
      _log('Import result: $ok');
    } catch (e) {
      _log('Import error: $e');
    }
  }

  Future<void> _connectProxy(UnprovisionedDevice d) async {
    if (_connecting) return;
    setState(() => _connecting = true);
    try {
      final unicast = _parseInt(_proxyUnicastCtrl.text);
      _log('Connect proxy deviceId=${d.deviceId} proxyUnicast=0x${unicast.toRadixString(16)}');
      final ok = await _mesh.connectProxy(d.deviceId, unicast);
      final connected = await _mesh.isProxyConnected();
      _log('connectProxy result=$ok isProxyConnected=$connected');
    } catch (e) {
      _log('Connect error: $e');
    } finally {
      setState(() => _connecting = false);
    }
  }

  Future<void> _disconnectProxy() async {
    try {
      _log('Disconnect proxy.');
      final ok = await _mesh.disconnectProxy();
      final connected = await _mesh.isProxyConnected();
      _log('disconnectProxy result=$ok isProxyConnected=$connected');
    } catch (e) {
      _log('Disconnect error: $e');
    }
  }

  Future<void> _bind() async {
    try {
      final el = _parseInt(_elementAddressCtrl.text);
      final mid = _parseInt(_modelIdCtrl.text);
      final app = _parseInt(_appKeyIndexCtrl.text);
      _log('Bind AppKey: element=0x${el.toRadixString(16)} model=0x${mid.toRadixString(16)} appKeyIndex=$app');
      final ok = await _mesh.bindAppKey(el, mid, app);
      _log('bindAppKey result=$ok');
    } catch (e) {
      _log('bindAppKey error: $e');
    }
  }

  Future<void> _subAdd() async {
    try {
      final el = _parseInt(_elementAddressCtrl.text);
      final mid = _parseInt(_modelIdCtrl.text);
      final addr = _parseInt(_subAddressCtrl.text);
      _log('Add subscription: element=0x${el.toRadixString(16)} model=0x${mid.toRadixString(16)} addr=0x${addr.toRadixString(16)}');
      final ok = await _mesh.addSubscription(el, mid, addr);
      _log('addSubscription result=$ok');
    } catch (e) {
      _log('addSubscription error: $e');
    }
  }

  Future<void> _pubSet() async {
    try {
      final el = _parseInt(_elementAddressCtrl.text);
      final mid = _parseInt(_modelIdCtrl.text);
      final addr = _parseInt(_pubAddressCtrl.text);
      final app = _parseInt(_appKeyIndexCtrl.text);
      final ttl = int.tryParse(_ttlCtrl.text.trim());
      _log('Set publication: element=0x${el.toRadixString(16)} model=0x${mid.toRadixString(16)} pub=0x${addr.toRadixString(16)} appKeyIndex=$app ttl=$ttl');
      final ok = await _mesh.setPublication(el, mid, addr, app, ttl: ttl);
      _log('setPublication result=$ok');
    } catch (e) {
      _log('setPublication error: $e');
    }
  }

  Future<void> _sendOnOff(bool state) async {
    try {
      final dst = _parseInt(_accessDstCtrl.text);
      final app = _parseInt(_accessAppKeyIndexCtrl.text);
      _log('Send GenericOnOffSet state=$state dst=0x${dst.toRadixString(16)} appKeyIndex=$app');
      await _mesh.sendMessage(GenericOnOffSet(state: state, address: dst, appKeyIndex: app));
      _log('sendMessage(GenericOnOffSet) OK');
    } catch (e) {
      _log('sendMessage(GenericOnOffSet) error: $e');
    }
  }

  Future<void> _sendLevel() async {
    try {
      final dst = _parseInt(_accessDstCtrl.text);
      final app = _parseInt(_accessAppKeyIndexCtrl.text);
      final level = int.parse(_levelCtrl.text.trim());
      _log('Send GenericLevelSet level=$level dst=0x${dst.toRadixString(16)} appKeyIndex=$app');
      await _mesh.sendMessage(GenericLevelSet(level: level, address: dst, appKeyIndex: app));
      _log('sendMessage(GenericLevelSet) OK');
    } catch (e) {
      _log('sendMessage(GenericLevelSet) error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('P1 Real Proxy + Config'),
        actions: [
          IconButton(
            onPressed: _disconnectProxy,
            tooltip: 'Disconnect Proxy',
            icon: const Icon(Icons.link_off),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Step 0: Import Mesh DB (optional but recommended)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _importPathCtrl,
            decoration: const InputDecoration(
              labelText: 'Mesh DB path (Mesh Configuration DB Profile 1.0.1 JSON)',
              hintText: '/path/to/mesh.json',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: _importMeshDb,
                child: const Text('Import Network'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () async {
                  try {
                    _log('Load network (native storage).');
                    await _mesh.loadNetwork();
                    _log('Load network done.');
                  } catch (e) {
                    _log('Load network error: $e');
                  }
                },
                child: const Text('Load Network'),
              ),
            ],
          ),
          const Divider(height: 32),
          const Text(
            'Step 1: Scan and connect to a Proxy node',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _proxyUnicastCtrl,
            decoration: const InputDecoration(
              labelText: 'Proxy node primary unicast (hint for Android; iOS may ignore)',
              hintText: '0x0001',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: _scanning ? _stopScan : _startScan,
                child: Text(_scanning ? 'Stop Scan' : 'Start Scan'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () async {
                  try {
                    final connected = await _mesh.isProxyConnected();
                    _log('isProxyConnected=$connected');
                  } catch (e) {
                    _log('isProxyConnected error: $e');
                  }
                },
                child: const Text('Check Connected'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._proxies.map(
            (d) => ListTile(
              dense: true,
              title: Text(d.name),
              subtitle: Text('deviceId=${d.deviceId} rssi=${d.rssi}'),
              trailing: ElevatedButton(
                onPressed: _connecting ? null : () => _connectProxy(d),
                child: _connecting ? const Text('...') : const Text('Connect'),
              ),
            ),
          ),
          const Divider(height: 32),
          const Text(
            'Step 2: Real Config (bind / sub / pub)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _elementAddressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Element unicast address',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _modelIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'SIG modelId (e.g. 0x1000)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _appKeyIndexCtrl,
                  decoration: const InputDecoration(
                    labelText: 'AppKeyIndex (decimal)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _subAddressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Subscription address',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pubAddressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Publication address',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _ttlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'TTL (decimal)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton(onPressed: _bind, child: const Text('Bind AppKey')),
              ElevatedButton(onPressed: _subAdd, child: const Text('Add Sub')),
              ElevatedButton(onPressed: _pubSet, child: const Text('Set Pub')),
              OutlinedButton(
                onPressed: () async {
                  try {
                    _log('Reload nodes/groups for inspection.');
                    await _mesh.getNodes();
                    await _mesh.getGroups();
                    _log('Reload done.');
                  } catch (e) {
                    _log('Reload error: $e');
                  }
                },
                child: const Text('Reload'),
              ),
            ],
          ),
          const Divider(height: 32),
          const Text(
            'Step 3: Access messages (P2 - send Generic OnOff/Level)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _accessDstCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Destination (group/unicast)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _accessAppKeyIndexCtrl,
                  decoration: const InputDecoration(
                    labelText: 'AppKeyIndex (decimal)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _levelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Level (int, -32768..32767)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton(
                      onPressed: () => _sendOnOff(true),
                      child: const Text('OnOff: ON'),
                    ),
                    ElevatedButton(
                      onPressed: () => _sendOnOff(false),
                      child: const Text('OnOff: OFF'),
                    ),
                    ElevatedButton(
                      onPressed: _sendLevel,
                      child: const Text('Level: SET'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          const Text(
            'Logs',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 320,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(_logs[i], style: const TextStyle(fontFamily: 'monospace')),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

