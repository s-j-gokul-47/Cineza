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
    String identifier, Function(dynamic) onSuccess, Function(dynamic) onError) {
  if (_cinezaMsg91Ready != true) {
    try {
      _initCinezaMsg91();
    } catch (_) {}
  }
  _sendOtpJs(
    identifier.toJS,
    ((JSAny? data) => onSuccess(data?.dartify())).toJS,
    ((JSAny? error) => onError(error?.dartify())).toJS,
  );
}

void callVerifyOtp(String otp, Function(dynamic) onSuccess,
    Function(dynamic) onError, String? reqId) {
  _verifyOtpJs(
    otp.toJS,
    ((JSAny? data) => onSuccess(data?.dartify())).toJS,
    ((JSAny? error) => onError(error?.dartify())).toJS,
    reqId?.toJS,
  );
}

void callRetryOtp(String channel, Function(dynamic) onSuccess,
    Function(dynamic) onError, String? reqId) {
  _retryOtpJs(
    channel.toJS,
    ((JSAny? data) => onSuccess(data?.dartify())).toJS,
    ((JSAny? error) => onError(error?.dartify())).toJS,
    reqId?.toJS,
  );
}

bool get isMsg91Ready => _cinezaMsg91Ready == true;
void initMsg91() {
  try {
    _initCinezaMsg91();
  } catch (_) {}
}
