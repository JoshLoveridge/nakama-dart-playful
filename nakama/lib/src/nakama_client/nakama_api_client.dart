import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:nakama/nakama.dart';
import 'package:nakama/src/models/account.dart' as model;
import 'package:nakama/src/models/channel_message.dart' as model;
import 'package:nakama/src/models/friends.dart' as model;
import 'package:nakama/src/models/group.dart' as model;
import 'package:nakama/src/models/leaderboard.dart' as model;
import 'package:nakama/src/models/match.dart' as model;
import 'package:nakama/src/models/notification.dart' as model;
import 'package:nakama/src/models/response_error.dart';
import 'package:nakama/src/models/session.dart' as model;
import 'package:nakama/src/models/storage.dart' as model;
import 'package:nakama/src/models/tournament.dart' as model;
import 'package:nakama/src/rest/api_client.gen.dart';
import 'package:nakama/src/utils/prepare_payload.dart';

const _kDefaultAppKey = 'default';

/// Base class for communicating with Nakama via API.
/// [NakamaGrpcClient] abstracts the API calls and handles authentication
/// for you.
class NakamaRestApiClient extends NakamaBaseClient {
  static final Map<String, NakamaRestApiClient> _clients = {};

  late final ApiClient _api;

  /// The key used to authenticate with the server without a session.
  /// Defaults to "defaultkey".
  late final String serverKey;

  late final Uri apiBaseUrl;

  /// Either inits and returns a new instance of [NakamaRestApiClient] or
  /// returns a already initialized one.
  factory NakamaRestApiClient.init({
    String? host,
    String? serverKey,
    String key = _kDefaultAppKey,
    int port = 7350,
    String path = '',
    bool ssl = false,
  }) {
    if (_clients.containsKey(key)) {
      return _clients[key]!;
    }

    // Not yet initialized -> check if we've got all parameters to do so
    if (host == null || serverKey == null) {
      throw Exception(
        'Not yet initialized, need parameters [host] and [serverKey] to initialize.',
      );
    }

    // Create a new instance of this with given parameters.
    return _clients[key] = NakamaRestApiClient._(
      host: host,
      port: port,
      path: path,
      serverKey: serverKey,
      ssl: ssl,
    );
  }

  NakamaRestApiClient._({
    required String host,
    required String serverKey,
    required int port,
    required String path,
    required bool ssl,
  }) {
    apiBaseUrl =
        Uri(host: host, scheme: ssl ? 'https' : 'http', port: port, path: path);
    // Auth and refresh endpoints require the server key. Session endpoints
    // override this immutable default with their own request's Bearer token.
    // Never read shared session state from an asynchronous interceptor.
    // Auth and refresh endpoints require the server key. Session endpoints
    // override this immutable default with their own request's Bearer token.
    // Never read shared session state from an asynchronous interceptor.
    final dio = Dio(BaseOptions(
      baseUrl: apiBaseUrl.toString(),
      headers: {
        'Authorization': 'Basic ${base64Encode('$serverKey:'.codeUnits)}'
      },
    ));
    _api = ApiClient(
      dio,
      baseUrl: apiBaseUrl.toString(),
    );
  }

  /// Handles errors and returns a [ResponseError] if the error is a [DioException] and the response data is not null.
  /// Otherwise it returns the error as is.
  Exception _handleError(Exception e) {
    if (e is DioException) {
      return e.response != null ? ResponseError.fromJson(e.response!.data) : e;
    } else {
      return e;
    }
  }

