import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nrf_mesh_flutter/nrf_mesh_flutter.dart';

/// M3: virtual label group + subscription + groupcast (OnOff / Level / raw access).
class GroupMessagingPage extends StatefulWidget {
  const GroupMessagingPage({super.key});

  @override
  State<GroupMessagingPage> createState() => _GroupMessagingPageState();
}

class _GroupMessagingPageState extends State<GroupMessagingPage> {
  final _mesh = PlatoJobsNrfMeshManager.instance;
  final _labelHex = TextEditingController();
  final _elementAddr = TextEditingController(text: '2');
  final _modelId = TextEditingController(text: '4096');
  final _appKey = TextEditingController(text: '0');
  final _rawHex = TextEditingController(text: '01');
  final _level = TextEditingController(text: '0');
  String _log = '';
  int? _cachedVirtualAddress;

  @override
  void initState() {
    super.initState();
    _rollLabel();
  }

  @override
  void dispose() {
    _labelHex.dispose();
    _elementAddr.dispose();
    _modelId.dispose();
    _appKey.dispose();
    _rawHex.dispose();
    _level.dispose();
    super.dispose();
  }

  void _append(String s) {
    setState(() {
      _log = '$s\n$_log';
    });
  }

  void _rollLabel() {
    final r = Random();
    _labelHex.text = List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
    _recomputeAddress();
  }

  List<int>? _parseLabelBytes() {
    final s = _labelHex.text.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (s.length != 32) {
      _append('Label must be 32 hex chars (16 bytes).');
      return null;
    }
    return List.generate(16, (i) => int.parse(s.substring(i * 2, i * 2 + 2), radix: 16));
  }

  void _recomputeAddress() {
    final b = _parseLabelBytes();
    if (b == null) return;
    setState(() {
      _cachedVirtualAddress = meshVirtualAddressFromLabel(b);
    });
  }

  int _readInt(TextEditingController c) => int.parse(c.text.trim(), radix: 0);

  Future<void> _createVirtualGroup() async {
    final b = _parseLabelBytes();
    if (b == null) return;
    try {
      final g = await _mesh.createVirtualGroup('Virtual (example)', b);
      _append('createVirtualGroup -> ${g.groupId} @ ${g.address} (virtual=${g.isVirtual})');
    } catch (e) {
      _append('createVirtualGroup error: $e');
    }
  }

  Future<void> _subscribe() async {
    final b = _parseLabelBytes();
    if (b == null) return;
    try {
      final el = _readInt(_elementAddr);
      final mid = _readInt(_modelId);
      final ok = await _mesh.addSubscriptionVirtual(el, mid, b);
      _append('addSubscriptionVirtual -> $ok (element=0x${el.toRadixString(16)} model=0x${mid.toRadixString(16)})');
    } catch (e) {
      _append('addSubscriptionVirtual error: $e');
    }
  }

  Future<void> _sendOnOff(bool on) async {
    final b = _parseLabelBytes();
    if (b == null) return;
    if (_cachedVirtualAddress == null) _recomputeAddress();
    final a = _cachedVirtualAddress;
    if (a == null) return;
    try {
      final ak = _readInt(_appKey);
      await _mesh.sendMessage(
        GenericOnOffSet(
          state: on,
          address: a,
          appKeyIndex: ak,
          virtualLabel: b,
        ),
      );
      _append('GenericOnOffSet $on -> group 0x${a.toRadixString(16)}');
    } catch (e) {
      _append('send OnOff error: $e');
    }
  }

  Future<void> _sendLevel() async {
    final b = _parseLabelBytes();
    if (b == null) return;
    if (_cachedVirtualAddress == null) _recomputeAddress();
    final a = _cachedVirtualAddress;
    if (a == null) return;
    final lv = int.parse(_level.text.trim());
    try {
      final ak = _readInt(_appKey);
      await _mesh.sendMessage(
        GenericLevelSet(
          level: lv,
          address: a,
          appKeyIndex: ak,
          virtualLabel: b,
        ),
      );
      _append('GenericLevelSet $lv -> group 0x${a.toRadixString(16)}');
    } catch (e) {
      _append('send Level error: $e');
    }
  }

  Future<void> _sendRaw() async {
    final b = _parseLabelBytes();
    if (b == null) return;
    if (_cachedVirtualAddress == null) _recomputeAddress();
    final a = _cachedVirtualAddress;
    if (a == null) return;
    final s = _rawHex.text.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (s.isEmpty) {
      _append('raw hex required');
      return;
    }
    if (s.length % 2 != 0) {
      _append('raw hex even length only');
      return;
    }
    final bytes = List<int>.generate(s.length >> 1, (i) => int.parse(s.substring(i * 2, i * 2 + 2), radix: 16));
    try {
      final ak = _readInt(_appKey);
      await _mesh.sendAccess(
        opCode: 0x8202,
        parameters: bytes,
        address: a,
        appKeyIndex: ak,
        virtualLabel: b,
      );
      _append('raw 0x8202 ${bytes.length}B -> 0x${a.toRadixString(16)} (same as default OnOff params)');
    } catch (e) {
      _append('sendAccess error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('M3 Virtual group messaging'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView(
          children: [
            const Text('Virtual Label (16 B, MSB..LSB as 32 hex chars)'),
            TextField(
              controller: _labelHex,
              onChanged: (_) => _recomputeAddress(),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                hintText: '32 hex',
              ),
            ),
            if (_cachedVirtualAddress != null)
              Text(
                'Computed group address: 0x${_cachedVirtualAddress!.toRadixString(16)} (Dart meshVirtualAddressFromLabel)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(onPressed: _rollLabel, child: const Text('Random label')),
                const SizedBox(width: 8),
                FilledButton.tonal(onPressed: _createVirtualGroup, child: const Text('Create virtual group (DB)')),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Subscribe node model to this label'),
            TextField(
              controller: _elementAddr,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Element unicast (decimal or 0x..)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            TextField(
              controller: _modelId,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Model id (0x1000=Generic OnOff Srv, decimal or 0x..)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _subscribe, child: const Text('Config: subscription virtual (proxy required)')),
            const Divider(height: 32),
            TextField(
              controller: _appKey,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'App key index',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(onPressed: () => _sendOnOff(true), child: const Text('OnOff ON')),
                const SizedBox(width: 8),
                FilledButton(onPressed: () => _sendOnOff(false), child: const Text('OnOff OFF')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _level,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Level (-32768..32767)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(onPressed: _sendLevel, child: const Text('Generic Level Set')),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Raw (opcode fixed 0x8202, params = hex)'),
            TextField(
              controller: _rawHex,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                hintText: 'e.g. 01 <tid> for onoff',
              ),
            ),
            FilledButton.tonal(onPressed: _sendRaw, child: const Text('Send raw 0x8202')),
            const SizedBox(height: 16),
            const Text('Log', style: TextStyle(fontWeight: FontWeight.bold)),
            SelectableText(_log.isEmpty ? '—' : _log, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
