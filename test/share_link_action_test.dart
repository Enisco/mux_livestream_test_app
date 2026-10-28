import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/engagement/data/share_link_action.dart';
import 'package:test_app/features/engagement/repo/engagement_repo.dart';
import 'package:test_app/shared/services/api_service.dart';

/// Minting a link, which two surfaces now do through one helper.
///
/// The rule that matters is the one the route's own doc states and the card
/// sheet's tests already pin: **minting is not sharing**. Nothing here posts
/// an `interactionType: "share"` interaction, because a reader who opens a
/// sheet and changes their mind has not shared anything — counting the mint
/// would inflate every creator's share count by every abandoned sheet.
class _FakeApi implements ApiService {
  _FakeApi({
    this.url = 'https://gospeltube.tv/w/abc?analyticsSource=share_link',
    this.refuse = false,
  });

  final String? url;
  final bool refuse;
  final List<String> posted = [];

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    posted.add(path);
    if (refuse) {
      throw DioException(requestOptions: RequestOptions(path: path));
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data:
          {
                'data': {'url': url},
              }
              as T,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// What the helper actually put on the clipboard.
  String? copied;
  setUp(() {
    copied = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
  });

  test('mints a link and puts it on the clipboard', () async {
    final api = _FakeApi();
    final url = await copyShareLink(
      engagement: EngagementRepo(api: api),
      targetType: 'media',
      targetId: 'm1',
    );

    expect(url, 'https://gospeltube.tv/w/abc?analyticsSource=share_link');
    expect(copied, url);
    // One call, and it is the mint — not an interaction.
    expect(api.posted, ['/v1/engagement/share-links']);
  });

  test('the URL is copied exactly as returned', () async {
    // It carries `?analyticsSource=share_link`, and trimming or wrapping it
    // loses both the Open Graph preview and the deep link.
    final api = _FakeApi();
    await copyShareLink(
      engagement: EngagementRepo(api: api),
      targetType: 'media',
      targetId: 'm1',
    );

    expect(copied, contains('analyticsSource=share_link'));
  });

  test('a refusal answers null rather than throwing', () async {
    // A refusal is final — the target stays unshareable until its creator
    // changes its visibility — so the caller reports it and does not retry.
    final api = _FakeApi(refuse: true);
    final url = await copyShareLink(
      engagement: EngagementRepo(api: api),
      targetType: 'media',
      targetId: 'm1',
    );

    expect(url, isNull);
    expect(copied, isNull);
  });

  test('a mint that answers no URL copies nothing', () async {
    final api = _FakeApi(url: null);
    final url = await copyShareLink(
      engagement: EngagementRepo(api: api),
      targetType: 'media',
      targetId: 'm1',
    );

    expect(url, isNull);
    expect(copied, isNull);
  });

  test('an empty URL is treated as no URL', () async {
    final api = _FakeApi(url: '');
    expect(
      await copyShareLink(
        engagement: EngagementRepo(api: api),
        targetType: 'media',
        targetId: 'm1',
      ),
      isNull,
    );
    expect(copied, isNull);
  });
}
