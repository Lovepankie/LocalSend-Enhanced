import 'dart:io';
import 'dart:typed_data';

import 'package:common/model/file_type.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/provider/network/server/server_utils.dart';
import 'package:localsend_app/provider/receive_history_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/native/directories.dart';
import 'package:localsend_app/util/native/file_saver.dart';
import 'package:localsend_app/util/simple_server.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Serves a self-contained, no-app browser page that lets a computer joined to
/// the host's hotspot UPLOAD files to the phone (PC -> phone). The download
/// direction (phone -> PC) is handled by the existing web-send flow.
///
/// Routes (active whenever the server runs):
///   GET  /direct         -> inline HTML upload page (no app, no sign-in)
///   POST /direct/upload  -> multipart form upload, saved to the receive folder
class DirectWebController {
  final ServerUtils server;

  DirectWebController(this.server);

  void installRoutes({required SimpleServerRouteBuilder router}) {
    router.get('/direct', (HttpRequest request) async {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write(_uploadPageHtml);
      await request.response.close();
    });

    router.post('/direct/upload', (HttpRequest request) async {
      await _handleUpload(request);
    });
  }

  Future<void> _handleUpload(HttpRequest request) async {
    final contentType = request.headers.contentType;
    final boundary = contentType?.parameters['boundary'];
    if (contentType == null ||
        !contentType.mimeType.startsWith('multipart/') ||
        boundary == null) {
      return request.respondJson(
        400,
        message: 'Expected multipart/form-data upload.',
      );
    }

    final settings = server.ref.read(settingsProvider);
    final destinationDir =
        settings.destination ?? await getDefaultDestinationDirectory();
    final androidSdkInt = server.ref.read(deviceInfoProvider).androidSdkInt;

    final createdDirectories = <String>{};
    var savedCount = 0;

    try {
      final parts = MimeMultipartTransformer(boundary).bind(request);
      await for (final part in parts) {
        final disposition = part.headers['content-disposition'];
        final fileName = disposition == null
            ? null
            : _filenameFromDisposition(disposition);
        if (fileName == null || fileName.isEmpty) {
          // Not a file field (or unnamed) — drain and skip.
          await part.drain<void>();
          continue;
        }

        var savedBytes = 0;
        final (savedToGallery, filePath) = await saveFile(
          destinationDirectory: destinationDir,
          fileName: fileName,
          saveToGallery: false,
          isImage: false,
          stream: part.map((chunk) => Uint8List.fromList(chunk)),
          onProgress: (b) => savedBytes = b,
          createdDirectories: createdDirectories,
          androidSdkInt: androidSdkInt,
        );

        // Record the browser upload in history like any other received file.
        await server.ref.redux(receiveHistoryProvider).dispatchAsync(
              AddHistoryEntryAction(
                entryId: _uuid.v4(),
                fileName: fileName,
                fileType: _guessFileType(fileName),
                path: filePath,
                savedToGallery: savedToGallery,
                isMessage: false,
                fileSize: savedBytes,
                senderAlias: 'Browser',
                timestamp: DateTime.now().toUtc(),
              ),
            );
        savedCount++;
      }
    } catch (e) {
      return request.respondJson(500, message: 'Upload failed: $e');
    }

    return request.respondJson(200, body: {'saved': savedCount});
  }

  String? _filenameFromDisposition(String disposition) {
    // content-disposition: form-data; name="file"; filename="photo.jpg"
    final match = RegExp('filename="([^"]*)"').firstMatch(disposition);
    return match?.group(1);
  }

  FileType _guessFileType(String name) {
    final parts = name.toLowerCase().split('.');
    final ext = parts.length > 1 ? parts.last : '';
    const images = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'};
    const videos = {'mp4', 'mkv', 'mov', 'avi', 'webm', '3gp'};
    if (images.contains(ext)) return FileType.image;
    if (videos.contains(ext)) return FileType.video;
    if (ext == 'pdf') return FileType.pdf;
    if (ext == 'apk') return FileType.apk;
    if (ext == 'txt') return FileType.text;
    return FileType.other;
  }
}

