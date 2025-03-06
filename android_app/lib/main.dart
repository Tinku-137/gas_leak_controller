import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gas Control',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: GasControlDashboard(),
    );
  }
}

class GasControlDashboard extends StatefulWidget {
  @override
  _GasControlDashboardState createState() => _GasControlDashboardState();
}

class _GasControlDashboardState extends State<GasControlDashboard> {
  double gasLevel = 0.0;
  bool isValveOpen = false;
  bool leakDetected = false;

  Future<void> fetchGasData() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:8000/data'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          gasLevel = data['gas_level'];
          leakDetected = data['gas_leak'] > 500;
        });
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> toggleValve(bool state) async {
    final response = await http.post(
      Uri.parse('http://localhost:8000/control-valve'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'state': state}),
    );

    if (response.statusCode == 200) {
      setState(() {
        isValveOpen = state;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchGasData();
    // Auto-refresh every 10 seconds
    SystemChannels.lifecycle.setMessageHandler((msg) async {
      if (msg == AppLifecycleState.resumed.toString()) {
        fetchGasData();
      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gas Control Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchGasData,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            GasLevelIndicator(level: gasLevel),
            SizedBox(height: 20),
            _buildValveControl(),
            SizedBox(height: 20),
            _buildAlertsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildValveControl() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Valve Control',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Switch(
              value: isValveOpen,
              onChanged: toggleValve,
              activeColor: Colors.green,
            ),
            Text(
              isValveOpen ? 'REMOTE SHUTOFF ACTIVE' : 'SYSTEM SAFE',
              style: TextStyle(
                color: isValveOpen ? Colors.green : Colors.red,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsSection() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: leakDetected ? Colors.red[100] : Colors.green[50],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            leakDetected ? Icons.warning : Icons.check_circle,
            color: leakDetected ? Colors.red : Colors.green,
            size: 40,
          ),
          SizedBox(width: 15),
          Expanded(
            child: Text(
              leakDetected
                  ? 'EMERGENCY ALERT: Gas leak detected!\nShut off valve immediately!'
                  : 'System Status Normal\nNo leaks detected',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: leakDetected ? Colors.red : Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GasLevelIndicator extends StatelessWidget {
  final double level;

  const GasLevelIndicator({super.key, required this.level});

  Color _getFillColor() {
    if (level > 50) return Colors.green[800]!;
    if (level > 20) return Colors.orange[700]!;
    return Colors.red[800]!;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'CYLINDER LEVEL',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 20),
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Cylinder outline
                Container(
                  width: 100,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                      bottom: Radius.circular(10),
                    ),
                    border: Border.all(
                      color: Colors.grey[400]!,
                      width: 3,
                    ),
                  ),
                ),
                // Liquid fill
                AnimatedContainer(
                  duration: Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  width: 94,
                  height: (level / 100) * 194,
                  margin: EdgeInsets.only(bottom: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _getFillColor().withOpacity(0.8),
                        _getFillColor(),
                      ],
                    ),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(8),
                      top: Radius.circular(28),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              '${level.toStringAsFixed(1)}% REMAINING',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _getFillColor(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}