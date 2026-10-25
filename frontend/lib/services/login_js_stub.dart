void callSendOtp(
    String identifier, Function(dynamic) onSuccess, Function(dynamic) onError) {
  onError('MSG91 OTP is only supported on Web platform.');
}

void callVerifyOtp(String otp, Function(dynamic) onSuccess,
    Function(dynamic) onError, String? reqId) {
  onError('MSG91 OTP is only supported on Web platform.');
}

void callRetryOtp(String channel, Function(dynamic) onSuccess,
    Function(dynamic) onError, String? reqId) {
  onError('MSG91 OTP is only supported on Web platform.');
}

bool get isMsg91Ready => false;
void initMsg91() {}
