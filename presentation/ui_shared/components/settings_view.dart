import 'package:flutter/material.dart';

import '../forms/dns_settings_form.dart';
import '../forms/routing_settings_form.dart';
import '../forms/tun_settings_form.dart';

/// Tabbed container for the app-global settings forms (routing, DNS, TUN/OS).
/// Per-profile TLS tricks live in the profile editor, not here.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Routing'),
              Tab(text: 'DNS'),
              Tab(text: 'TUN / OS'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                RoutingSettingsForm(),
                DnsSettingsForm(),
                TunSettingsForm(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