  @override
  Future<model.Session> sessionRefresh({
    required model.Session session,
    Map<String, String>? vars,
  }) async {
    if (session.refreshToken == null) {
      throw Exception('Session does not have a refresh token.');
    }

    try {
      final newSession = await _api.sessionRefresh(
        body: ApiSessionRefreshRequest(
          token: session.refreshToken!,
          vars: vars,
        ),
      );
      return model.Session.fromApi(newSession);
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> sessionLogout({required model.Session session}) async {
    try {
      await _api.sessionLogout(
        bearerToken: 'Bearer ${session.token}',
        body: ApiSessionLogoutRequest(
          refreshToken: session.refreshToken!,
          token: session.token,
        ),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.Session> authenticateEmail({
    String? email,
    String? username,
    required String password,
    bool create = false,
    Map<String, String>? vars,
  }) async {
    try {
      final session = await _api.authenticateEmail(
        body: ApiAccountEmail(
          email: email,
          password: password,
          vars: vars,
        ),
        username: username,
        create: create,
      );
      return model.Session.fromApi(session);
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> linkEmail({
    required model.Session session,
    required String email,
    required String password,
    Map<String, String>? vars,
  }) async {
    try {
      await _api.linkEmail(
        bearerToken: 'Bearer ${session.token}',
        body: ApiAccountEmail(
          email: email,
          password: password,
          vars: vars,
        ),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> unlinkEmail({
    required model.Session session,
    required String email,
    required String password,
    Map<String, String>? vars,
  }) async {
    try {
      await _api.unlinkEmail(
        bearerToken: 'Bearer ${session.token}',
        body: ApiAccountEmail(
          email: email,
          password: password,
          vars: vars,
        ),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.Session> authenticateDevice({
    required String deviceId,
    bool create = true,
    String? username,
    Map<String, String>? vars,
  }) async {
    try {
      final session = await _api.authenticateDevice(
        body: ApiAccountDevice(id: deviceId, vars: vars),
        create: create,
        username: username,
      );
      return model.Session.fromApi(session);
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> linkDevice({
    required model.Session session,
    required String deviceId,
    Map<String, String>? vars,
  }) async {
    try {
      await _api.linkDevice(
        bearerToken: 'Bearer ${session.token}',
        body: ApiAccountDevice(id: deviceId, vars: vars),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> unlinkDevice({
    required model.Session session,
    required String deviceId,
    Map<String, String>? vars,
  }) async {
    try {
      await _api.unlinkDevice(
        bearerToken: 'Bearer ${session.token}',
        body: ApiAccountDevice(id: deviceId, vars: vars),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.Session> authenticateFacebook({
    required String token,
    bool create = true,
    String? username,
    Map<String, String>? vars,
    bool import = false,
  }) async {
    try {
      final session = await _api.authenticateFacebook(
        body: ApiAccountFacebook(
          token: token,
          vars: vars,
        ),
        sync: import,
        create: create,
        username: username,
      );
      return model.Session.fromApi(session);
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> linkFacebook({
    required model.Session session,
    required String token,
    bool import = false,
    Map<String, String>? vars,
  }) async {
    try {
      await _api.linkFacebook(
        bearerToken: 'Bearer ${session.token}',
        body: ApiAccountFacebook(
          token: token,
          vars: vars,
        ),
        sync: import,
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> unlinkFacebook({
    required model.Session session,
    required String token,
    Map<String, String>? vars,
  }) async {
    try {
      await _api.unlinkFacebook(
        bearerToken: 'Bearer ${session.token}',
        body: ApiAccountFacebook(
          token: token,
          vars: vars,
        ),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.Session> authenticateGoogle({
    required String token,
    bool create = true,
    String? username,
    Map<String, String>? vars,
  }) async {
    try {
      final session = await _api.authenticateGoogle(
        body: ApiAccountGoogle(
          token: token,
          vars: vars,
        ),
        create: create,
        username: username,
      );
      return model.Session.fromApi(session);
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> linkGoogle({
    required model.Session session,
    required String token,
    Map<String, String>? vars,
  }) async {
    try {
      await _api.linkGoogle(
        bearerToken: 'Bearer ${session.token}',
        body: ApiAccountGoogle(
          token: token,
          vars: vars,
        ),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> unlinkGoogle({
    required model.Session session,
    required String token,
    Map<String, String>? vars,
  }) async {
    try {
      await _api.unlinkGoogle(
        bearerToken: 'Bearer ${session.token}',
        body: ApiAccountGoogle(
          token: token,
          vars: vars,
        ),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.Session> authenticateApple({
    required String token,
    bool create = true,
    String? username,
    Map<String, String>? vars,
  }) async {
    try {
      final session = await _api.authenticateApple(
        body: ApiAccountApple(
          token: token,
          vars: vars,
        ),
        create: create,
        username: username,
      );
      return model.Session.fromApi(session);
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> linkApple({
    required model.Session session,
    required String token,
    Map<String, String>? vars,
  }) async {
    try {
      await _api.linkApple(
        bearerToken: 'Bearer ${session.token}',
        body: ApiAccountApple(
          token: token,
          vars: vars,
        ),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> unlinkApple({
    required model.Session session,
    required String token,
    Map<String, String>? vars,
  }) async {
    try {
      await _api.unlinkApple(
        bearerToken: 'Bearer ${session.token}',
        body: ApiAccountApple(
          token: token,
          vars: vars,
        ),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.Session> authenticateFacebookInstantGame({
    required String signedPlayerInfo,
    bool create = true,
    String? username,
    Map<String, String>? vars,
  }) async {
    try {
      final session = await _api.authenticateFacebookInstantGame(
        body: ApiAccountFacebookInstantGame(
          signedPlayerInfo: signedPlayerInfo,
          vars: vars,
        ),
        create: create,
        username: username,
      );
      return model.Session.fromApi(session);
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> linkFacebookInstantGame({
    required model.Session session,
    required String signedPlayerInfo,
    Map<String, String>? vars,
  }) async {
    try {
      await _api.linkFacebookInstantGame(
        bearerToken: 'Bearer ${session.token}',
        body: ApiAccountFacebookInstantGame(
          signedPlayerInfo: signedPlayerInfo,
          vars: vars,
        ),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> unlinkFacebookInstantGame({
    required model.Session session,
    required String signedPlayerInfo,
    Map<String, String>? vars,
  }) async {
    try {
      await _api.unlinkFacebookInstantGame(
        bearerToken: 'Bearer ${session.token}',
        body: ApiAccountFacebookInstantGame(
          signedPlayerInfo: signedPlayerInfo,
          vars: vars,
        ),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.Session> authenticateGameCenter({
    required String playerId,
    required String bundleId,
    required int timestampSeconds,
    required String salt,
    required String signature,
    required String publicKeyUrl,
    bool create = true,
    String? username,
    Map<String, String>? vars,
  }) async {
    try {
      final session = await _api.authenticateGameCenter(
        body: ApiAccountGameCenter(
          playerId: playerId,
          bundleId: bundleId,
          timestampSeconds: timestampSeconds.toString(),
          salt: salt,
          signature: signature,
          publicKeyUrl: publicKeyUrl,
          vars: vars,
        ),
        create: create,
        username: username,
      );
      return model.Session.fromApi(session);
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> linkGameCenter({
    required model.Session session,
    required String playerId,
    required String bundleId,
    required int timestampSeconds,
    required String salt,
    required String signature,
    required String publicKeyUrl,
    Map<String, String>? vars,
  }) async {
    try {
      await _api.linkGameCenter(
        bearerToken: 'Bearer ${session.token}',
        body: ApiAccountGameCenter(
          playerId: playerId,
          bundleId: bundleId,
          timestampSeconds: timestampSeconds.toString(),
          salt: salt,
          signature: signature,
          publicKeyUrl: publicKeyUrl,
          vars: vars,
        ),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> unlinkGameCenter({
    required model.Session session,
    required String playerId,
    required String bundleId,
    required int timestampSeconds,
    required String salt,
    required String signature,
    required String publicKeyUrl,
    Map<String, String>? vars,
  }) async {
    try {
      await _api.unlinkGameCenter(
        bearerToken: 'Bearer ${session.token}',
        body: ApiAccountGameCenter(
          playerId: playerId,
          bundleId: bundleId,
          timestampSeconds: timestampSeconds.toString(),
          salt: salt,
          signature: signature,
          publicKeyUrl: publicKeyUrl,
          vars: vars,
        ),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.Session> authenticateSteam({
    required String token,
    bool create = true,
    String? username,
    Map<String, String>? vars,
    bool import = false,
  }) async {
    try {
      final session = await _api.authenticateSteam(
        body: ApiAccountSteam(token: token, vars: vars),
        create: create,
        username: username,
        sync: import,
      );
      return model.Session.fromApi(session);
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> linkSteam({
    required model.Session session,
    required String token,
    Map<String, String>? vars,
    bool import = false,
  }) async {
    try {
      await _api.linkSteam(
        bearerToken: 'Bearer ${session.token}',
        body: ApiLinkSteamRequest(
          account: ApiAccountSteam(token: token, vars: vars),
          sync: import,
        ),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> unlinkSteam({
    required model.Session session,
    required String token,
    Map<String, String>? vars,
    bool import = false,
  }) async {
    try {
      await _api.unlinkSteam(
        bearerToken: 'Bearer ${session.token}',
        body: ApiAccountSteam(token: token, vars: vars),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.Session> authenticateCustom({
    required String id,
    bool create = true,
    String? username,
    Map<String, String>? vars,
  }) async {
    try {
      final session = await _api.authenticateCustom(
        body: ApiAccountCustom(id: id, vars: vars),
        create: create,
        username: username,
      );
      return model.Session.fromApi(session);
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> linkCustom({
    required model.Session session,
    required String id,
    Map<String, String>? vars,
  }) async {
    try {
      await _api.linkCustom(
        bearerToken: 'Bearer ${session.token}',
        body: ApiAccountCustom(id: id, vars: vars),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> unlinkCustom({
    required model.Session session,
    required String id,
    Map<String, String>? vars,
  }) async {
    try {
      await _api.unlinkCustom(
        bearerToken: 'Bearer ${session.token}',
        body: ApiAccountCustom(id: id, vars: vars),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> importFacebookFriends({
    required model.Session session,
    required String token,
    bool reset = false,
    Map<String, String>? vars,
  }) async {
    try {
      await _api.importFacebookFriends(
        bearerToken: 'Bearer ${session.token}',
        body: ApiAccountFacebook(
          token: token,
          vars: vars,
        ),
        reset: reset,
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> importSteamFriends({
    required model.Session session,
    required String token,
    bool reset = false,
    Map<String, String>? vars,
  }) async {
    try {
      await _api.importSteamFriends(
        bearerToken: 'Bearer ${session.token}',
        body: ApiAccountSteam(token: token, vars: vars),
        reset: reset,
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.Account> getAccount(model.Session session) async {
    try {
      final account = await _api.getAccount(
        bearerToken: 'Bearer ${session.token}',
      );

      return model.Account.fromJson(account.toJson());
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> updateAccount({
    required model.Session session,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? langTag,
    String? location,
    String? timezone,
  }) async {
    try {
      await _api.updateAccount(
        bearerToken: 'Bearer ${session.token}',
        body: ApiUpdateAccountRequest(
          username: username,
          displayName: displayName,
          avatarUrl: avatarUrl,
          langTag: langTag,
          location: location,
          timezone: timezone,
        ),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<List<model.User>> getUsers({
    required model.Session session,
    List<String>? facebookIds,
    required List<String> ids,
    List<String>? usernames,
  }) async {
    try {
      final users = await _api.getUsers(
        bearerToken: 'Bearer ${session.token}',
        ids: ids,
        usernames: usernames ?? [],
        facebookIds: facebookIds ?? [],
      );

      return users.users
              ?.map((e) => model.User.fromJson(e.toJson()))
              .toList(growable: false) ??
          [];
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> writeStorageObjects({
    required model.Session session,
    required Iterable<model.StorageObjectWrite> objects,
  }) async {
    try {
      await _api.writeStorageObjects(
        bearerToken: 'Bearer ${session.token}',
        body: ApiWriteStorageObjectsRequest(
          objects: objects
              .map((e) => ApiWriteStorageObject(
                    collection: e.collection,
                    key: e.key,
                    permissionRead: e.permissionRead?.index ?? 1,
                    permissionWrite: e.permissionWrite?.index ?? 1,
                    value: e.value,
                    version: e.version,
                  ))
              .toList(growable: false),
        ),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.StorageObjectList> listStorageObjects({
    required model.Session session,
    required String collection,
    String? cursor,
    String? userId,
    int? limit = defaultLimit,
  }) async {
    try {
      final objects = await _api.listStorageObjects(
        bearerToken: 'Bearer ${session.token}',
        collection: collection,
        userId: userId,
        limit: limit,
        cursor: cursor,
      );

      return model.StorageObjectList.fromJson(objects.toJson());
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<List<model.StorageObject>> readStorageObjects({
    required model.Session session,
    required Iterable<model.StorageObjectId> objectIds,
  }) async {
    try {
      final objects = await _api.readStorageObjects(
        bearerToken: 'Bearer ${session.token}',
        body: ApiReadStorageObjectsRequest(
          objectIds: objectIds
              .map((e) => ApiReadStorageObjectId(
                    collection: e.collection,
                    key: e.key,
                    userId: e.userId,
                  ))
              .toList(growable: false),
        ),
      );

      return objects.objects
              ?.map((e) => model.StorageObject.fromJson(e.toJson()))
              .toList(growable: false) ??
          [];
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> deleteStorageObjects({
    required model.Session session,
    required Iterable<model.StorageObjectId> objectIds,
  }) async {
    try {
      await _api.deleteStorageObjects(
        bearerToken: 'Bearer ${session.token}',
        body: ApiDeleteStorageObjectsRequest(
          objectIds: objectIds
              .map((e) => ApiDeleteStorageObjectId(
                    collection: e.collection,
                    key: e.key,
                    version: e.version,
                  ))
              .toList(growable: false),
        ),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.ChannelMessageList> listChannelMessages({
    required model.Session session,
    required String channelId,
    int limit = defaultLimit,
    bool? forward,
    String? cursor,
  }) async {
    try {
      final res = await _api.listChannelMessages(
        bearerToken: 'Bearer ${session.token}',
        channelId: channelId,
        limit: limit,
        forward: forward,
        cursor: cursor,
      );

      return model.ChannelMessageList.fromJson(res.toJson());
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.LeaderboardRecordList> listLeaderboardRecords({
    required model.Session session,
    required String leaderboardName,
    List<String>? ownerIds,
    int limit = defaultLimit,
    String? cursor,
    DateTime? expiry,
  }) async {
    try {
      final res = await _api.listLeaderboardRecords(
        bearerToken: 'Bearer ${session.token}',
        leaderboardId: leaderboardName,
        ownerIds: ownerIds ?? [],
        limit: limit,
        cursor: cursor,
        expiry: expiry == null
            ? null
            : (expiry.millisecondsSinceEpoch ~/ 1000).toString(),
      );

      return model.LeaderboardRecordList.fromJson(res.toJson());
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.LeaderboardRecordList> listLeaderboardRecordsAroundOwner({
    required model.Session session,
    required String leaderboardName,
    required String ownerId,
    int limit = defaultLimit,
    DateTime? expiry,
  }) async {
    try {
      final res = await _api.listLeaderboardRecordsAroundOwner(
        bearerToken: 'Bearer ${session.token}',
        leaderboardId: leaderboardName,
        ownerId: ownerId,
        limit: limit,
        expiry: expiry == null
            ? null
            : (expiry.millisecondsSinceEpoch ~/ 1000).toString(),
      );

      return model.LeaderboardRecordList.fromJson(res.toJson());
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.LeaderboardRecord> writeLeaderboardRecord({
    required model.Session session,
    required String leaderboardName,
    required int score,
    int? subscore,
    String? metadata,
    LeaderboardOperator? operator,
  }) async {
    try {
      final res = await _api.writeLeaderboardRecord(
          bearerToken: 'Bearer ${session.token}',
          leaderboardId: leaderboardName,
          body: WriteLeaderboardRecordRequestLeaderboardRecordWrite(
            score: score.toString(),
            subscore: (subscore ?? 0).toString(),
            metadata: metadata,
            operator: ApiOperator.values[operator?.index ?? 0],
          ));

      return model.LeaderboardRecord.fromJson(res.toJson());
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> deleteLeaderboardRecord({
    required model.Session session,
    required String leaderboardName,
  }) async {
    try {
      await _api.deleteLeaderboardRecord(
          bearerToken: 'Bearer ${session.token}',
          leaderboardId: leaderboardName);
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> addFriends({
    required model.Session session,
    required List<String> ids,
    List<String>? usernames,
  }) async {
    try {
      await _api.addFriends(
          bearerToken: 'Bearer ${session.token}',
          ids: ids,
          usernames: usernames ?? []);
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.FriendsList> listFriends({
    required model.Session session,
    FriendshipState? friendshipState,
    int limit = defaultLimit,
    String? cursor,
  }) async {
    try {
      final res = await _api.listFriends(
        bearerToken: 'Bearer ${session.token}',
        cursor: cursor,
        limit: limit,
        state: friendshipState?.index,
      );

      return model.FriendsList.fromJson(res.toJson());
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> deleteFriends({
    required model.Session session,
    required List<String> ids,
    List<String>? usernames,
  }) async {
    try {
      await _api.deleteFriends(
        bearerToken: 'Bearer ${session.token}',
        ids: ids,
        usernames: usernames ?? [],
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> blockFriends({
    required model.Session session,
    required List<String> ids,
    List<String>? usernames,
  }) async {
    try {
      await _api.blockFriends(
        bearerToken: 'Bearer ${session.token}',
        ids: ids,
        usernames: usernames ?? [],
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.Group> createGroup({
    required model.Session session,
    required String name,
    String? avatarUrl,
    String? description,
    String? langTag,
    int? maxCount,
    bool? open,
  }) async {
    try {
      final res = await _api.createGroup(
        bearerToken: 'Bearer ${session.token}',
        body: ApiCreateGroupRequest(
          name: name,
          avatarUrl: avatarUrl,
          description: description,
          langTag: langTag,
          maxCount: maxCount ?? 100,
          open: open,
        ),
      );

      return model.Group.fromJson(res.toJson());
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> updateGroup({
    required model.Session session,
    required String groupId,
    required String? name,
    String? avatarUrl,
    String? description,
    required String? langTag,
    bool? open,
  }) async {
    try {
      await _api.updateGroup(
        bearerToken: 'Bearer ${session.token}',
        groupId: groupId,
        body: ApiUpdateGroupRequest(
          groupId: groupId,
          name: name,
          open: open,
          avatarUrl: avatarUrl,
          description: description,
          langTag: langTag,
        ),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.GroupList> listGroups({
    required model.Session session,
    String? name,
    String? cursor,
    String? langTag,
    int? members,
    bool? open,
    int limit = defaultLimit,
  }) async {
    try {
      final res = await _api.listGroups(
        bearerToken: 'Bearer ${session.token}',
        cursor: cursor,
        langTag: langTag,
        limit: limit,
        members: members,
        name: name,
        open: open,
      );

      return model.GroupList.fromJson(res.toJson());
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> deleteGroup({
    required model.Session session,
    required String groupId,
  }) async {
    try {
      await _api.deleteGroup(
          bearerToken: 'Bearer ${session.token}', groupId: groupId);
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> joinGroup({
    required model.Session session,
    required String groupId,
  }) async {
    try {
      await _api.joinGroup(
          bearerToken: 'Bearer ${session.token}', groupId: groupId);
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.UserGroupList> listUserGroups({
    required model.Session session,
    String? cursor,
    int limit = defaultLimit,
    GroupMembershipState? state,
    String? userId,
  }) async {
    try {
      final res = await _api.listUserGroups(
        bearerToken: 'Bearer ${session.token}',
        cursor: cursor,
        limit: limit,
        state: state?.index,
        userId: userId ?? session.userId,
      );

      return model.UserGroupList.fromJson(res.toJson());
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.GroupUserList> listGroupUsers({
    required model.Session session,
    required String groupId,
    String? cursor,
    int limit = defaultLimit,
    GroupMembershipState? state,
  }) async {
    try {
      final res = await _api.listGroupUsers(
        bearerToken: 'Bearer ${session.token}',
        groupId: groupId,
        cursor: cursor,
        limit: limit,
        state: state?.index,
      );

      return model.GroupUserList.fromJson(res.toJson());
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> addGroupUsers({
    required model.Session session,
    required String groupId,
    required Iterable<String> userIds,
  }) async {
    try {
      await _api.addGroupUsers(
        bearerToken: 'Bearer ${session.token}',
        groupId: groupId,
        userIds: userIds.toList(growable: false),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> promoteGroupUsers({
    required model.Session session,
    required String groupId,
    required Iterable<String> userIds,
  }) async {
    try {
      await _api.promoteGroupUsers(
        bearerToken: 'Bearer ${session.token}',
        groupId: groupId,
        userIds: userIds.toList(growable: false),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> demoteGroupUsers({
    required model.Session session,
    required String groupId,
    required Iterable<String> userIds,
  }) async {
    try {
      await _api.demoteGroupUsers(
        bearerToken: 'Bearer ${session.token}',
        groupId: groupId,
        userIds: userIds.toList(growable: false),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> kickGroupUsers({
    required model.Session session,
    required String groupId,
    required Iterable<String> userIds,
  }) async {
    try {
      await _api.kickGroupUsers(
        bearerToken: 'Bearer ${session.token}',
        groupId: groupId,
        userIds: userIds.toList(growable: false),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> banGroupUsers({
    required model.Session session,
    required String groupId,
    required Iterable<String> userIds,
  }) async {
    try {
      await _api.banGroupUsers(
        bearerToken: 'Bearer ${session.token}',
        groupId: groupId,
        userIds: userIds.toList(growable: false),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> leaveGroup({
    required model.Session session,
    required String groupId,
  }) async {
    try {
      await _api.leaveGroup(
          bearerToken: 'Bearer ${session.token}', groupId: groupId);
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.NotificationList> listNotifications({
    required model.Session session,
    int limit = defaultLimit,
    String? cursor,
  }) async {
    try {
      final res = await _api.listNotifications(
        bearerToken: 'Bearer ${session.token}',
        limit: limit,
        cacheableCursor: cursor,
      );

      return model.NotificationList.fromJson(res.toJson());
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> deleteNotifications({
    required model.Session session,
    required Iterable<String> notificationIds,
  }) async {
    try {
      await _api.deleteNotifications(
        bearerToken: 'Bearer ${session.token}',
        ids: notificationIds.toList(growable: false),
      );
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<List<model.Match>> listMatches({
    required model.Session session,
    bool? authoritative,
    String? label,
    int limit = defaultLimit,
    int? maxSize,
    int? minSize,
    String? query,
  }) async {
    try {
      final res = await _api.listMatches(
        bearerToken: 'Bearer ${session.token}',
        authoritative: authoritative,
        label: label,
        limit: limit,
        maxSize: maxSize,
        minSize: minSize,
        query: query,
      );

      return res.matches
              ?.map((e) => model.Match.fromJson(e.toJson()))
              .toList(growable: false) ??
          [];
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> joinTournament({
    required model.Session session,
    required String tournamentId,
  }) async {
    try {
      await _api.joinTournament(
          bearerToken: 'Bearer ${session.token}', tournamentId: tournamentId);
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.TournamentList> listTournaments({
    required model.Session session,
    int? categoryStart,
    int? categoryEnd,
    String? cursor,
    DateTime? startTime,
    DateTime? endTime,
    int limit = defaultLimit,
  }) async {
    try {
      final res = await _api.listTournaments(
        bearerToken: 'Bearer ${session.token}',
        categoryStart: categoryStart,
        categoryEnd: categoryEnd,
        cursor: cursor,
        startTime:
            startTime != null ? startTime.millisecondsSinceEpoch ~/ 1000 : null,
        endTime:
            endTime != null ? endTime.millisecondsSinceEpoch ~/ 1000 : null,
        limit: limit,
      );

      return model.TournamentList.fromJson(res.toJson());
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.TournamentRecordList> listTournamentRecords({
    required model.Session session,
    required String tournamentId,
    required Iterable<String> ownerIds,
    int? expiry,
    int limit = defaultLimit,
    String? cursor,
  }) async {
    try {
      final res = await _api.listTournamentRecords(
        bearerToken: 'Bearer ${session.token}',
        ownerIds: ownerIds.toList(growable: false),
        tournamentId: tournamentId,
        cursor: cursor,
        expiry: expiry?.toString(),
        limit: limit,
      );

      return model.TournamentRecordList.fromJson(res.toJson());
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.TournamentRecordList> listTournamentRecordsAroundOwner({
    required model.Session session,
    required String tournamentId,
    required String ownerId,
    int? expiry,
    int limit = defaultLimit,
  }) async {
    try {
      final res = await _api.listTournamentRecordsAroundOwner(
        bearerToken: 'Bearer ${session.token}',
        ownerId: ownerId,
        tournamentId: tournamentId,
        expiry: expiry?.toString(),
        limit: limit,
      );

      return model.TournamentRecordList.fromJson(res.toJson());
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<model.LeaderboardRecord> writeTournamentRecord({
    required model.Session session,
    required String tournamentId,
    String? metadata,
    LeaderboardOperator? operator,
    int? score,
    int? subscore,
  }) async {
    try {
      final res = await _api.writeTournamentRecord(
        bearerToken: 'Bearer ${session.token}',
        tournamentId: tournamentId,
        body: WriteTournamentRecordRequestTournamentRecordWrite(
          metadata: metadata,
          score: score.toString(),
          subscore: (subscore ?? 0).toString(),
          operator: ApiOperator.values[operator?.index ?? 0],
        ),
      );

      return model.LeaderboardRecord.fromJson(res.toJson());
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<String?> rpc({
    required model.Session session,
    required String id,
    String? payload,
  }) async {
    try {
      ApiRpc res;

      if (payload == null) {
        res =
            await _api.rpcFunc2(bearerToken: 'Bearer ${session.token}', id: id);
      } else {
        res = await _api.rpcFunc(
            bearerToken: 'Bearer ${session.token}',
            id: id,
            body: preparePayload(payload));
      }

      return res.payload;
    } on Exception catch (e) {
      throw _handleError(e);
    }
  }
}
