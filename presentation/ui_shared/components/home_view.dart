import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/models/connection_state.dart';
import '../../../core/domain/models/proxy_profile.dart';
import '../../state/connection_state_mgr.dart';
import '../../state/profile_list_mgr.dart';
import '../forms/profile_editor.dart';
import 'protocol_badge.dart';

/// Shared home content: live connection status header + the selectable profile
/// list. The enclosing platform layout supplies the scaffold and the FAB.
class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profileListProvider);

    return Column(
      children: [
        const _StatusHeader(),
        Expanded(
          child: profiles.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load profiles: $e')),
            data: (list) => list.isEmpty
                ? _EmptyState(onAdd: () => _openEditor(context))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) => _ProfileTile(profile: list[i]),
                  ),
          ),
        ),
      ],
    );
  }

  static void _openEditor(BuildContext context, {ProxyProfile? existing}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileEditor(existing: existing)),
    );
  }
}

class _StatusHeader extends ConsumerWidget {
  const _StatusHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = ref.watch(connectionProvider);
    final scheme = Theme.of(context).colorScheme;

    final color = switch (conn.status) {
      ConnectionStatus.connected => Colors.green,
      ConnectionStatus.error => scheme.error,
      ConnectionStatus.connecting ||
      ConnectionStatus.disconnecting =>
        Colors.orange,
      ConnectionStatus.disconnected => scheme.outline,
    };

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 12, color: color),
                const SizedBox(width: 8),
                Text(
                  conn.status.name.toUpperCase(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            if (conn.message != null) ...[
              const SizedBox(height: 6),
              Text(conn.message!, style: TextStyle(color: scheme.error)),
            ],
            if (conn.isConnected) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Metric(label: '↑', value: _fmtRate(conn.uploadRate)),
                  _Metric(label: '↓', value: _fmtRate(conn.downloadRate)),
                  _Metric(label: 'Total ↑', value: _fmtBytes(conn.uploadBytes)),
                  _Metric(label: 'Total ↓', value: _fmtBytes(conn.downloadBytes)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _fmtRate(int bps) => '${_fmtBytes(bps)}/s';

  static String _fmtBytes(int b) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double v = b.toDouble();
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      );
}

class _ProfileTile extends ConsumerWidget {
  final ProxyProfile profile;
  const _ProfileTile({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedProfileIdProvider);
    final selected = ref.watch(selectedProfileProvider)?.id == profile.id;

    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(profile.name),
      subtitle: Text('${profile.serverAddress}:${profile.port}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProtocolBadge(profile: profile),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') {
                HomeView._openEditor(context, existing: profile);
              } else if (v == 'delete') {
                ref.read(profileListControllerProvider).delete(profile.id);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      selected: selected && selectedId != null,
      onTap: () =>
          ref.read(selectedProfileIdProvider.notifier).state = profile.id,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No profiles yet'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add profile'),
            ),
          ],
        ),
      );
}
