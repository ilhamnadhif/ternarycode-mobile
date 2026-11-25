import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../state/app_controller.dart';
import '../theme/slate_theme.dart';
import '../theme/slate_tokens.dart';
import '../widgets/slate_widgets.dart';

/// Screen 03 · Manual Pairing & local Wi-Fi LAN discovery.
/// Preserves typed inputs when validation or connection fails.
class ManualPairScreen extends StatefulWidget {
  const ManualPairScreen({
    super.key,
    required this.controller,
    required this.onPaired,
    this.initialUrl = '',
    this.initialCode = '',
  });

  final AppController controller;
  final VoidCallback onPaired;
  final String initialUrl;
  final String initialCode;

  @override
  State<ManualPairScreen> createState() => _ManualPairScreenState();
}

class _ManualPairScreenState extends State<ManualPairScreen> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.initialUrl);
    _codeCtrl = TextEditingController(text: widget.initialCode);
    _nameCtrl = TextEditingController(text: 'Android Phone');
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final err = await widget.controller.pairHost(
      rawUrl: _urlCtrl.text,
      code: _codeCtrl.text,
      deviceName: _nameCtrl.text,
    );
    if (!mounted) return;
    if (err == null) {
      widget.onPaired();
    } else {
      setState(() {
        _submitting = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return Scaffold(
      backgroundColor: c.window,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final discovered = widget.controller.discoveredHosts;
            final scanning = widget.controller.discoveringLan;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SlateIconButton(
                        icon: PhosphorIconsRegular.arrowLeft,
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Manual pairing',
                        style: SlateTypography.title(c, size: 19),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  _FieldLabel('Host address (LAN or tunnel)'),
                  SlateTextField(
                    controller: _urlCtrl,
                    hint: 'http://192.168.1.5:7890 or https://tc.example.com',
                    prefixIcon: PhosphorIconsRegular.globe,
                    mono: true,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),

                  _FieldLabel('Pairing code'),
                  SlateTextField(
                    controller: _codeCtrl,
                    hint: 'XXXX-XXXX-XXXX',
                    prefixIcon: PhosphorIconsRegular.key,
                    mono: true,
                    error: _error != null,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),

                  _FieldLabel('Device name'),
                  SlateTextField(
                    controller: _nameCtrl,
                    hint: 'Pixel 9 Pro',
                    prefixIcon: PhosphorIconsRegular.deviceMobile,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(
                            PhosphorIconsFill.xCircle,
                            size: 14,
                            color: c.failed,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: c.failed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  SlateButton(
                    label: 'Connect',
                    busy: _submitting,
                    expanded: true,
                    onPressed: _submit,
                  ),

                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(
                        child: SlateSectionLabel('Discover on Wi-Fi LAN'),
                      ),
                      const SizedBox(width: 8),
                      SlateGoButton(
                        label: scanning ? 'Scanning…' : 'Scan Wi-Fi',
                        icon: PhosphorIconsRegular.wifiHigh,
                        onTap: scanning
                            ? () {}
                            : () => widget.controller.scanLanHosts(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SlateCard(
                    child: discovered.isEmpty
                        ? SlateRow(
                            minHeight: 46,
                            leading: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: scanning ? c.running : c.idle,
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(
                              scanning
                                  ? 'Scanning local subnet on port 7890…'
                                  : 'No desktop found yet',
                              style: SlateTypography.body2(c),
                            ),
                            monoSubtitle:
                                'Enable Companion in desktop Settings → Phone',
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < discovered.length; i++)
                                SlateRow(
                                  showTopDivider: i > 0,
                                  minHeight: 48,
                                  leading: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: c.done,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  title: Text(
                                    discovered[i].name,
                                    style: SlateTypography.body(c,
                                        weight: FontWeight.w500),
                                  ),
                                  monoSubtitle:
                                      '${discovered[i].baseUrl} · ${discovered[i].latencyMs} ms',
                                  trailing: SlateGoButton(
                                    label: 'Use',
                                    onTap: () {
                                      _urlCtrl.text = discovered[i].baseUrl;
                                      widget.controller.showToast(
                                        'Filled ${discovered[i].baseUrl}',
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Your typed code and device name stay intact if a connection check fails. Each phone receives its own revocable Bearer token.',
                    style: SlateTypography.body2(c).copyWith(color: c.text3),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: c.text2,
        ),
      ),
    );
  }
}
