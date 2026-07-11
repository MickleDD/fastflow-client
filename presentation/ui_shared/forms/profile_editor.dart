import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/enums/flow_type.dart';
import '../../../core/domain/models/proxy_profile.dart';
import '../../../core/parsing/vless_parser.dart';
import '../../state/profile_list_mgr.dart';
import 'tls_tricks_form.dart';

/// Create/edit a [ProxyProfile]. The main view asks only for the essentials
/// (name, server, port, protocol, credential) and offers a one-tap
/// "Import from Clipboard" that fills the form from a `vless://` link. Every
/// power-user knob — transport, Vision flow, MUX, and the [TlsTricksForm] — is
/// tucked inside a collapsed "Advanced Settings" section. Text lives in
/// controllers; enums/nested config in a working draft.
class ProfileEditor extends ConsumerStatefulWidget {
  final ProxyProfile? existing;

  const ProfileEditor({super.key, this.existing});

  @override
  ConsumerState<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends ConsumerState<ProfileEditor> {
  late ProxyProfile _draft;
  late final TextEditingController _name;
  late final TextEditingController _server;
  late final TextEditingController _port;
  late final TextEditingController _uuid;
  late final TextEditingController _password;
  late final TextEditingController _path;
  late final TextEditingController _host;
  late final TextEditingController _serviceName;
  late final TextEditingController _obfs;

  @override
  void initState() {
    super.initState();
    _draft = widget.existing ??
        ProxyProfile(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: '',
          serverAddress: '',
          port: 443,
          protocol: ProxyProtocol.vless,
          uuid: '',
        );
    _name = TextEditingController(text: _draft.name);
    _server = TextEditingController(text: _draft.serverAddress);
    _port = TextEditingController(text: _draft.port.toString());
    _uuid = TextEditingController(text: _draft.uuid);
    _password = TextEditingController(text: _draft.password);
    _path = TextEditingController(text: _draft.transport.path);
    _host = TextEditingController(text: _draft.transport.host);
    _serviceName = TextEditingController(text: _draft.transport.serviceName);
    _obfs = TextEditingController(text: _draft.hysteriaObfsPassword);
  }

  @override
  void dispose() {
    for (final c in [
      _name, _server, _port, _uuid, _password,
      _path, _host, _serviceName, _obfs,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final profile = _draft.copyWith(
      name: _name.text.trim().isEmpty ? 'Unnamed' : _name.text.trim(),
      serverAddress: _server.text.trim(),
      port: int.tryParse(_port.text) ?? 443,
      uuid: _uuid.text.trim(),
      password: _password.text,
      hysteriaObfsPassword: _obfs.text,
      transport: _draft.transport.copyWith(
        path: _path.text,
        host: _host.text,
        serviceName: _serviceName.text,
      ),
    );
    ref.read(profileListControllerProvider).save(profile);
    Navigator.of(context).maybePop(profile);
  }

  /// Reads a `vless://` link from the clipboard and pre-fills the whole form.
  Future<void> _importFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final text = data?.text?.trim() ?? '';

    if (text.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Clipboard is empty')),
      );
      return;
    }

    final parsed = VlessParser.tryParse(text);
    if (parsed == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No valid vless:// link on the clipboard')),
      );
      return;
    }

    // Keep this profile's identity; adopt everything else from the link.
    _applyProfile(parsed.copyWith(id: _draft.id));
    messenger.showSnackBar(
      const SnackBar(content: Text('Imported from clipboard')),
    );
  }

  /// Replaces the working draft and re-syncs every text controller.
  void _applyProfile(ProxyProfile p) {
    setState(() {
      _draft = p;
      _name.text = p.name;
      _server.text = p.serverAddress;
      _port.text = p.port.toString();
      _uuid.text = p.uuid;
      _password.text = p.password;
      _path.text = p.transport.path;
      _host.text = p.transport.host;
      _serviceName.text = p.transport.serviceName;
      _obfs.text = p.hysteriaObfsPassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isVless = _draft.protocol == ProxyProtocol.vless;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New profile' : 'Edit profile'),
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.save)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // One-tap setup: paste a vless:// link and auto-fill everything.
          OutlinedButton.icon(
            onPressed: _importFromClipboard,
            icon: const Icon(Icons.content_paste_go_outlined),
            label: const Text('Import from Clipboard'),
          ),
          const SizedBox(height: 12),

          // ---- Essentials: the bare minimum a user must provide ------------
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: _server,
            decoration: const InputDecoration(labelText: 'Server address'),
          ),
          TextField(
            controller: _port,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Port'),
          ),
          const SizedBox(height: 8),
          _protocolDropdown(),
          if (isVless)
            TextField(
              controller: _uuid,
              decoration: const InputDecoration(labelText: 'UUID'),
            )
          else
            TextField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Password'),
            ),

