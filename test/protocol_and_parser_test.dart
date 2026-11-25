import 'package:flutter_test/flutter_test.dart';
import 'package:ternarycode_mobile/models/companion_models.dart';
import 'package:ternarycode_mobile/models/host_models.dart';
import 'package:ternarycode_mobile/services/ansi_parser.dart';
import 'package:ternarycode_mobile/theme/slate_tokens.dart';

void main() {
  group('ParsedPairingQr', () {
    test('parses LAN HTTP pairing URL from desktop QR', () {
      final parsed = ParsedPairingQr.tryParse(
        'http://192.168.1.5:7890/?pair=k7m9-p2x4-q8r2',
      );
      expect(parsed, isNotNull);
      expect(parsed!.baseUrl, 'http://192.168.1.5:7890');
      expect(parsed.code, 'K7M9-P2X4-Q8R2');
      expect(parsed.hostLabel, '192.168.1.5:7890');
    });

    test('parses Cloudflare HTTPS tunnel pairing URL', () {
      final parsed = ParsedPairingQr.tryParse(
        'https://tc.ilham.dev/?pair=ABCD-EFGH-2345',
      );
      expect(parsed, isNotNull);
      expect(parsed!.baseUrl, 'https://tc.ilham.dev');
      expect(parsed.code, 'ABCD-EFGH-2345');
    });

    test('parses custom ternarycode:// deep link', () {
      final parsed = ParsedPairingQr.tryParse(
        'ternarycode://pair?url=http://100.84.12.9:7890&token=WXYZ-1234',
      );
      expect(parsed, isNotNull);
      expect(parsed!.baseUrl, 'http://100.84.12.9:7890');
      expect(parsed.code, 'WXYZ-1234');
    });

    test('rejects invalid or missing code URLs', () {
      expect(ParsedPairingQr.tryParse(''), isNull);
      expect(ParsedPairingQr.tryParse('not-a-url'), isNull);
      expect(ParsedPairingQr.tryParse('http://192.168.1.5:7890/'), isNull);
      expect(ParsedPairingQr.tryParse('http://192.168.1.5:7890/?pair=ab'), isNull);
    });
  });

  group('PairedHost transport inference', () {
    test('detects Wi-Fi LAN, Tailscale, Cloudflare, and ngrok', () {
      expect(PairedHost.inferTransport('http://192.168.1.5:7890'), 'Wi-Fi LAN');
      expect(PairedHost.inferTransport('http://100.84.12.9:7890'), 'Tailscale');
      expect(PairedHost.inferTransport('https://mac.tail123.ts.net'), 'Tailscale');
      expect(PairedHost.inferTransport('https://tc.ilham.dev'), 'Cloudflare');
      expect(PairedHost.inferTransport('https://abc.ngrok-free.app'), 'ngrok');
    });
  });

  group('CompanionSnapshot & failover prioritization', () {
    test('deserializes exact desktop CompanionSnapshot JSON', () {
      final snap = CompanionSnapshot.fromJson({
        'host_os': 'Mac',
        'failover_mode': 'auto',
        'projects': [
          {
            'id': 1,
            'name': 'storefront',
            'branch': 'main',
            'sessions': [
              {
                'id': 'sess-1',
                'title': 'Fix OAuth loop',
                'agent': 'claude',
                'profile': 'claude1',
                'status': 'needs_input',
                'age': 'live',
                'live_pane': 7,
              }
            ],
          }
        ],
        'panes': [
          {
            'id': 7,
            'project_id': 1,
            'project_name': 'storefront',
            'label': 'Claude Code',
            'branch': 'main',
            'provider': 'Claude Code',
            'profile': 'claude1',
            'supports_profiles': true,
            'status': 'rate_limited',
            'status_label': 'Rate limited',
            'message': '5h limit',
            'output': 'hello',
            'rate_limit': {
              'from_profile': 'claude1',
              'reason': '5-hour limit reached',
              'resets_at_unix': 2000000000,
            },
          }
        ],
        'profiles': [
          {
            'id': 'codex1',
            'name': 'codex1',
            'provider': 'ChatGPT / Codex',
            'state': 'idle',
            'enabled': true,
            'tokens_in': 1000,
            'tokens_out': 500,
          },
          {
            'id': 'claude1',
            'name': 'claude1',
            'provider': 'Claude Code',
            'state': 'rate_limited',
            'enabled': true,
            'tokens_in': 1000000,
            'tokens_out': 400000,
          },
          {
            'id': 'claude2',
            'name': 'claude2',
            'provider': 'Claude Code',
            'state': 'idle',
            'enabled': true,
            'tokens_in': 50000,
            'tokens_out': 20000,
            'window_5h': {
              'label': '5h window',
              'used_pct': 12.0,
              'tokens': 70000,
              'resets_at_unix': 2000005000,
            },
          },
        ],
        'alerts': [
          {
            'time': '09:41:00',
            'level': 'info',
            'profile': 'claude2',
            'message': 'Ready',
          }
        ],
      });

      expect(snap.hostOs, 'Mac');
      expect(snap.failoverMode, 'auto');
      expect(snap.panes.length, 1);
      expect(snap.waitingCount, 1);
      expect(snap.healthyProfileCount, 2);

      // Same-provider replacement (claude2) must be prioritized over codex1!
      final healthy = snap.healthyProfilesFor(snap.panes.first);
      expect(healthy.map((p) => p.id).toList(), ['claude2', 'codex1']);
    });

    test('formats tokens and countdowns cleanly', () {
      expect(formatTokens(950), '950');
      expect(formatTokens(210000), '210k');
      expect(formatTokens(1400000), '1.4M');
      expect(formatResetCountdown(1000 + 840, nowUnix: 1000), '14m');
      expect(formatResetCountdown(1000 + 3600 * 4 + 120, nowUnix: 1000), '4h 02m');
      expect(formatResetCountdown(1000 + 86400 * 2 + 3600 * 6, nowUnix: 1000), '2d 6h');
    });
  });

  group('AnsiTerminalParser', () {
    test('parses ANSI SGR colors and diff tint rows', () {
      const sample = '\x1B[32mPASS\x1B[0m auth_test\n'
          '  39 -   return redirect(old)\n'
          '  39 +   return redirect(safe)\n'
          '⏺ Update(src/auth.ts)';
      final lines = AnsiTerminalParser.parse(sample, SlateColors.dark);
      expect(lines.length, 4);

      expect(lines[0].spans.first.text, 'PASS');
      expect(lines[0].spans.first.style?.color, SlateColors.dark.termGreen);
      expect(lines[1].background, SlateColors.dark.diffDel);
      expect(lines[2].background, SlateColors.dark.diffAdd);
      expect(lines[3].spans.first.style?.color, SlateColors.dark.claude);
    });
  });
}
