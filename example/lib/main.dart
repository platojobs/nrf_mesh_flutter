import 'package:flutter/material.dart';
import 'dart:async';

import 'package:nrf_mesh_flutter/nrf_mesh_flutter.dart';
import 'real_p1_page.dart';
import 'provisioning_demo_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PlatoJobsNrfMeshManager.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _meshManager = PlatoJobsNrfMeshManager.instance;
  MeshNetwork? _network;
  List<UnprovisionedDevice> _devices = [];
  List<ProvisionedNode> _nodes = [];
  List<MeshGroup> _groups = [];
  bool _isScanning = false;
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    _loadNetwork();
    _listenToMessages();
  }

  Future<void> _loadNetwork() async {
    try {
      setState(() => _status = 'Loading network...');
      _network = await _meshManager.loadNetwork();
      if (_network == null) {
        _network = await _meshManager.createNetwork('My Mesh Network');
        setState(() => _status = 'Network created');
      } else {
        setState(() => _status = 'Network loaded');
      }
      _loadNodesAndGroups();
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _loadNodesAndGroups() async {
    _nodes = await _meshManager.getNodes();
    _groups = await _meshManager.getGroups();
    setState(() {});
  }

  void _listenToMessages() {
    _meshManager.messageStream.listen((message) {
      setState(() {
        _status = 'Received message: ${message.opcode}';
      });
    });
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _devices = [];
      _status = 'Scanning for devices...';
    });

    _meshManager.scanForDevices().listen((device) {
      setState(() {
        final id = device.deviceId;
        if (!_devices.any((d) => d.deviceId == id)) {
          _devices.add(device);
        }
      });
    });
  }

  Future<void> _stopScan() async {
    await _meshManager.stopScan();
    setState(() {
      _isScanning = false;
      _status = 'Scan stopped';
    });
  }

  Future<void> _provisionDevice(UnprovisionedDevice device) async {
    try {
      setState(() => _status = 'Provisioning device...');
      await _meshManager.provisionDevice(
        device,
        ProvisioningParameters(
          deviceName: device.name.isEmpty ? 'Mesh Device' : device.name,
        ),
      );
      setState(() => _status = 'Device provisioned');
      await _loadNodesAndGroups();
    } catch (e) {
      setState(() => _status = 'Provisioning error: $e');
    }
  }

  Future<void> _sendTestMessage() async {
    try {
      if (_nodes.isEmpty) {
        setState(() => _status = 'No nodes available');
        return;
      }

      setState(() => _status = 'Sending test message...');
      await _meshManager.sendMessage(
        GenericOnOffSet(
          state: true,
          transitionTime: 0,
          delay: 0,
          address: 0xC000,
          appKeyIndex: 0,
        ),
      );
      setState(() => _status = 'Message sent');
    } catch (e) {
      setState(() => _status = 'Send error: $e');
    }
  }

  Future<void> _configDemo() async {
    try {
      if (_nodes.isEmpty) {
        setState(() => _status = 'No nodes available');
        return;
      }
      final first = _nodes.first;
      if (first.elements.isEmpty || first.elements.first.models.isEmpty) {
        setState(() => _status = 'Node has no models');
        return;
      }
      final elementAddress = int.tryParse(
            first.elements.first.address.replaceAll('0x', ''),
            radix: 16,
          ) ??
          1;
      final modelId = int.tryParse(first.elements.first.models.first.modelId) ?? 0x1000;

      setState(() => _status = 'Configuring model...');
      await _meshManager.bindAppKey(elementAddress, modelId, 0);
      await _meshManager.addSubscription(elementAddress, modelId, 0xC000);
      await _meshManager.setPublication(elementAddress, modelId, 0xC000, 0, ttl: 5);
      setState(() => _status = 'Config updated');
      await _loadNodesAndGroups();
    } catch (e) {
      setState(() => _status = 'Config error: $e');
    }
  }

  Future<void> _createGroup() async {
    try {
      setState(() => _status = 'Creating group...');
      await _meshManager.createGroup('Test Group');
      setState(() => _status = 'Group created');
      await _loadNodesAndGroups();
    } catch (e) {
      setState(() => _status = 'Create group error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('PlatoJobs nRF Mesh Example')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: $_status', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              if (_network != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Network',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('Name: ${_network?.name}'),
                        Text('Nodes: ${_nodes.length}'),
                        Text('Groups: ${_groups.length}'),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _isScanning ? _stopScan : _startScan,
                    child: Text(_isScanning ? 'Stop Scan' : 'Start Scan'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _sendTestMessage,
                    child: const Text('Send Test Message'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _createGroup,
                    child: const Text('Create Group'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _configDemo,
                    child: const Text('Config Demo'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RealP1Page(),
                        ),
                      );
                    },
                    child: const Text('P1 Real Flow'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ProvisioningDemoPage(),
                        ),
                      );
                    },
                    child: const Text('M1 Provisioning'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Provisioned Nodes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  itemCount: _nodes.length,
                  itemBuilder: (context, index) {
                    final node = _nodes[index];
                    final element = node.elements.isNotEmpty ? node.elements.first : null;
                    final model = (element != null && element.models.isNotEmpty) ? element.models.first : null;
                    return ListTile(
                      dense: true,
                      title: Text('Node ${node.uuid} @ ${node.unicastAddress}'),
                      subtitle: model == null
                          ? const Text('No model info')
                          : Text(
                              'Element: ${element!.address}\n'
                              'Model: ${model.modelName} (${model.modelId})\n'
                              'Bound AppKeys: ${model.boundAppKeyIndexes}\n'
                              'Subs: ${model.subscriptions}\n'
                              'Pub: ${model.publication == null ? 'null' : 'addr=${model.publication!.address} appKey=${model.publication!.appKeyIndex} ttl=${model.publication!.ttl}'}',
                            ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Discovered Devices',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    return ListTile(
                      title: Text(device.name),
                      subtitle: Text(
                        'ID: ${device.deviceId}\nRSSI: ${device.rssi}',
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => _provisionDevice(device),
                        child: const Text('Provision'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
