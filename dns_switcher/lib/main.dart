import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';
import 'dart:io' show Platform;

void main() {
  runApp(const DNSSwitcherApp());
}

class DNSSwitcherApp extends StatelessWidget {
  const DNSSwitcherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DNS Switcher Pro',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryColorSeed,
          brightness: Brightness.light,
          primary: AppColors.primaryColorSeed,
          onPrimary: Colors.white,
          primaryContainer: AppColors.primaryColorAccent.withOpacity(0.1),
          onPrimaryContainer: AppColors.primaryColorDark,
          surface: Colors.grey.shade50,
          onSurface: AppColors.primaryColorDark,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primaryColorDark,
          elevation: 0,
          scrolledUnderElevation: 1,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          titleTextStyle: TextStyle(
            color: AppColors.primaryColorDark,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: AppColors.primaryColorAccent,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppColors.primaryColorAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primaryColorAccent, width: 2),
          ),
          labelStyle: TextStyle(color: Colors.grey.shade600),
          hintStyle: TextStyle(color: Colors.grey.shade500),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const DNSSwitcherHomePage(),
    );
  }
}

class DNSSwitcherHomePage extends StatefulWidget {
  const DNSSwitcherHomePage({super.key});

  @override
  State<DNSSwitcherHomePage> createState() => _DNSSwitcherHomePageState();
}

