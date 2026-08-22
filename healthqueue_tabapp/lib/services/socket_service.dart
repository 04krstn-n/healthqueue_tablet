import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../config/api_config.dart';
import '../core/network/api_client.dart';

/// Wraps the Socket.io connection to the hq-server for live queue updates.
/// The server mounts Socket.io on the same HTTP server as the REST API
/// (see server.js) and expects a `join_clinic` event with the clinic's id
/// to receive that clinic's queue broadcasts.
///
/// Note: the server does NOT emit a single generic `queue_updated` event.
/// Each mutation in queueController.js emits its own event name to the
/// `clinic_<id>` room — queue_entry_added, patient_called, service_started,
/// queue_completed, patient_skipped, patient_noshow, queue_cancelled,
/// walkin_added — and also broadcasts `global_queue_change` to everyone.
/// We listen for all of them and treat any as "something changed, refresh".
class ClinicSocketService {
  static const _queueEventNames = [
    'queue_entry_added',
    'patient_called',
    'service_started',
    'queue_completed',
    'patient_skipped',
    'patient_noshow',
    'queue_cancelled',
    'walkin_added',
    'queue_requeued',
    'global_queue_change',
  ];

  IO.Socket? _socket;

  /// Connects and joins the given clinic's room. [onQueueUpdated] is called
  /// with the event payload whenever the server emits any queue-change
  /// event — typically used to trigger a provider refresh.
  ///
  /// [eventNames] lets other providers (e.g. inquiries) reuse this same
  /// socket wrapper to listen for a different set of server-emitted events
  /// instead of the queue-specific ones.
  Future<void> connect(
    String clinicId, {
    void Function(dynamic data)? onQueueUpdated,
    void Function()? onConnected,
    void Function()? onDisconnected,
    List<String>? eventNames,
  }) async {
    final token = await ApiClient.instance.getToken();

    _socket = IO.io(
      ApiConfig.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    _socket!.onConnect((_) {
      _socket!.emit('join_clinic', clinicId);
      onConnected?.call();
    });

    for (final event in (eventNames ?? _queueEventNames)) {
      _socket!.on(event, (data) => onQueueUpdated?.call(data));
    }

    _socket!
      ..onDisconnect((_) => onDisconnected?.call())
      ..connect();
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
