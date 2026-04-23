import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nrf_mesh_flutter/nrf_mesh_flutter.dart';

class ProvisioningDemoPage extends StatefulWidget {
  const ProvisioningDemoPage({super.key});

  @override
  State<ProvisioningDemoPage> createState() => _ProvisioningDemoPageState();
}

class _ProvisioningDemoPageState extends State<ProvisioningDemoPage> {
  final _mesh = PlatoJobsNrfMeshManager.instance;
  StreamSubscription<UnprovisionedDevice>? _scanSub;
  StreamSubscription<ProvisioningEvent>? _provSub;

  final List<UnprovisionedDevice> _devices = <UnprovisionedDevice>[];
  final List<ProvisionedNode> _nodes = <ProvisionedNode>[];
  String _status = 'Ready';

  ProvisioningEvent? _lastProvEvent;
  final _oobController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _provSub = _mesh.provisioningEventStream.listen((e) {
      setState(() {
        _lastProvEvent = e;
        _status = 'Provisioning: ${e.type} ${e.message ?? ''}';
      });
      _reloadNodes();
    });
    _reloadNodes();
  }

  Future<void> _reloadNodes() async {
    try {
      final nodes = await _mesh.getNodes();
      setState(() {
        _nodes
          ..clear()
          ..addAll(nodes);
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _startScan() async {
    await _scanSub?.cancel();
    setState(() {
      _devices.clear();
      _status = 'Scanning...';
    });
    _scanSub = _mesh.scanForDevices().listen((d) {
      setState(() {
        if (!_devices.any((x) => x.deviceId == d.deviceId)) {
          _devices.add(d);
        }
      });
    });
  }

  Future<void> _stopScan() async {
    await _mesh.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    setState(() => _status = 'Scan stopped');
  }

  Future<void> _connectProvisioning(UnprovisionedDevice d) async {
    try {
      setState(() => _status = 'Connecting provisioning bearer...');
      final ok = await _mesh.connectProvisioning(d.deviceId);
      setState(() => _status = ok ? 'Provisioning bearer connected' : 'Connect failed');
    } catch (e) {
      setState(() => _status = 'Connect error: $e');
    }
  }

  Future<void> _provision(UnprovisionedDevice d) async {
    try {
      setState(() => _status = 'Provisioning...');
      await _mesh.provisionDevice(
        d,
        ProvisioningParameters(
          deviceName: d.name.isEmpty ? 'Mesh Device' : d.name,
          // You can switch oobMethod/oobData here for testing.
          // oobMethod: 0, // No OOB
        ),
      );
      setState(() => _status = 'Provision call returned (check events)');
      await _reloadNodes();
    } catch (e) {
      setState(() => _status = 'Provision error: $e');
    }
  }

  Future<void> _submitOutputOob() async {
    final e = _lastProvEvent;
    if (e == null) return;
    final deviceId = e.deviceId ?? '';
    final v = _oobController.text.trim();
    if (deviceId.isEmpty || v.isEmpty) return;
    try {
      final numeric = int.tryParse(v);
      final ok = numeric != null
          ? await _mesh.provideProvisioningOobNumeric(deviceId, numeric)
          : await _mesh.provideProvisioningOobAlphaNumeric(deviceId, v);
      setState(() => _status = ok ? 'OOB input submitted' : 'OOB submit rejected');
    } catch (err) {
      setState(() => _status = 'OOB submit error: $err');
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _provSub?.cancel();
    _oobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsOobInput = _lastProvEvent?.type == ProvisioningEventType.oobInputRequested;
    return Scaffold(
      appBar: AppBar(title: const Text('Provisioning Demo (M1)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: $_status'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton(
                  onPressed: _startScan,
                  child: const Text('Start Scan'),
                ),
                ElevatedButton(
                  onPressed: _stopScan,
                  child: const Text('Stop Scan'),
                ),
                ElevatedButton(
                  onPressed: _reloadNodes,
                  child: const Text('Refresh Nodes'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (needsOobInput) ...[
              TextField(
                controller: _oobController,
                decoration: const InputDecoration(
                  labelText: 'Output OOB input (numeric or text)',
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _submitOutputOob,
                child: const Text('Submit OOB Input'),
              ),
              const SizedBox(height: 16),
            ],
            const Text('Unprovisioned devices', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView(
                children: [
                  for (final d in _devices)
                    Card(
                      child: ListTile(
                        title: Text(d.name.isEmpty ? '(unknown)' : d.name),
                        subtitle: Text('id=${d.deviceId} service=${d.serviceUuid} rssi=${d.rssi}'),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => _connectProvisioning(d),
                              child: const Text('Connect'),
                            ),
                            TextButton(
                              onPressed: () => _provision(d),
                              child: const Text('Provision'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Nodes in network: ${_nodes.length}'),
          ],
        ),
      ),
    );
  }
}

