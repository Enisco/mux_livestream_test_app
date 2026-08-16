import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/models/engagement_models/engagement_models.dart';

MediaComment _comment({
  int likes = 0,
  int dislikes = 0,
  CommentVote? vote,
  String? parent,
  Map<String, dynamic>? author,
}) => MediaComment.fromJson({
  'id': 'c1',
  'body': 'Amen',
  'author': author,
  'createdAt': '2026-08-01T10:00:00.000Z',
  'likeCount': likes,
  'dislikeCount': dislikes,
  'myVote': vote?.wire,
  'parentCommentId': parent,
});

/// Mirrors `_CommentsSheetState._locallyVoted` — the optimistic vote maths.
MediaComment locallyVoted(MediaComment c, CommentVote vote) {
  final had = c.myVote;
  final clearing = had == vote;
  var likes = c.likeCount;
  var dislikes = c.dislikeCount;

  if (had == CommentVote.like) likes -= 1;
  if (had == CommentVote.dislike) dislikes -= 1;
  if (!clearing && vote == CommentVote.like) likes += 1;
  if (!clearing && vote == CommentVote.dislike) dislikes += 1;

  return c.copyWith(
    likeCount: likes < 0 ? 0 : likes,
    dislikeCount: dislikes < 0 ? 0 : dislikes,
    myVote: clearing ? null : vote,
    clearVote: clearing,
  );
}

void main() {
  group('comment parsing', () {
    test('a null author does not break the row', () {
      // Staging really does return these, and the sheet must still render.
      final c = _comment();
      expect(c.author, isNull);
      expect(c.body, 'Amen');
    });

    test('the creator flag comes off the author', () {
      final c = _comment(
        author: {'displayName': 'GospelTube', 'isCreator': true},
      );
      expect(c.author?.isCreator, isTrue);
      expect(c.author?.displayName, 'GospelTube');
    });

    test('a reply knows its parent', () {
      expect(_comment(parent: 'p1').isReply, isTrue);
      expect(_comment().isReply, isFalse);
    });

    test('an unknown vote value reads as no vote', () {
      expect(CommentVote.parse('sideways'), isNull);
      expect(CommentVote.parse(null), isNull);
      expect(CommentVote.parse('like'), CommentVote.like);
      expect(CommentVote.parse('dislike'), CommentVote.dislike);
    });

    test('the wire values are the two the API accepts', () {
      // Anything else is rejected: "vote must be one of: like, dislike".
      expect(CommentVote.like.wire, 'like');
      expect(CommentVote.dislike.wire, 'dislike');
    });
  });

  group('optimistic voting', () {
    test('liking a fresh comment adds one', () {
      final r = locallyVoted(_comment(likes: 4), CommentVote.like);
      expect(r.likeCount, 5);
      expect(r.myVote, CommentVote.like);
    });

    test('liking again clears the vote and the count', () {
      final r = locallyVoted(
        _comment(likes: 5, vote: CommentVote.like),
        CommentVote.like,
      );
      expect(r.likeCount, 4);
      expect(r.myVote, isNull);
    });

    test('switching sides moves the count across', () {
      final r = locallyVoted(
        _comment(likes: 3, dislikes: 1, vote: CommentVote.like),
        CommentVote.dislike,
      );
      expect(r.likeCount, 2);
      expect(r.dislikeCount, 2);
      expect(r.myVote, CommentVote.dislike);
    });

    test('a count can never go negative', () {
      // Server and client can disagree; the UI must not show -1.
      final r = locallyVoted(
        _comment(likes: 0, vote: CommentVote.like),
        CommentVote.like,
      );
      expect(r.likeCount, 0);
    });

    test('copyWith keeps what it is not given', () {
      final c = _comment(likes: 2, dislikes: 1, vote: CommentVote.like);
      final r = c.copyWith(replyCount: 3);
      expect(r.likeCount, 2);
      expect(r.dislikeCount, 1);
      expect(r.myVote, CommentVote.like);
      expect(r.replyCount, 3);
    });

    test('clearVote actually clears, rather than falling back', () {
      final c = _comment(vote: CommentVote.like);
      // `myVote ?? this.myVote` would silently keep the old vote here.
      expect(c.copyWith(clearVote: true).myVote, isNull);
    });
  });
}
