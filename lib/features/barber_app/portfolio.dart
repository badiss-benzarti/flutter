import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/cloud/cloud_errors.dart';
import '../../core/media/photo_compressor.dart';
import 'barber_session.dart';

/// One photo of a cut, as posted by a barber.
class PortfolioPost {
  const PortfolioPost({
    required this.id,
    required this.imagePath,
    required this.imageUrl,
    required this.caption,
    required this.ratingAvg,
    required this.ratingCount,
    required this.commentCount,
    required this.createdAt,
  });

  final String id;

  /// Path in the storage bucket (`<barber id>/<file>`).
  final String imagePath;
  final String imageUrl;
  final String caption;

  /// This photo's own stars, from client accounts.
  final double ratingAvg;
  final int ratingCount;
  final int commentCount;
  final DateTime createdAt;
}

class PostComment {
  const PostComment({
    required this.id,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String authorName;
  final String body;
  final DateTime createdAt;
}

/// The barber's rating: from clients' ratings of real visits only.
class VisitRating {
  const VisitRating(this.average, this.count);

  final double average;
  final int count;
}

/// Server access for a barber's portfolio. Failures are thrown as
/// `AppException`.
abstract class PortfolioRepository {
  Future<List<PortfolioPost>> postsOf(String barberId);

  Future<List<PostComment>> commentsOf(String postId);

  Future<VisitRating> visitRatingOf(String barberId);

  /// Compresses [photo], uploads it to the barber's folder and posts it.
  Future<void> publish({
    required String barberId,
    required Uint8List photo,
    required String caption,
  });

  Future<void> deletePost(PortfolioPost post);

  Future<void> deleteComment(String commentId);
}

class SupabasePortfolioRepository implements PortfolioRepository {
  SupabasePortfolioRepository(this._client);

  final SupabaseClient _client;

  static const bucket = 'portfolio';

  StorageFileApi get _files => _client.storage.from(bucket);

  @override
  Future<List<PortfolioPost>> postsOf(String barberId) async {
    try {
      final rows = await _client
          .from('portfolio_posts')
          .select(
            'id, image_path, caption, rating_avg, rating_count, '
            'comment_count, created_at',
          )
          .eq('barber_id', barberId)
          .order('created_at', ascending: false);
      return [
        for (final r in rows)
          PortfolioPost(
            id: r['id'] as String,
            imagePath: r['image_path'] as String,
            imageUrl: _files.getPublicUrl(r['image_path'] as String),
            caption: r['caption'] as String,
            ratingAvg: (r['rating_avg'] as num).toDouble(),
            ratingCount: r['rating_count'] as int,
            commentCount: r['comment_count'] as int,
            createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          ),
      ];
    } catch (e) {
      throw cloudException(e);
    }
  }

  @override
  Future<List<PostComment>> commentsOf(String postId) async {
    try {
      final rows = await _client
          .from('post_comments')
          .select('id, author_name, body, created_at')
          .eq('post_id', postId)
          .order('created_at');
      return [
        for (final r in rows)
          PostComment(
            id: r['id'] as String,
            authorName: r['author_name'] as String,
            body: r['body'] as String,
            createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          ),
      ];
    } catch (e) {
      throw cloudException(e);
    }
  }

  @override
  Future<VisitRating> visitRatingOf(String barberId) async {
    try {
      final row = await _client
          .from('barbers')
          .select('rating_avg, rating_count')
          .eq('id', barberId)
          .single();
      return VisitRating(
        (row['rating_avg'] as num).toDouble(),
        row['rating_count'] as int,
      );
    } catch (e) {
      throw cloudException(e);
    }
  }

  @override
  Future<void> publish({
    required String barberId,
    required Uint8List photo,
    required String caption,
  }) async {
    final jpeg = await PhotoCompressor.compress(photo);
    final path = '$barberId/${const Uuid().v4()}.jpg';
    try {
      await _files.uploadBinary(
        path,
        jpeg,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );
    } catch (e) {
      throw cloudException(e);
    }
    try {
      await _client.from('portfolio_posts').insert({
        'barber_id': barberId,
        'image_path': path,
        'caption': caption.trim(),
        'client_consent': true,
      });
    } catch (e) {
      // No orphan photo if the post itself is refused.
      await _files.remove([path]).catchError((_) => <FileObject>[]);
      throw cloudException(e);
    }
  }

  @override
  Future<void> deletePost(PortfolioPost post) async {
    try {
      await _client.from('portfolio_posts').delete().eq('id', post.id);
      await _files.remove([post.imagePath]);
    } catch (e) {
      throw cloudException(e);
    }
  }

  @override
  Future<void> deleteComment(String commentId) async {
    try {
      await _client.from('post_comments').delete().eq('id', commentId);
    } catch (e) {
      throw cloudException(e);
    }
  }
}

final portfolioRepositoryProvider = Provider<PortfolioRepository>(
  (ref) => SupabasePortfolioRepository(Supabase.instance.client),
);

/// The signed-in barber's posts, newest first.
final myPostsProvider = FutureProvider.autoDispose<List<PortfolioPost>>((
  ref,
) async {
  final barberId = ref.watch(
    barberSessionProvider.select((s) => s.link?.barberId),
  );
  if (barberId == null) return const [];
  return ref.read(portfolioRepositoryProvider).postsOf(barberId);
});

final myVisitRatingProvider = FutureProvider.autoDispose<VisitRating>((
  ref,
) async {
  final barberId = ref.watch(
    barberSessionProvider.select((s) => s.link?.barberId),
  );
  if (barberId == null) return const VisitRating(0, 0);
  return ref.read(portfolioRepositoryProvider).visitRatingOf(barberId);
});

final postCommentsProvider = FutureProvider.autoDispose
    .family<List<PostComment>, String>(
      (ref, postId) => ref.read(portfolioRepositoryProvider).commentsOf(postId),
    );
