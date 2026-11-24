import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../orders/domain/order_models.dart';

/// Private photos (prescriptions, handwritten lists, return photos). Only the uploader and the
/// shop's staff can fetch them, so they go through the API with the access token (no public URL).
abstract interface class PrivateMediaRepository {
  Future<Attachment> upload(String filePath, AttachmentKind kind);
  Future<Uint8List> bytes(String id, {bool thumb = true});
}

class HttpPrivateMediaRepository implements PrivateMediaRepository {
  HttpPrivateMediaRepository(this._dio);

  final Dio _dio;

  @override
  Future<Attachment> upload(String filePath, AttachmentKind kind) async {
    final form = FormData.fromMap({'kind': kind.wire, 'file': await MultipartFile.fromFile(filePath)});
    return Attachment.fromJson(await unwrap<Map<String, dynamic>>(_dio.post<dynamic>('/api/v1/media/private', data: form)));
  }

  @override
  Future<Uint8List> bytes(String id, {bool thumb = true}) async {
    try {
      final response = await _dio.get<List<int>>(
        '/api/v1/media/private/$id',
        queryParameters: {'size': thumb ? 'thumb' : 'full'},
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data!);
    } on DioException catch (error) {
      throw error.error is ApiException ? error.error! as ApiException : ApiException.fromDio(error);
    }
  }
}
