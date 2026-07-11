import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/models/dns_config.dart';
import '../../state/settings_mgr.dart';

/// App-global DNS settings: remote/direct resolvers, Fake-DNS, and the domain
/// resolution strategy. Reads and writes [settingsProvider].
class DnsSettingsForm extends ConsumerWidget {
  const DnsSettingsForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dns = ref.watch(settingsProvider).dns;
    final notifier = ref.read(settingsProvider.notifier);

    void updateDns(DnsConfig next) =>
        notifier.patch((s) => s.copyWith(dns: next));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextFormField(
          initialValue: dns.remoteDns,
          decoration: const InputDecoration(
            labelText: 'Remote DNS',
            hintText: 'https://1.1.1.1/dns-query',
          ),
          onChanged: (v) => updateDns(dns.copyWith(remoteDns: v)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: dns.directDns,
          decoration: const InputDecoration(
            labelText: 'Direct DNS',
            hintText: 'local / 223.5.5.5',
          ),
          onChanged: (v) => updateDns(dns.copyWith(directDns: v)),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Enable Fake DNS'),
          subtitle: const Text('Hand out synthetic IPs; prevents pre-tunnel leaks'),
          value: dns.enableFakeDns,
          onChanged: (v) => updateDns(dns.copyWith(enableFakeDns: v)),
        ),
        SwitchListTile(
          title: const Text('Independent cache'),
          subtitle: const Text('Separate cache per resolver'),
          value: dns.independentCache,
          onChanged: (v) => updateDns(dns.copyWith(independentCache: v)),
        ),
        const Divider(),
        ListTile(
          title: const Text('Domain routing strategy'),
          trailing: DropdownButton<DnsDomainStrategy>(
            value: dns.domainStrategy,
            onChanged: (v) {
              if (v != null) updateDns(dns.copyWith(domainStrategy: v));
            },
            items: DnsDomainStrategy.values
                .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                .toList(),
          ),
        ),
      ],
    );
  }
}