const _uploadPageHtml = r'''
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Send to phone</title>
<style>
  body{font-family:-apple-system,Segoe UI,Roboto,sans-serif;background:#0D1B3E;
    color:#EEF4FF;margin:0;display:flex;min-height:100vh;align-items:center;
    justify-content:center}
  .card{background:#18264a;border-radius:18px;padding:32px;max-width:460px;
    width:90%;box-shadow:0 12px 40px rgba(0,0,0,.4)}
  h1{margin:0 0 6px;font-size:22px}
  p{color:#A0B0C8;margin:0 0 22px;font-size:14px}
  .drop{border:2px dashed #35508a;border-radius:14px;padding:34px 18px;
    text-align:center;cursor:pointer;transition:border-color .15s,background .15s}
  .drop:hover,.drop.over{border-color:#1A73E8;background:#1d2c54}
  .drop strong{color:#1A73E8}
  input[type=file]{display:none}
  button{margin-top:18px;width:100%;background:#1A73E8;color:#fff;border:0;
    border-radius:10px;padding:13px;font-size:15px;font-weight:600;cursor:pointer}
  button:disabled{opacity:.5;cursor:default}
  #list{margin-top:14px;font-size:13px;color:#A0B0C8;max-height:140px;overflow:auto}
  #status{margin-top:14px;font-size:14px;min-height:20px}
  .ok{color:#43d17a}.err{color:#ff6b6b}
</style>
</head>
<body>
  <div class="card">
    <h1>Send to phone</h1>
    <p>Drop files here or choose them. They go straight to the phone over this
       direct connection — no app, no internet.</p>
    <label class="drop" id="drop">
      <input type="file" id="file" multiple>
      <div>Drag files here or <strong>browse</strong></div>
    </label>
    <div id="list"></div>
    <button id="send" disabled>Send</button>
    <div id="status"></div>
  </div>
<script>
  var input = document.getElementById("file");
  var drop = document.getElementById("drop");
  var list = document.getElementById("list");
  var sendBtn = document.getElementById("send");
  var status = document.getElementById("status");
  var files = [];

  function render(){
    list.innerHTML = files.map(function(f){return "• "+f.name;}).join("<br>");
    sendBtn.disabled = files.length === 0;
  }
  input.addEventListener("change", function(){
    files = Array.prototype.slice.call(input.files); render();
  });
  ["dragover","dragenter"].forEach(function(ev){
    drop.addEventListener(ev, function(e){e.preventDefault();drop.classList.add("over");});
  });
  ["dragleave","drop"].forEach(function(ev){
    drop.addEventListener(ev, function(e){e.preventDefault();drop.classList.remove("over");});
  });
  drop.addEventListener("drop", function(e){
    files = Array.prototype.slice.call(e.dataTransfer.files); render();
  });
  sendBtn.addEventListener("click", function(){
    if(files.length === 0) return;
    var form = new FormData();
    files.forEach(function(f){ form.append("file", f, f.name); });
    var xhr = new XMLHttpRequest();
    xhr.open("POST", "/direct/upload");
    sendBtn.disabled = true; status.className = ""; status.textContent = "Sending…";
    xhr.upload.onprogress = function(e){
      if(e.lengthComputable){
        var pct = Math.round(e.loaded/e.total*100);
        status.textContent = "Sending… "+pct+"%";
      }
    };
    xhr.onload = function(){
      if(xhr.status === 200){
        status.className = "ok"; status.textContent = "Sent to phone ✓";
        files = []; input.value = ""; render();
      } else {
        status.className = "err"; status.textContent = "Failed ("+xhr.status+")";
        sendBtn.disabled = false;
      }
    };
    xhr.onerror = function(){
      status.className = "err"; status.textContent = "Connection error";
      sendBtn.disabled = false;
    };
    xhr.send(form);
  });
</script>
</body>
</html>
''';