          // ---- Everything technical, collapsed away by default -------------
          const SizedBox(height: 12),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              leading: const Icon(Icons.tune),
              title: const Text('Advanced Settings'),
              subtitle:
                  const Text('Transport, MUX, TLS tricks — optional'),
              children: [
                if (isVless) ..._vlessAdvanced() else ..._hysteria2Advanced(),
                const Divider(),
                Text('TLS', style: Theme.of(context).textTheme.titleMedium),
                TlsTricksForm(
                  value: _draft.tls,
                  onChanged: (tls) =>
                      setState(() => _draft = _draft.copyWith(tls: tls)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _protocolDropdown() => ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Protocol'),
        trailing: DropdownButton<ProxyProtocol>(
          value: _draft.protocol,
          onChanged: (v) {
            if (v != null) setState(() => _draft = _draft.copyWith(protocol: v));
          },
          items: ProxyProtocol.values
              .map((p) =>
                  DropdownMenuItem(value: p, child: Text(p.value.toUpperCase())))
              .toList(),
        ),
      );

  /// VLESS knobs that non-technical users rarely touch — flow, transport and
  /// multiplexing. Lives inside "Advanced Settings"; UUID stays up top.
  List<Widget> _vlessAdvanced() => [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Flow'),
          trailing: DropdownButton<FlowType>(
            value: _draft.flow,
            onChanged: (v) {
              if (v != null) setState(() => _draft = _draft.copyWith(flow: v));
            },
            items: FlowType.values
                .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
                .toList(),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Transport'),
          trailing: DropdownButton<TransportType>(
            value: _draft.transport.type,
            onChanged: (v) {
              if (v != null) {
                setState(() => _draft = _draft.copyWith(
                    transport: _draft.transport.copyWith(type: v)));
              }
            },
            items: TransportType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                .toList(),
          ),
        ),
        // Transport-specific fields.
        if (_draft.transport.type == TransportType.ws ||
            _draft.transport.type == TransportType.http ||
            _draft.transport.type == TransportType.httpUpgrade) ...[
          TextField(
            controller: _path,
            decoration: const InputDecoration(labelText: 'Path'),
          ),
          TextField(
            controller: _host,
            decoration: const InputDecoration(labelText: 'Host header'),
          ),
        ],
        if (_draft.transport.type == TransportType.grpc)
          TextField(
            controller: _serviceName,
            decoration: const InputDecoration(labelText: 'gRPC service name'),
          ),
        const Divider(),
        // MUX.
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Multiplex (MUX)'),
          subtitle: const Text('Disabled automatically with Vision flow'),
          value: _draft.mux.enabled,
          onChanged: (v) => setState(
              () => _draft = _draft.copyWith(mux: _draft.mux.copyWith(enabled: v))),
        ),
        if (_draft.mux.enabled)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('MUX protocol'),
            trailing: DropdownButton<MuxProtocol>(
              value: _draft.mux.protocol,
              onChanged: (v) {
                if (v != null) {
                  setState(() => _draft =
                      _draft.copyWith(mux: _draft.mux.copyWith(protocol: v)));
                }
              },
              items: MuxProtocol.values
                  .map((m) =>
                      DropdownMenuItem(value: m, child: Text(m.value)))
                  .toList(),
            ),
          ),
      ];

  /// Hysteria2 tuning — obfuscation and bandwidth hints. Password stays up top.
  List<Widget> _hysteria2Advanced() => [
        TextField(
          controller: _obfs,
          decoration: const InputDecoration(
            labelText: 'Obfs (salamander) password — empty to disable',
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _BandwidthField(
                label: 'Up (Mbps)',
                value: _draft.hysteriaUpMbps,
                onChanged: (v) => setState(
                    () => _draft = _draft.copyWith(hysteriaUpMbps: v)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BandwidthField(
                label: 'Down (Mbps)',
                value: _draft.hysteriaDownMbps,
                onChanged: (v) => setState(
                    () => _draft = _draft.copyWith(hysteriaDownMbps: v)),
              ),
            ),
          ],
        ),
      ];
}

class _BandwidthField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _BandwidthField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        initialValue: value.toString(),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label),
        onChanged: (v) {
          final parsed = int.tryParse(v);
          if (parsed != null) onChanged(parsed);
        },
      );
}
