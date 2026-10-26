void callSendOtp(
    String identifier, void Function(dynamic) onSuccess, void Function(dynamic) onError) {
  onError('MSG91 OTP is only supported on Web platform.');
}

void callVerifyOtp(String otp, void Function(dynamic) onSuccess,
    void Function(dynamic) onError, String? reqId) {
  onError('MSG91 OTP is only supported on Web platform.');
}

void callRetryOtp(String channel, void Function(dynamic) onSuccess,
    void Function(dynamic) onError, String? reqId) {
  onError('MSG91 OTP is only supported on Web platform.');
}

bool get isMsg91Ready => false;
void initMsg91() {}
