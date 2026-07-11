import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/models/routing_config.dart';
import '../../state/settings_mgr.dart';

/// App-global routing: balancer strategy, IPv6 mode, and the strict / ad-block /
/// bypass-LAN / sniffing toggles.
class RoutingSettingsForm extends ConsumerWidget {
  const RoutingSettingsForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routing = ref.watch(settingsProvider).routing;
    final notifier = ref.read(settingsProvider.notifier);

    void updateRouting(RoutingConfig next) =>
        notifier.patch((s) => s.copyWith(routing: next));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          title: const Text('Balancer strategy'),
          trailing: DropdownButton<BalancerStrategy>(
            value: routing.balancer,
            onChanged: (v) {
              if (v != null) updateRouting(routing.copyWith(balancer: v));
            },
            items: BalancerStrategy.values
                .map((b) => DropdownMenuItem(value: b, child: Text(b.label)))
                .toList(),
          ),
        ),
        ListTile(
          title: const Text('IPv6 routes'),
          trailing: DropdownButton<Ipv6Mode>(
            value: routing.ipv6Mode,
            onChanged: (v) {
              if (v != null) updateRouting(routing.copyWith(ipv6Mode: v));
            },
            items: Ipv6Mode.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                .toList(),
          ),
        ),
        const Divider(),
        SwitchListTile(
          title: const Text('Strict routing'),
          subtitle: const Text('Enforce address-family + interface binding'),
          value: routing.strictRouting,
          onChanged: (v) => updateRouting(routing.copyWith(strictRouting: v)),
        ),
        SwitchListTile(
          title: const Text('Ad blocking'),
          subtitle: const Text('Sinkhole geosite:category-ads-all'),
          value: routing.adBlock,
          onChanged: (v) => updateRouting(routing.copyWith(adBlock: v)),
        ),
        SwitchListTile(
          title: const Text('Bypass LAN'),
          subtitle: const Text('Send private/LAN ranges directly'),
          value: routing.bypassLan,
          onChanged: (v) => updateRouting(routing.copyWith(bypassLan: v)),
        ),
        SwitchListTile(
          title: const Text('Determine destination (sniffing)'),
          subtitle: const Text('Inspect first packet for the real domain'),
          value: routing.enableSniffing,
          onChanged: (v) => updateRouting(routing.copyWith(enableSniffing: v)),
        ),
      ],
    );
  }
}
