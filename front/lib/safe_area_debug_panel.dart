import 'package:flutter/material.dart';
import 'telegram_safe_area.dart';
import 'dart:async';

/// Debug panel to display Telegram safe area information
class SafeAreaDebugPanel extends StatefulWidget {
  const SafeAreaDebugPanel({super.key});

  @override
  State<SafeAreaDebugPanel> createState() => _SafeAreaDebugPanelState();
}

class _SafeAreaDebugPanelState extends State<SafeAreaDebugPanel> {
  final TelegramSafeAreaService _service = TelegramSafeAreaService();
  SafeAreaInsets _currentSafeArea = SafeAreaInsets.zero;
  Map<String, dynamic> _debugInfo = {};
  StreamSubscription<String>? _logSubscription;
  bool _isExpanded = true; // Always opened
  bool _useBottomPosition = true; // Start at bottom to avoid Telegram header
  List<String> _consoleLogs = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Subscribe to service logs
    _logSubscription = _service.logStream.listen((log) {
      if (mounted) {
        setState(() {
          _addLog(log);
        });
      }
    });

    await _service.initialize();

    // Get initial values once on load
    _currentSafeArea = _service.currentSafeArea;
    _debugInfo = _service.getDebugInfo();
    _consoleLogs = _service.recentLogs;
    _addLog('Initialized. Safe area: $_currentSafeArea');
    _addLog('TMA.js available: ${_service.isTmaJsAvailable}');
    _addLog('WebApp available: ${_service.isAvailable}');

    setState(() {});
  }

  void _addLog(String message) {
    if (mounted) {
      setState(() {
        final timestamp = DateTime.now().toString().substring(11, 19);
        _consoleLogs.add('[$timestamp] $message');
        if (_consoleLogs.length > 20) {
          _consoleLogs.removeAt(0);
        }
      });
    }
  }

  Future<void> _refreshSafeArea() async {
    await _service.requestSafeArea();
    setState(() {
      _currentSafeArea = _service.currentSafeArea;
      _debugInfo = _service.getDebugInfo();
    });
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Position below Telegram's header/status bar using safe area
    // Add extra offset to ensure visibility (safe area + 60px for Telegram header)
    final topOffset = _currentSafeArea.top + 60.0;
    final bottomOffset = _currentSafeArea.bottom + 80.0; // Space for bottom UI

    return Positioned(
      top: _useBottomPosition ? null : topOffset,
      bottom: _useBottomPosition ? bottomOffset : null,
      right: 8,
      child: Container(
        width: _isExpanded ? 320 : 50,
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.cyan.withOpacity(0.7), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.cyan.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 3,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: _isExpanded ? _buildExpandedPanel() : _buildCollapsedButton(),
      ),
    );
  }

  Widget _buildCollapsedButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _isExpanded = true),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _currentSafeArea.isEmpty
                      ? Colors.orange.withOpacity(0.3)
                      : Colors.green.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'SA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Safe Area Debug',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                onPressed: () => setState(() => _isExpanded = false),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        // Content
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Safe Area Inset (NEW - device safe area)
                Builder(
                  builder: (context) {
                    final safeAreaInset = _service.getSafeAreaInset();
                    return _buildSection(
                      'safeAreaInset (Device)',
                      [
                        _buildInfoRow('Top', '${safeAreaInset.top}px'),
                        _buildInfoRow('Bottom', '${safeAreaInset.bottom}px'),
                        _buildInfoRow('Left', '${safeAreaInset.left}px'),
                        _buildInfoRow('Right', '${safeAreaInset.right}px'),
                        _buildInfoRow(
                          'Status',
                          safeAreaInset.isEmpty ? 'Empty' : 'Active',
                          valueColor: safeAreaInset.isEmpty
                              ? Colors.orange
                              : Colors.green,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Content Safe Area Inset (NEW - content safe area)
                Builder(
                  builder: (context) {
                    final contentSafeAreaInset =
                        _service.getContentSafeAreaInset();
                    return _buildSection(
                      'contentSafeAreaInset (Content)',
                      [
                        _buildInfoRow('Top', '${contentSafeAreaInset.top}px'),
                        _buildInfoRow(
                            'Bottom', '${contentSafeAreaInset.bottom}px'),
                        _buildInfoRow('Left', '${contentSafeAreaInset.left}px'),
                        _buildInfoRow(
                            'Right', '${contentSafeAreaInset.right}px'),
                        _buildInfoRow(
                          'Status',
                          contentSafeAreaInset.isEmpty ? 'Empty' : 'Active',
                          valueColor: contentSafeAreaInset.isEmpty
                              ? Colors.orange
                              : Colors.green,
                        ),
                      ],
                    );
                  },
                ),
                // Telegram Info
                _buildSection(
                  'Telegram WebApp',
                  [
                    _buildInfoRow(
                      'Available',
                      _service.isAvailable ? 'Yes' : 'No',
                      valueColor:
                          _service.isAvailable ? Colors.green : Colors.red,
                    ),
                    if (_debugInfo['version'] != null)
                      _buildInfoRow('Version', '${_debugInfo['version']}'),
                    if (_debugInfo['platform'] != null)
                      _buildInfoRow('Platform', '${_debugInfo['platform']}'),
                    if (_debugInfo['viewportHeight'] != null)
                      _buildInfoRow(
                        'Viewport Height',
                        '${_debugInfo['viewportHeight']}px',
                      ),
                    if (_debugInfo['viewportStableHeight'] != null)
                      _buildInfoRow(
                        'Stable Height',
                        '${_debugInfo['viewportStableHeight']}px',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Actions
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              _addLog('Manual refresh triggered');
                              _refreshSafeArea();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text('Refresh',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              _addLog('Manual mount triggered');
                              // Re-initialize to remount viewport
                              await _service.initialize();
                              setState(() {
                                _currentSafeArea = _service.currentSafeArea;
                                _debugInfo = _service.getDebugInfo();
                                _consoleLogs = _service.recentLogs;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text('Remount',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => setState(
                              () => _useBottomPosition = !_useBottomPosition),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 8),
                            minimumSize: const Size(40, 36),
                          ),
                          child: Icon(
                            _useBottomPosition
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Debug Logs
                _buildSection(
                  'Debug Logs (Last 30)',
                  [
                    Container(
                      height: 200,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: _consoleLogs.isEmpty
                          ? const Center(
                              child: Text(
                                'No logs yet. Logs will appear here.',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 10,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _consoleLogs.length > 30
                                  ? 30
                                  : _consoleLogs.length,
                              itemBuilder: (context, index) {
                                final log = _consoleLogs[
                                    _consoleLogs.length - 1 - index];
                                final isError = log.contains('Error') ||
                                    log.contains('null') ||
                                    log.contains('not found');
                                final isSuccess =
                                    log.contains('✓') || log.contains('Parsed');
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    log,
                                    style: TextStyle(
                                      color: isError
                                          ? Colors.red
                                          : isSuccess
                                              ? Colors.green
                                              : Colors.white70,
                                      fontSize: 9,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
                if (_debugInfo['error'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Error: ${_debugInfo['error']}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
