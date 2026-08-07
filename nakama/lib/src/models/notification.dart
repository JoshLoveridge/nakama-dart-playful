import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nakama/src/api/api.dart' as api;

part 'notification.freezed.dart';
part 'notification.g.dart';

@freezed
class Notification with _$Notification {
  const Notification._();

  const factory Notification({
    @JsonKey(name: 'id') required String id,
    @JsonKey(name: 'subject') String? subject,
    @JsonKey(name: 'content') String? content,
    @JsonKey(name: 'code') required int code,
    @JsonKey(name: 'sender_id') required String senderId,
    @JsonKey(name: 'create_time') required DateTime createTime,
    @JsonKey(name: 'persistent') required bool persistent,
  }) = _Notification;

  /// Nakama's REST layer is a grpc-gateway emitting proto3 JSON, which OMITS
  /// default-valued fields. Server-sent notifications carry no sender — Nakama's own
  /// documented API takes `senderID := ""` for them — so `sender_id` is absent from the
  /// response entirely, and the generated `json['sender_id'] as String` cast a null.
  ///
  /// That failure was not per-row: it threw out of `NotificationList.fromJson`, losing
  /// every notification in the response rather than the one lacking a sender. It is also
  /// a `TypeError` (an `Error`, not an `Exception`), so `NakamaRestApiClient`'s own
  /// `on Exception catch` did not catch it either.
  ///
  /// Defaulted to '' rather than made nullable so `senderId` stays a non-nullable String
  /// for callers: [Notification.fromDto] already supplies '' from the protobuf in exactly
  /// this case, so '' is the value the socket path has always carried.
  ///
  /// Patched here in the factory rather than as a `@Default` on the constructor so no
  /// code generation is required — this package's committed generated code was built with
  /// freezed 2 while its pubspec now allows freezed 3, so regenerating rewrites the whole
  /// package. Doing it this way also means the fix survives a future regeneration.
  factory Notification.fromJson(Map<String, Object?> json) => _$NotificationFromJson({
        ...json,
        'sender_id': json['sender_id'] ?? '',
      });

  factory Notification.fromDto(api.Notification dto) => Notification(
        id: dto.id,
        code: dto.code,
        content: dto.content,
        subject: dto.subject,
        senderId: dto.senderId,
        createTime: dto.createTime.toDateTime(),
        persistent: dto.persistent,
      );
}

@freezed
class NotificationList with _$NotificationList {
  const NotificationList._();

  const factory NotificationList({
    @JsonKey(name: 'cacheable_cursor') String? cursor,
    @JsonKey(name: 'notifications') required List<Notification> notifications,
  }) = _NotificationList;

  /// Same proto3 omission as [Notification.fromJson]: an empty repeated field is left out
  /// of the response, so a user with no notifications gets no `notifications` key at all
  /// and the generated `as List<dynamic>` cast a null. That made `listNotifications()`
  /// throw for every user with an empty inbox — most users, most of the time.
  ///
  /// Upstream has since made this same field defaulted on main (unreleased as of 1.3.0);
  /// this is that fix, applied in the factory so it needs no regeneration.
  factory NotificationList.fromJson(Map<String, Object?> json) => _$NotificationListFromJson({
        ...json,
        'notifications': json['notifications'] ?? const <Object?>[],
      });

  factory NotificationList.fromDto(api.NotificationList dto) => NotificationList(
        cursor: dto.cacheableCursor,
        notifications: dto.notifications.map((e) => Notification.fromDto(e)).toList(growable: false),
      );
}
