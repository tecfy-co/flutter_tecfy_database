part of '../../tecfy_database.dart';

/// Raw rows to decode: each row is `[tecfy_json_body, primaryKeyValue]`.
/// Kept to plain lists/strings so it can be sent to a background isolate.
class _TecfyDecodeJob {
  final List<List<Object?>> rows;
  final String pkName;
  final List<String> dateFields;

  _TecfyDecodeJob(this.rows, this.pkName, this.dateFields);
}

/// Decodes stored rows back into documents: parses the JSON body, restores the
/// primary key and turns indexed datetime fields back into [DateTime]s.
/// Top-level so it can run under `compute`.
List<Map<String, dynamic>> _decodeTecfyRows(_TecfyDecodeJob job) {
  return job.rows.map((row) {
    final data = jsonDecode(row[0] as String) as Map<String, dynamic>;
    data[job.pkName] = row[1];
    for (final field in job.dateFields) {
      final value = data[field];
      if (value is int) {
        data[field] = DateTime.fromMillisecondsSinceEpoch(value);
      } else if (value is String) {
        data[field] = DateTime.tryParse(value);
      }
    }
    return data;
  }).toList();
}
