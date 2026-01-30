enum PhotoStatusType { local, uploaded, uploading, error }

class PhotoDisplay {
  final int? localId;
  final int? remoteId;
  final String? type;
  final String path;
  final String? url;
  final PhotoStatusType status;
  final String? errorMessage;

  PhotoDisplay({
    this.localId,
    this.remoteId,
    required this.path,
    this.url,
    this.type,
    required this.status,
    this.errorMessage,
  });
}