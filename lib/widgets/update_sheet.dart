import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/apk_updater.dart';
import '../theme/slate_theme.dart';
import '../theme/slate_tokens.dart';
import 'slate_widgets.dart';

/// Slate bottom sheet for checking, downloading (with SHA-256 verification),
/// and installing GitHub Release APKs directly on Android.
Future<void> showApkUpdateSheet({
  required BuildContext context,
  required ApkUpdater updater,
  required ApkReleaseInfo release,
  required ValueChanged<String> onToast,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ApkUpdateSheetBody(
      updater: updater,
      release: release,
      onToast: onToast,
    ),
  );
}

class _ApkUpdateSheetBody extends StatefulWidget {
  const _ApkUpdateSheetBody({
    required this.updater,
    required this.release,
    required this.onToast,
  });

  final ApkUpdater updater;
  final ApkReleaseInfo release;
  final ValueChanged<String> onToast;

  @override
  State<_ApkUpdateSheetBody> createState() => _ApkUpdateSheetBodyState();
}

class _ApkUpdateSheetBodyState extends State<_ApkUpdateSheetBody> {
  bool _busy = false;
  ApkDownloadProgress? _progress;
  File? _downloadedFile;
  bool _needsInstallPermission = false;
  String? _error;

  String _formatBytes(int b) {
    if (b >= 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (b >= 1024) {
      return '${(b / 1024).toStringAsFixed(0)} KB';
    }
    return '$b B';
  }

  Future<void> _downloadAndInstall() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _needsInstallPermission = false;
    });

    try {
      File file;
      if (_downloadedFile != null && await _downloadedFile!.exists()) {
        file = _downloadedFile!;
      } else {
        file = await widget.updater.downloadAndVerify(
          widget.release,
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
        );
        _downloadedFile = file;
      }

      if (!mounted) return;
      setState(() {
        _progress = ApkDownloadProgress(
          receivedBytes: widget.release.apkSizeBytes ?? 1,
          totalBytes: widget.release.apkSizeBytes ?? 1,
          stage: 'installing',
        );
      });

      final outcome = await widget.updater.installApk(file.path);
      if (!mounted) return;

      if (outcome == ApkInstallOutcome.permissionRequired) {
        setState(() {
          _busy = false;
          _needsInstallPermission = true;
        });
      } else if (outcome == ApkInstallOutcome.launched) {
        setState(() => _busy = false);
        widget.onToast('Opening Android installer…');
      } else {
        setState(() {
          _busy = false;
          _error = 'Direct APK install is only supported on Android devices.';
        });
      }
    } on ApkUpdateException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Update failed: $e';
        });
      }
    }
  }

  Future<void> _openGithub() async {
    final uri = Uri.tryParse(widget.release.releaseUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.slate;
    final r = widget.release;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final sizeStr =
        r.apkSizeBytes != null ? _formatBytes(r.apkSizeBytes!) : null;

    return Container(
      decoration: BoxDecoration(
        color: c.overlay,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: c.lineStrong)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 18 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.lineStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  r.hasUpdate ? 'Update available' : 'TernaryCode Mobile',
                  style: SlateTypography.title(c, size: 16),
                ),
              ),
              SlateTag(
                label: r.hasUpdate
                    ? 'v${r.currentVersion} -> v${r.latestVersion}'
                    : 'v${r.currentVersion}',
                fg: r.hasUpdate ? c.accentText : c.done,
                bg: r.hasUpdate ? c.accentTint : c.doneTint,
              ),
              const SizedBox(width: 8),
              SlateIconButton(
                icon: PhosphorIconsRegular.x,
                small: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          SlateCard(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      r.hasUpdate
                          ? PhosphorIconsRegular.arrowCircleDown
                          : PhosphorIconsFill.checkCircle,
                      size: 16,
                      color: r.hasUpdate ? c.accentText : c.done,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.hasUpdate
                            ? (r.assetName ?? 'v${r.latestVersion} APK')
                            : (r.statusMessage ??
                                'You are on the latest release'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SlateTypography.body(c, weight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  [
                    ?r.matchedAbi,
                    ?sizeStr,
                    if (r.checksumsUrl != null) 'SHA-256 verified',
                  ].join(' · '),
                  style: SlateTypography.data(c),
                ),
                if (r.releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 140),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: c.inset,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.lineSubtle),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        r.releaseNotes,
                        style: SlateTypography.body2(c),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (_progress != null) ...[
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      _progress!.stage == 'verifying'
                          ? 'Verifying SHA-256 signature…'
                          : _progress!.stage == 'installing'
                              ? 'Launching Android installer…'
                              : 'Downloading APK…',
                      style: SlateTypography.data(c, color: c.text2),
                    ),
                    const Spacer(),
                    if (_progress!.fraction != null)
                      Text(
                        '${(_progress!.fraction! * 100).round()}% · ${_formatBytes(_progress!.receivedBytes)}',
                        style: SlateTypography.data(c, color: c.accentText),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: _progress!.stage == 'downloading'
                        ? _progress!.fraction
                        : null,
                    minHeight: 5,
                    backgroundColor: c.active,
                    color: c.accent,
                  ),
                ),
              ],
            ),
          ],

          if (_needsInstallPermission) ...[
            const SizedBox(height: 12),
            SlateNotice(
              status: 'needs_input',
              leading: Icon(PhosphorIconsRegular.shieldCheck,
                  size: 16, color: c.input),
              title: 'Allow installs from TernaryCode',
              body:
                  'Enable "Install unknown apps" in the Android Settings screen that opened, then tap Install APK below.',
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 12),
            SlateNotice(
              status: 'failed',
              leading: Icon(PhosphorIconsFill.xCircle, size: 16, color: c.failed),
              title: 'Update error',
              body: _error!,
            ),
          ],

          const SizedBox(height: 14),
          if (r.hasUpdate && r.apkDownloadUrl != null) ...[
            SlateButton(
              label: _downloadedFile != null
                  ? 'Install v${r.latestVersion} APK'
                  : 'Download & Install v${r.latestVersion}',
              icon: PhosphorIconsRegular.downloadSimple,
              variant: SlateButtonVariant.primary,
              expanded: true,
              busy: _busy,
              onPressed: _downloadAndInstall,
            ),
            const SizedBox(height: 8),
          ],
          SlateButton(
            label: 'View release on GitHub',
            icon: PhosphorIconsRegular.arrowSquareOut,
            variant: SlateButtonVariant.secondary,
            height: 40,
            expanded: true,
            onPressed: _openGithub,
          ),
        ],
      ),
    );
  }
}
