import { Alert } from "react-native";

/**
 * Simple toast helper for React Native.
 * Uses Alert for errors/confirms; for lightweight info toasts
 * consider adding @/components/Toast and a ToastContext.
 */
export function useToast() {
  const toast = {
    success: (message: string) => {
      // On native, brief success messages are usually shown inline. For a richer
      // experience, integrate a library like react-native-toast-message. Errors and
      // info use Alert below; success is intentionally a no-op placeholder.
      void message;
    },
    error: (message: string) => {
      Alert.alert("Error", message);
    },
    info: (message: string) => {
      Alert.alert("Info", message);
    },
  };
  return toast;
}
