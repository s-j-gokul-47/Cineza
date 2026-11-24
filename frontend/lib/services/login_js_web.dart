import 'dart:js_interop';

@JS('cinezaSendOtp')
external void _sendOtpJs(
  JSAny? identifier,
  JSFunction successCallback,
  JSFunction failureCallback,
);

@JS('cinezaVerifyOtp')
external void _verifyOtpJs(
  JSAny? otp,
  JSFunction successCallback,
  JSFunction failureCallback,
  JSAny? reqId,
);

@JS('cinezaRetryOtp')
external void _retryOtpJs(
  JSAny? channel,
  JSFunction successCallback,
  JSFunction failureCallback,
  JSAny? reqId,
);

@JS('cinezaMsg91Ready')
external bool? get _cinezaMsg91Ready;

@JS('initCinezaMsg91')
external void _initCinezaMsg91();

void callSendOtp(
    String identifier, void Function(dynamic) onSuccess, void Function(dynamic) onError) {
  if (_cinezaMsg91Ready != true) {
    try {
      _initCinezaMsg91();
    } catch (_) {}
  }
  _sendOtpJs(
    identifier.toJS,
    ((JSAny? data) {
      onSuccess(data?.dartify());
    }).toJS,
    ((JSAny? error) {
      onError(error?.dartify());
    }).toJS,
  );
}

void callVerifyOtp(String otp, void Function(dynamic) onSuccess,
    void Function(dynamic) onError, String? reqId) {
  _verifyOtpJs(
    otp.toJS,
    ((JSAny? data) {
      onSuccess(data?.dartify());
    }).toJS,
    ((JSAny? error) {
      onError(error?.dartify());
    }).toJS,
    reqId?.toJS,
  );
}

void callRetryOtp(String channel, void Function(dynamic) onSuccess,
    void Function(dynamic) onError, String? reqId) {
  _retryOtpJs(
    channel.toJS,
    ((JSAny? data) {
      onSuccess(data?.dartify());
    }).toJS,
    ((JSAny? error) {
      onError(error?.dartify());
    }).toJS,
    reqId?.toJS,
  );
}

bool get isMsg91Ready => _cinezaMsg91Ready == true;
void initMsg91() {
  try {
    _initCinezaMsg91();
  } catch (_) {}
}

@JS('cinezaPlayClapperSound')
external void _playClapperSoundJs();

void playClapperSound() {
  try {
    _playClapperSoundJs();
  } catch (_) {}
}

@JS('cinezaSaveUserSession')
external void _saveUserSessionJs(JSString? data);

@JS('cinezaLoadUserSession')
external JSString? _loadUserSessionJs();

void saveWebUserSession(String userDataJson) {
  try {
    _saveUserSessionJs(userDataJson.toJS);
  } catch (_) {}
}

String? loadWebUserSession() {
  try {
    final res = _loadUserSessionJs();
    return res?.toDart;
  } catch (_) {
    return null;
  }
}

@JS('cinezaClearWebSession')
external void _clearWebSessionJs();

void clearWebSession() {
  try {
    _clearWebSessionJs();
  } catch (_) {}
}



