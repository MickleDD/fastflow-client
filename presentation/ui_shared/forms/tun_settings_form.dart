import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/enums/tun_mode.dart';
import '../../../core/domain/models/local_proxy_config.dart';
import '../../../core/security/secret_generator.dart';
import '../../state/providers.dart';
import '../../state/settings_mgr.dart';

/// TUN + OS-integration settings: TUN stack, the optional authenticated local
/// proxy (loopback tooling / LAN sharing), and the OS features (kill switch,
/// auto-connect on insecure Wi-Fi, Windows no-admin fallback). The kill switch
/// is routed through its use-case so it applies live when a tunnel is already
/// up.
///
/// There are deliberately no editable listener ports here for the core inbounds
/// — those are ephemeral per connection. Only the authenticated local proxy may
/// pin a port (0 = random each session).
class TunSettingsForm extends ConsumerWidget {
  const TunSettingsForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final proxy = settings.localProxy;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          title: const Text('TUN mode'),
          trailing: DropdownButton<TunMode>(
            value: settings.tunMode,
            onChanged: (v) {
              if (v != null) notifier.patch((s) => s.copyWith(tunMode: v));
            },
            items: TunMode.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                .toList(),
          ),
        ),
        const Divider(),
        Text('Local proxy', style: Theme.of(context).textTheme.titleSmall),
        SwitchListTile(
          title: const Text('Local proxy for other apps'),
          subtitle: const Text(
              'Authenticated SOCKS5/HTTP proxy on this device. Off by default: '
              'an open local proxy lets other apps bypass VPN routing.'),
          value: proxy.enabled,
          onChanged: (v) => notifier.patch(
            (s) => s.copyWith(
              localProxy: v
                  ? _withCredentials(proxy)
                      .copyWith(mode: LocalProxyMode.loopback)
                  : proxy.copyWith(mode: LocalProxyMode.disabled),
            ),
          ),
        ),
        if (proxy.enabled) ...[
          SwitchListTile(
            title: const Text('Share on local network'),
            subtitle: const Text(
                'Reachable by every device on the network — credentials '
                'below are required to connect'),
            value: proxy.mode == LocalProxyMode.lan,
            onChanged: (v) => notifier.patch(
              (s) => s.copyWith(
                localProxy: _withCredentials(proxy).copyWith(
                  mode: v ? LocalProxyMode.lan : LocalProxyMode.loopback,
                ),
              ),
            ),
          ),
          _PortField(
            label: 'Proxy port (0 = random each session)',
            value: proxy.pinnedPort,
            onChanged: (v) => notifier.patch(
              (s) => s.copyWith(localProxy: proxy.copyWith(pinnedPort: v)),
            ),
          ),
          if (!proxy.hasCredentials)
            ListTile(
              leading: const Icon(Icons.warning_amber_rounded),
              title: const Text('Credentials required'),
              subtitle: const Text(
                  'The proxy stays offline until credentials are generated'),
              trailing: FilledButton(
                onPressed: () => notifier.patch(
                  (s) => s.copyWith(localProxy: _withCredentials(proxy)),
                ),
                child: const Text('Generate'),
              ),
            )
          else
            ListTile(
              title: const Text('Proxy credentials'),
              subtitle: SelectableText(
                  '${proxy.username} / ${proxy.password}'),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Rotate credentials',
                onPressed: () => notifier.patch(
                  (s) => s.copyWith(
                    localProxy: proxy.copyWith(
                      username: SecretGenerator.username(),
                      password: SecretGenerator.password(),
                    ),
                  ),
                ),
              ),
            ),
        ],
        const Divider(),
        Text('OS integration', style: Theme.of(context).textTheme.titleSmall),
        SwitchListTile(
          title: const Text('Kill switch'),
          subtitle: const Text('Block all non-VPN traffic'),
          value: settings.killSwitch,
          onChanged: (v) async {
            final updated =
                await ref.read(toggleKillSwitchUseCaseProvider).execute(v);
            notifier.adopt(updated);
          },
        ),
        SwitchListTile(
          title: const Text('Auto-connect on insecure Wi-Fi'),
          subtitle: const Text('Connect automatically on open hotspots'),
          value: settings.autoConnectInsecureWifi,
          onChanged: (v) =>
              notifier.patch((s) => s.copyWith(autoConnectInsecureWifi: v)),
        ),
        if (Platform.isWindows)
          SwitchListTile(
            title: const Text('No-admin fallback (system proxy)'),
            subtitle: const Text(
                'When not elevated, use the Windows system proxy instead of TUN'),
            value: settings.windowsNoAdminFallback,
            onChanged: (v) =>
                notifier.patch((s) => s.copyWith(windowsNoAdminFallback: v)),
          ),
        SwitchListTile(
          title: const Text('External control API (debug)'),
          subtitle: const Text(
              'Clash API on 127.0.0.1, random port, new access token every '
              'connection. Leave off unless debugging.'),
          value: settings.debugApiEnabled,
          onChanged: (v) =>
              notifier.patch((s) => s.copyWith(debugApiEnabled: v)),
        ),
      ],
    );
  }

  /// Ensure the config carries credentials before any enabled mode is stored;
  /// existing credentials are kept so tooling configs stay valid.
  static LocalProxyConfig _withCredentials(LocalProxyConfig p) {
    if (p.hasCredentials) return p;
    return p.copyWith(
      username: SecretGenerator.username(),
      password: SecretGenerator.password(),
    );
  }
}

class _PortField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _PortField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        initialValue: value.toString(),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          helperText: '0 for a random port, or 1024–65535',
        ),
        onChanged: (v) {
          final parsed = int.tryParse(v);
          // 0 = ephemeral; otherwise unprivileged ports only.
          if (parsed != null &&
              (parsed == 0 || (parsed >= 1024 && parsed <= 65535))) {
            onChanged(parsed);
          }
        },
      ),
    );
  }
}
