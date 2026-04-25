import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nrf_mesh_flutter/platojobs_nrf_mesh.dart';

class ScenesPage extends StatefulWidget {
  const ScenesPage({super.key});

  @override
  State<ScenesPage> createState() => _ScenesPageState();
}

class _ScenesPageState extends State<ScenesPage> {
  final _mgr = PlatoJobsNrfMeshManager.instance;

  final _dstController = TextEditingController(text: '0x0001');
  final _appKeyController = TextEditingController(text: '0');
  final _sceneController = TextEditingController(text: '1');

  String _log = '';
  StreamSubscription? _sub1;
  StreamSubscription? _sub2;

  @override
  void initState() {
    super.initState();
    _sub1 = _mgr.sceneStatusStream.listen((e) {
      setState(() {
        _log = '[SceneStatus] code=${e.statusCode} current=${e.currentScene} '
                'target=${e.targetScene} remain=${e.remainingTime}\n$_log';
      });
    });
    _sub2 = _mgr.sceneRegisterStatusStream.listen((e) {
      setState(() {
        _log = '[SceneRegisterStatus] code=${e.statusCode} current=${e.currentScene} '
                'scenes=${e.scenes}\n$_log';
      });
    });
  }

  @override
  void dispose() {
    _sub1?.cancel();
    _sub2?.cancel();
    _dstController.dispose();
    _appKeyController.dispose();
    _sceneController.dispose();
    super.dispose();
  }

  int _parseInt(String s) {
    final t = s.trim();
    if (t.startsWith('0x') || t.startsWith('0X')) {
      return int.parse(t.substring(2), radix: 16);
    }
    return int.parse(t);
  }

  @override
  Widget build(BuildContext context) {
    final dst = _parseInt(_dstController.text);
    final appKeyIndex = _parseInt(_appKeyController.text);
    final sceneNumber = _parseInt(_sceneController.text);

    return Scaffold(
      appBar: AppBar(title: const Text('Scenes (M4)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _dstController,
              decoration: const InputDecoration(labelText: 'Destination (e.g. 0x0001)'),
            ),
            TextField(
              controller: _appKeyController,
              decoration: const InputDecoration(labelText: 'AppKeyIndex'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _sceneController,
              decoration: const InputDecoration(labelText: 'Scene number (1..65535)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () async => _mgr.sceneStore(
                    destination: dst,
                    appKeyIndex: appKeyIndex,
                    sceneNumber: sceneNumber,
                  ),
                  child: const Text('Scene Store'),
                ),
                ElevatedButton(
                  onPressed: () async => _mgr.sceneRecall(
                    destination: dst,
                    appKeyIndex: appKeyIndex,
                    sceneNumber: sceneNumber,
                  ),
                  child: const Text('Scene Recall'),
                ),
                ElevatedButton(
                  onPressed: () async => _mgr.sceneDelete(
                    destination: dst,
                    appKeyIndex: appKeyIndex,
                    sceneNumber: sceneNumber,
                  ),
                  child: const Text('Scene Delete'),
                ),
                ElevatedButton(
                  onPressed: () async => _mgr.sceneGet(
                    destination: dst,
                    appKeyIndex: appKeyIndex,
                  ),
                  child: const Text('Scene Get'),
                ),
                ElevatedButton(
                  onPressed: () async => _mgr.sceneRegisterGet(
                    destination: dst,
                    appKeyIndex: appKeyIndex,
                  ),
                  child: const Text('Scene Register Get'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Incoming Status:'),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(_log),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