class _DNSSwitcherHomePageState extends State<DNSSwitcherHomePage>
    with TickerProviderStateMixin {
  bool _isDNSActive = false;
  bool _isLoading = false; // New loading state
  List<Map<String, String>> _customDNSList = [];
  String? _selectedDNS;
  String? _loadingDNS; // Track which DNS is being activated
  late AnimationController _statusAnimationController;
  late AnimationController _loadingAnimationController; // New loading animation controller
  late Animation<double> _statusAnimation;
  late Animation<double> _loadingAnimation; // New loading animation
  static const _vpnChannel = MethodChannel('com.example.dns_switcher/vpn');

  final List<Map<String, dynamic>> _predefinedDNS = [
    {
      'name': 'Google DNS',
      'subtitle': 'Fast & Reliable',
      'address': '8.8.8.8, 8.8.4.4',
      'icon': Icons.speed,
      'description': 'Google\'s fast and reliable DNS service',
    },
    {
      'name': 'Cloudflare DNS',
      'subtitle': 'Privacy Focused',
      'address': '1.1.1.1, 1.0.0.1',
      'icon': Icons.security,
      'description': 'Privacy-first DNS with built-in security',
    },
    {
      'name': 'Quad9 DNS',
      'subtitle': 'Security Enhanced',
      'address': '9.9.9.9, 149.112.112.112',
      'icon': Icons.shield,
      'description': 'Blocks malicious domains automatically',
    },
    {
      'name': 'OpenDNS',
      'subtitle': 'Customizable',
      'address': '208.67.222.222, 208.67.220.220',
      'icon': Icons.tune,
      'description': 'Customizable filtering and parental controls',
    },
  ];

  @override
  void initState() {
    super.initState();
    _statusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _statusAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _statusAnimationController,
      curve: Curves.easeInOut,
    ));
    _loadingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _statusAnimationController.dispose();
    _loadingAnimationController.dispose();
    super.dispose();
  }

  bool _isValidIPAddress(String ip) {
    if (ip.trim().isEmpty) return false;
    
    ip = ip.trim();
    
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    
    for (final part in parts) {
      if (part.isEmpty) return false;
      
      final number = int.tryParse(part);
      if (number == null) return false;
      
      if (number < 0 || number > 255) return false;
      
      if (part.length > 1 && part.startsWith('0')) return false;
    }
    
    return true;
  }

  String? _validateDNSAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a DNS address';
    }
    
    final addresses = value.split(',').map((e) => e.trim()).toList();
    
    for (final address in addresses) {
      if (!_isValidIPAddress(address)) {
        return 'Invalid IP address format: $address\nExample: 8.8.8.8 or 8.8.8.8, 8.8.4.4';
      }
    }
    
    return null;
  }

  void _showTopSnackBar(String message, Color backgroundColor, {IconData? icon}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(overlayEntry);
    
    // Remove the overlay after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }

  void _selectDNS(String dnsName) async {
    if (Platform.isIOS) {
      _showTopSnackBar(
        'This feature is not available for iOS at the moment.',
        Colors.red.shade600,
        icon: Icons.error,
      );
      return;
    }

    // Start loading state
    setState(() {
      _isLoading = true;
      _loadingDNS = dnsName;
    });
    _loadingAnimationController.repeat();

    String? dnsAddress;
    for (var dns in _predefinedDNS) {
      if (dns['name'] == dnsName) {
        dnsAddress = dns['address'];
        break;
      }
    }
    if (dnsAddress == null) {
      for (var dns in _customDNSList) {
        if (dns['name'] == dnsName) {
          dnsAddress = dns['address'];
          break;
        }
      }
    }

    if (dnsAddress != null) {
      try {
        await _startVpn(dnsAddress);
        
        // Success - update UI
        setState(() {
          _selectedDNS = dnsName;
          _isDNSActive = true;
          _isLoading = false;
          _loadingDNS = null;
        });
        _loadingAnimationController.stop();
        _statusAnimationController.forward();

        _showTopSnackBar(
          '$dnsName activated successfully',
          Colors.green.shade600,
          icon: Icons.check_circle,
        );

        debugPrint('Selected DNS: $dnsName');
        
      } catch (e) {
        // Error - reset loading state
        setState(() {
          _isLoading = false;
          _loadingDNS = null;
        });
        _loadingAnimationController.stop();
        
        // Handle different types of errors
        String errorMessage;
        if (e.toString().contains('PERMISSION_DENIED') || 
            e.toString().contains('User denied VPN permission')) {
          errorMessage = 'VPN permission denied. Please allow VPN access to use this feature.';
        } else {
          errorMessage = 'Failed to activate DNS. Please try again.';
        }
        
        _showTopSnackBar(
          errorMessage,
          Colors.red.shade600,
          icon: Icons.error,
        );
        
        debugPrint('Error starting VPN: $e');
      }
    }
  }

  Future<void> _startVpn(String dnsAddress) async {
    await _vpnChannel.invokeMethod('startVpn', {'dnsAddress': dnsAddress});
  }

  void _deactivateDNS() {
    if (Platform.isIOS) {
      _showTopSnackBar(
        'This feature is not available for iOS at the moment.',
        Colors.red.shade600,
        icon: Icons.error,
      );
      return;
    }

    setState(() {
      _isDNSActive = false;
      _selectedDNS = null;
    });
    _statusAnimationController.reverse();

    _stopVpn();

    _showTopSnackBar(
      'DNS deactivated',
      Colors.orange.shade600,
      icon: Icons.power_off,
    );

    debugPrint('DNS Deactivated');
  }

  Future<void> _stopVpn() async {
    try {
      await _vpnChannel.invokeMethod('stopVpn');
    } catch (e) {
      debugPrint('Error stopping VPN: $e');
      _showTopSnackBar(
        'Failed to stop VPN: $e',
        Colors.red.shade600,
        icon: Icons.error,
      );
    }
  }

  void _showAddDNSDialog() {
    String? dnsName;
    String? dnsAddress;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.add_circle, color: AppColors.primaryColorAccent),
            const SizedBox(width: 12),
            const Text('Add Custom DNS'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'DNS Name',
                  hintText: 'e.g., My Custom DNS',
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a DNS name';
                  }
                  return null;
                },
                onChanged: (value) => dnsName = value.trim(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'DNS Address',
                  hintText: 'e.g., 8.8.8.8 or 8.8.8.8, 8.8.4.4',
                  prefixIcon: Icon(Icons.dns),
                ),
                validator: _validateDNSAddress,
                onChanged: (value) => dnsAddress = value.trim(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                setState(() {
                  _customDNSList.add({
                    'name': dnsName!,
                    'address': dnsAddress!,
                  });
                });
                debugPrint('Added Custom DNS: $dnsName ($dnsAddress)');
                Navigator.pop(context);
                
                _showTopSnackBar(
                  'Custom DNS "$dnsName" added successfully',
                  Colors.green.shade600,
                  icon: Icons.check_circle,
                );
              }
            },
            child: const Text('Add DNS'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDNSDialog(String dnsName, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete, color: Colors.red.shade600),
            const SizedBox(width: 12),
            const Text('Delete Custom DNS'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$dnsName"?\n\nThis action cannot be undone.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                if (_selectedDNS == dnsName) {
                  _isDNSActive = false;
                  _selectedDNS = null;
                  _statusAnimationController.reverse();
                }
                _customDNSList.removeAt(index);
              });
              
              debugPrint('Deleted Custom DNS: $dnsName');
              Navigator.pop(context);
              
              _showTopSnackBar(
                'Custom DNS "$dnsName" deleted',
                Colors.red.shade600,
                icon: Icons.delete,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),  
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return AnimatedBuilder(
      animation: _statusAnimation,
      builder: (context, child) {
        Color cardColor;
        String statusText;
        IconData statusIcon;
        
        if (_isLoading) {
          cardColor = Colors.blue.shade500;
          statusText = 'Connecting...';
          statusIcon = Icons.sync;
        } else if (_isDNSActive) {
          cardColor = Colors.green.shade500;
          statusText = 'Active';
          statusIcon = Icons.check_circle;
        } else {
          cardColor = Colors.grey.shade500;
          statusText = 'Inactive';
          statusIcon = Icons.cancel;
        }

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cardColor.withOpacity(0.8), cardColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: cardColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'DNS Status',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _loadingAnimation,
                      builder: (context, child) {
                        if (_isLoading) {
                          return Transform.rotate(
                            angle: _loadingAnimation.value * 2 * 3.14159,
                            child: Icon(
                              statusIcon,
                              color: Colors.white,
                              size: 24,
                            ),
                          );
                        } else {
                          return AnimatedRotation(
                            turns: _statusAnimation.value,
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              statusIcon,
                              color: Colors.white,
                              size: 24,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isLoading && _loadingDNS != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Activating: $_loadingDNS',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ] else if (_isDNSActive && _selectedDNS != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Using: $_selectedDNS',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDNSOption({
    required String name,
    required String subtitle,
    required String address,
    required IconData icon,
    required String description,
    bool isSelected = false,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool isCustom = false,
  }) {
    bool isCurrentlyLoading = _isLoading && _loadingDNS == name;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _isLoading ? null : onTap, // Disable tap when loading
        onLongPress: _isLoading ? null : onLongPress, // Disable long press when loading
        child: Opacity(
          opacity: _isLoading && !isCurrentlyLoading ? 0.5 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryColorAccent
                        : isCurrentlyLoading
                            ? Colors.blue.shade100
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: isCurrentlyLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue.shade600,
                            ),
                          ),
                        )
                      : Icon(
                          icon,
                          color: isSelected ? Colors.white : AppColors.primaryColorText,
                          size: 24,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryColorDark,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            )
                          else if (isCurrentlyLoading)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'CONNECTING',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryColorAccent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isCustom) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• Hold to delete',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (!isCustom) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 24,
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (_isDNSActive)
          FloatingActionButton.extended(
            onPressed: _isLoading ? null : _deactivateDNS,
            icon: const Icon(Icons.power_off),
            label: const Text('Deactivate'),
            backgroundColor: _isLoading ? Colors.grey : Colors.red.shade600,
            heroTag: "deactivate_btn",
          ),
        
        FloatingActionButton.extended(
          onPressed: _isLoading ? null : _showAddDNSDialog,
          icon: const Icon(Icons.add),
          label: const Text('Add Custom DNS'),
          backgroundColor: _isLoading ? Colors.grey : AppColors.primaryColorAccent,
          heroTag: "add_dns_btn",
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('DNS Switcher Pro'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('About DNS Switcher Pro'),
                  content: const Text(
                    'Change your DNS settings to improve internet speed, security, and privacy. Select from predefined options or add your own custom DNS servers.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 24),
            
            Row(
              children: [
                Icon(Icons.dns, color: AppColors.primaryColorAccent),
                const SizedBox(width: 8),
                Text(
                  'DNS Providers',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColorDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            ..._predefinedDNS.map((dns) => _buildDNSOption(
              name: dns['name'],
              subtitle: dns['subtitle'],
              address: dns['address'],
              icon: dns['icon'],
              description: dns['description'],
              isSelected: _selectedDNS == dns['name'],
              onTap: () => _selectDNS(dns['name']),
            )),
            
            if (_customDNSList.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.settings, color: AppColors.primaryColorAccent),
                  const SizedBox(width: 8),
                  Text(
                    'Custom DNS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColorDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              ..._customDNSList.asMap().entries.map((entry) {
                int index = entry.key;
                Map<String, String> dns = entry.value;
                return _buildDNSOption(
                  name: dns['name']!,
                  subtitle: 'Custom DNS',
                  address: dns['address']!,
                  icon: Icons.dns,
                  description: '',
                  isSelected: _selectedDNS == dns['name'],
                  onTap: () => _selectDNS(dns['name']!),
                  onLongPress: () => _showDeleteDNSDialog(dns['name']!, index),
                  isCustom: true,
                );
              }),
            ],
            
            const SizedBox(height: 100), // Extra space for floating buttons
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButtons(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}