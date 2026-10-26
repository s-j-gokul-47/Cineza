import { useEffect, useRef, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";

const TIMELINE = {
  fullPause: 300,   // pause after last digit before scan starts
  verifyHold: 800,  // scan glow sweep across boxes
  mergeDelay: 280,  // pause before merging into checkmark
  successHold: 2000,// checkmark duration before calling onSuccess
  errorHold: 1400,  // error shake & red state duration before resetting
};

/**
 * Animated OTP Verification UI Component (Self-Contained)
 *
 * @param {Object} props
 * @param {number} [props.length=4] - Number of OTP digits.
 * @param {Function} props.onVerify - Async function: (code) => Promise<boolean | { valid: boolean, message?: string }>
 * @param {Function} [props.onSuccess] - Callback fired after success animation completes (e.g. redirect/navigate).
 * @param {Function} [props.onResend] - Callback fired when Resend button is clicked.
 * @param {string} [props.title="Let's verify your number"]
 * @param {string} [props.subtitle]
 * @param {string} [props.successTitle="Verified successfully"]
 * @param {string} [props.successSubtitle="Your phone number has been verified."]
 * @param {string} [props.errorTitle="Invalid code"]
 * @param {string} [props.errorSubtitle="The code you entered is incorrect. Please try again."]
 */
export default function OtpVerification({
  length = 4,
  onVerify,
  onSuccess,
  onResend,
  title = "Let's verify your number",
  subtitle = `We've sent a ${length}-digit code to your phone.`,
  successTitle = "Verified successfully",
  successSubtitle = "Your phone number has been verified.",
  errorTitle = "Invalid code",
  errorSubtitle = "The code you entered is incorrect. Please try again.",
}) {
  const [code, setCode] = useState("");
  const [phase, setPhase] = useState("idle"); // idle | typing | verifying | success | error
  const [customError, setCustomError] = useState("");
  const timers = useRef([]);
  const inputRef = useRef(null);

  const clearTimers = () => {
    timers.current.forEach(clearTimeout);
    timers.current = [];
  };
  const t = (fn, ms) => timers.current.push(setTimeout(fn, ms));

  // Auto-focus input when accepting keystrokes
  useEffect(() => {
    if (phase !== "success" && phase !== "verifying" && phase !== "error") {
      inputRef.current?.focus();
    }
  }, [phase]);

  // Clean up all timers on unmount
  useEffect(() => {
    return clearTimers;
  }, []);

  // When all digits are entered, trigger the verification cycle
  useEffect(() => {
    if (code.length === length && phase !== "verifying" && phase !== "success" && phase !== "error") {
      clearTimers();

      // 1. Brief pause so user sees all digits entered
      t(() => setPhase("verifying"), TIMELINE.fullPause);

      // 2. Run the glowing scan sweep, then call the verification logic
      t(async () => {
        try {
          let isValid = false;
          let errorMessage = "";

          if (onVerify) {
            const res = await onVerify(code);
            if (typeof res === "boolean") {
              isValid = res;
            } else if (res && typeof res === "object") {
              isValid = Boolean(res.valid);
              errorMessage = res.message || "";
            }
          }

          if (isValid) {
            setPhase("success");
            // Hold success checkmark, then trigger parent onSuccess
            t(() => {
              onSuccess?.();
            }, TIMELINE.mergeDelay + TIMELINE.successHold);
          } else {
            setCustomError(errorMessage);
            setPhase("error");
            // Hold error shake, then clear code and reset for retry
            t(() => {
              setCode("");
              setCustomError("");
              setPhase("idle");
            }, TIMELINE.errorHold);
          }
        } catch (err) {
          setCustomError(err?.message || "");
          setPhase("error");
          t(() => {
            setCode("");
            setCustomError("");
            setPhase("idle");
          }, TIMELINE.errorHold);
        }
      }, TIMELINE.fullPause + TIMELINE.verifyHold);
    }
  }, [code, phase, length, onVerify, onSuccess]);

  const handleInput = (e) => {
    if (phase === "verifying" || phase === "success" || phase === "error") return;
    const v = e.target.value.replace(/\D/g, "").slice(0, length);
    setCode(v);
    setPhase(v.length > 0 ? "typing" : "idle");
  };

  const handleResend = () => {
    if (acceptingInput) {
      clearTimers();
      setCode("");
      setCustomError("");
      setPhase("idle");
      onResend?.();
      inputRef.current?.focus();
    }
  };

  const verified = phase === "success";
  const isError = phase === "error";
  const acceptingInput = phase !== "verifying" && phase !== "success" && phase !== "error";
  const activeIndex = acceptingInput && code.length < length ? code.length : -1;

  return (
    <motion.div
      className="card"
      onClick={() => acceptingInput && inputRef.current?.focus()}
      animate={{
        boxShadow: verified
          ? "0 0 0 1px rgba(52,211,153,0.25), 0 30px 80px -30px rgba(16,185,129,0.45)"
          : isError
          ? "0 0 0 1px rgba(239,68,68,0.25), 0 30px 80px -30px rgba(239,68,68,0.4)"
          : "0 0 0 1px rgba(255,255,255,0.06), 0 30px 80px -40px rgba(0,0,0,0.8)",
      }}
      transition={{ duration: 0.5 }}
    >
      {/* Ambient background glow */}
      <AnimatePresence>
        {verified && (
          <motion.div
            key="ambient-success"
            className="ambient-glow success"
            initial={{ opacity: 0, scale: 0.6 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.8, ease: "easeOut" }}
          />
        )}
        {isError && (
          <motion.div
            key="ambient-error"
            className="ambient-glow error"
            initial={{ opacity: 0, scale: 0.6 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.4, ease: "easeOut" }}
          />
        )}
      </AnimatePresence>

      {/* Heading crossfade */}
      <div className="heading-slot">
        <AnimatePresence mode="wait">
          {verified ? (
            <motion.div
              key="done"
              className="heading success"
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -8 }}
              transition={{ duration: 0.35, delay: 0.05 }}
            >
              <h2>{successTitle}</h2>
              <p>{successSubtitle}</p>
            </motion.div>
          ) : isError ? (
            <motion.div
              key="error"
              className="heading error"
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -8 }}
              transition={{ duration: 0.25 }}
            >
              <h2>{errorTitle}</h2>
              <p>{customError || errorSubtitle}</p>
            </motion.div>
          ) : (
            <motion.div
              key="ask"
              className="heading"
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -8 }}
              transition={{ duration: 0.35 }}
            >
              <h2>{title}</h2>
              <p>{subtitle}</p>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* Body: OTP boxes OR checkmark */}
      <div className="body-slot">
        {!verified && (
          <input
            ref={inputRef}
            className="otp-input"
            value={code}
            onChange={handleInput}
            inputMode="numeric"
            autoComplete="one-time-code"
            maxLength={length}
            aria-label="Enter verification code"
            autoFocus
          />
        )}

        <AnimatePresence mode="popLayout">
          {!verified ? (
            <motion.div
              key="otp"
              className="otp-row"
              initial={{ opacity: 0 }}
              animate={
                isError
                  ? {
                      opacity: 1,
                      x: [0, -12, 12, -8, 8, -4, 4, 0],
                    }
                  : { opacity: 1, x: 0 }
              }
              exit={{ scale: 0.7, opacity: 0, filter: "blur(6px)" }}
              transition={
                isError
                  ? { duration: 0.45, ease: "easeInOut" }
                  : { duration: 0.3 }
              }
            >
              {Array.from({ length }).map((_, i) => {
                const digit = code[i];
                const isFilled = i < code.length;
                const isActive = i === activeIndex;
                const isVerifying = phase === "verifying";

                let animate;
                let transition;
                if (isError) {
                  animate = {
                    borderColor: "rgba(239,68,68,0.95)",
                    boxShadow:
                      "0 0 0 3px rgba(239,68,68,0.2), 0 0 24px rgba(239,68,68,0.45)",
                    color: "#f87171",
                  };
                  transition = { duration: 0.2 };
                } else if (isVerifying) {
                  animate = {
                    borderColor: "rgba(52,211,153,0.95)",
                    boxShadow:
                      "0 0 0 3px rgba(52,211,153,0.2), 0 0 26px rgba(52,211,153,0.55)",
                    borderRadius: 30,
                    scale: [1, 1.1, 1],
                  };
                  transition = { duration: 0.5, delay: i * 0.13, ease: "easeOut" };
                } else if (isActive) {
                  animate = {
                    borderColor: "rgba(255,122,69,0.9)",
                    boxShadow:
                      "0 0 0 3px rgba(255,122,69,0.18), 0 0 22px rgba(255,122,69,0.35)",
                  };
                  transition = { duration: 0.25 };
                } else {
                  animate = {
                    borderColor: "rgba(255,255,255,0.12)",
                    boxShadow: "0 0 0 0px rgba(255,122,69,0)",
                  };
                  transition = { duration: 0.25 };
                }

                return (
                  <motion.div
                    key={i}
                    layout
                    className={`otp-box${isActive ? " active" : ""}${
                      isFilled ? " filled" : ""
                    }${isError ? " error" : ""}`}
                    animate={animate}
                    transition={transition}
                  >
                    <AnimatePresence>
                      {isFilled && (
                        <motion.span
                          key="d"
                          initial={{ opacity: 0, y: 10, scale: 0.5 }}
                          animate={{ opacity: 1, y: 0, scale: 1 }}
                          transition={{ type: "spring", stiffness: 520, damping: 24 }}
                        >
                          {digit}
                        </motion.span>
                      )}
                    </AnimatePresence>
                    {isActive && <span className="caret" />}
                  </motion.div>
                );
              })}
            </motion.div>
          ) : (
            <motion.div
              key="check"
              className="check-box"
              initial={{ scale: 0.4, opacity: 0, borderRadius: "30%" }}
              animate={{ scale: 1, opacity: 1, borderRadius: "26%" }}
              transition={{ type: "spring", stiffness: 260, damping: 18 }}
            >
              <motion.div
                className="check-pulse"
                initial={{ scale: 0.6, opacity: 0.7 }}
                animate={{ scale: 1.8, opacity: 0 }}
                transition={{ duration: 0.9, ease: "easeOut" }}
              />
              <svg viewBox="0 0 52 52" className="check-svg">
                <motion.path
                  d="M14 27 L23 36 L39 18"
                  fill="none"
                  stroke="#34d399"
                  strokeWidth="5"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  initial={{ pathLength: 0 }}
                  animate={{ pathLength: 1 }}
                  transition={{ duration: 0.45, delay: 0.18, ease: "easeOut" }}
                />
              </svg>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* Footer */}
      <div className="footer">
        <span>Didn't receive the code?</span>
        <button type="button" onClick={handleResend}>
          Resend
        </button>
      </div>
    </motion.div>
  );
}
