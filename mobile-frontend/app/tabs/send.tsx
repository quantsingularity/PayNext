import React, { useEffect, useState } from "react";
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
  Alert,
  ActivityIndicator,
  useColorScheme,
  KeyboardAvoidingView,
  Platform,
} from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { useLocalSearchParams, useRouter } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import { apiClient, mockApiClient, useMockData } from "@/lib/api-client";
import { Colors, Shadow } from "@/lib/theme";

const schema = z.object({
  recipient: z.string().min(3, "Recipient must be at least 3 characters."),
  amount: z.coerce
    .number({ invalid_type_error: "Amount must be a number." })
    .positive("Amount must be positive.")
    .multipleOf(0.01, "At most 2 decimal places."),
  memo: z.string().optional(),
});

type FormData = z.infer<typeof schema>;

const QUICK_AMOUNTS = [10, 25, 50, 100, 200];

export default function SendScreen() {
  const params = useLocalSearchParams<{
    recipient?: string;
    amount?: string;
    memo?: string;
  }>();
  const router = useRouter();
  const colorScheme = useColorScheme();
  const isDark = colorScheme === "dark";

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [lastTxId, setLastTxId] = useState<string | null>(null);

  const bg = isDark ? Colors.dark.background : Colors.background;
  const surface = isDark ? Colors.dark.surface : Colors.surface;
  const textPrimary = isDark ? Colors.dark.textPrimary : Colors.textPrimary;
  const textSecondary = isDark
    ? Colors.dark.textSecondary
    : Colors.textSecondary;
  const border = isDark ? Colors.dark.border : Colors.border;
  const inputBg = isDark ? "rgba(255,255,255,0.05)" : "#f8fafc";

  const {
    control,
    handleSubmit,
    setValue,
    watch,
    reset,
    formState: { errors },
  } = useForm<FormData>({
    resolver: zodResolver(schema),
    defaultValues: { recipient: "", amount: undefined, memo: "" },
  });

  const watchedAmount = watch("amount");

  useEffect(() => {
    if (params.recipient)
      setValue("recipient", decodeURIComponent(params.recipient));
    if (params.amount) {
      const n = parseFloat(params.amount);
      if (!isNaN(n) && n > 0) setValue("amount", n);
    }
    if (params.memo) setValue("memo", decodeURIComponent(params.memo));
  }, [params.recipient, params.amount, params.memo, setValue]);

  const onSubmit = async (data: FormData) => {
    setIsSubmitting(true);
    try {
      const client = useMockData ? mockApiClient : apiClient;
      const res = await client.sendPayment({
        recipient: data.recipient,
        amount: data.amount,
        memo: data.memo,
      });
      if (res.success && res.data) {
        setLastTxId((res.data as any).transactionId);
        reset();
        Alert.alert(
          "✓ Payment Sent!",
          `$${data.amount.toFixed(2)} sent to ${data.recipient} successfully.`,
          [{ text: "Done", onPress: () => setLastTxId(null) }],
        );
      } else {
        Alert.alert(
          "Payment Failed",
          res.error?.message || "Please try again.",
        );
      }
    } catch (err) {
      console.error("Send error:", err);
      Alert.alert("Error", "An unexpected error occurred. Please try again.");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <SafeAreaView
      style={[styles.safe, { backgroundColor: bg }]}
      edges={["top"]}
    >
      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === "ios" ? "padding" : "height"}
      >
        <ScrollView
          contentContainerStyle={styles.scroll}
          showsVerticalScrollIndicator={false}
          keyboardShouldPersistTaps="handled"
        >
          {/* Header */}
          <View style={styles.header}>
            <TouchableOpacity
              onPress={() => router.back()}
              style={[
                styles.backBtn,
                { backgroundColor: surface, borderColor: border },
              ]}
            >
              <Ionicons name="arrow-back" size={20} color={textPrimary} />
            </TouchableOpacity>
            <View style={{ flex: 1 }}>
              <Text style={[styles.pageTitle, { color: textPrimary }]}>
                Send Money
              </Text>
              <Text style={[styles.pageSubtitle, { color: textSecondary }]}>
                Fast &amp; secure transfers
              </Text>
            </View>
            <LinearGradient
              colors={[Colors.primary, Colors.primaryDark]}
              style={styles.headerIcon}
            >
              <Ionicons name="send" size={20} color="#fff" />
            </LinearGradient>
          </View>

          {/* Success Banner */}
          {lastTxId && (
            <View
              style={[
                styles.successBanner,
                {
                  backgroundColor: isDark ? "rgba(34,197,94,0.15)" : "#f0fdf4",
                  borderColor: isDark ? "#166534" : "#86efac",
                },
              ]}
            >
              <View
                style={[
                  styles.successIconWrap,
                  {
                    backgroundColor: isDark
                      ? "rgba(34,197,94,0.25)"
                      : "#dcfce7",
                  },
                ]}
              >
                <Ionicons
                  name="checkmark-circle"
                  size={20}
                  color={Colors.successMid}
                />
              </View>
              <View style={{ flex: 1 }}>
                <Text
                  style={[
                    styles.successTitle,
                    { color: isDark ? "#86efac" : Colors.success },
                  ]}
                >
                  Payment Sent!
                </Text>
                <Text
                  style={[
                    styles.successRef,
                    { color: isDark ? "#4ade80" : "#16a34a" },
                  ]}
                >
                  Ref: {lastTxId}
                </Text>
              </View>
            </View>
          )}

          {/* Form Card */}
          <View
            style={[
              styles.card,
              { backgroundColor: surface, borderColor: border },
            ]}
          >
            <Text style={[styles.cardTitle, { color: textPrimary }]}>
              Payment Details
            </Text>

            {/* Recipient */}
            <View style={styles.field}>
              <Text style={[styles.label, { color: textPrimary }]}>
                Recipient
              </Text>
              <Controller
                control={control}
                name="recipient"
                render={({ field: { value, onChange, onBlur } }) => (
                  <View
                    style={[
                      styles.inputWrap,
                      {
                        backgroundColor: inputBg,
                        borderColor: errors.recipient
                          ? Colors.errorMid
                          : border,
                      },
                    ]}
                  >
                    <Ionicons
                      name="person-circle-outline"
                      size={18}
                      color={textSecondary}
                      style={styles.inputIcon}
                    />
                    <TextInput
                      style={[styles.input, { color: textPrimary }]}
                      placeholder="Username, email, or phone"
                      placeholderTextColor={textSecondary}
                      value={value}
                      onChangeText={onChange}
                      onBlur={onBlur}
                      autoCapitalize="none"
                      keyboardType="email-address"
                    />
                  </View>
                )}
              />
              {errors.recipient && (
                <Text style={styles.errorText}>{errors.recipient.message}</Text>
              )}
              <Text style={[styles.hint, { color: textSecondary }]}>
                Enter username, email, or phone number
              </Text>
            </View>

            {/* Amount */}
            <View style={styles.field}>
              <Text style={[styles.label, { color: textPrimary }]}>
                Amount (USD)
              </Text>
              <Controller
                control={control}
                name="amount"
                render={({ field: { value, onChange, onBlur } }) => (
                  <View
                    style={[
                      styles.inputWrap,
                      {
                        backgroundColor: inputBg,
                        borderColor: errors.amount ? Colors.errorMid : border,
                      },
                    ]}
                  >
                    <Text
                      style={[styles.currencySymbol, { color: textSecondary }]}
                    >
                      $
                    </Text>
                    <TextInput
                      style={[
                        styles.input,
                        styles.amountInput,
                        { color: textPrimary },
                      ]}
                      placeholder="0.00"
                      placeholderTextColor={textSecondary}
                      value={value?.toString() ?? ""}
                      onChangeText={(t) => onChange(t === "" ? undefined : t)}
                      onBlur={onBlur}
                      keyboardType="decimal-pad"
                    />
                  </View>
                )}
              />
              {errors.amount && (
                <Text style={styles.errorText}>{errors.amount.message}</Text>
              )}

              {/* Quick amount pills */}
              <ScrollView
                horizontal
                showsHorizontalScrollIndicator={false}
                style={styles.quickAmounts}
              >
                {QUICK_AMOUNTS.map((amt) => (
                  <TouchableOpacity
                    key={amt}
                    style={[
                      styles.quickAmountPill,
                      {
                        backgroundColor:
                          watchedAmount === amt
                            ? Colors.primary
                            : isDark
                              ? "rgba(255,255,255,0.08)"
                              : "#f1f5f9",
                        borderColor:
                          watchedAmount === amt ? Colors.primary : border,
                      },
                    ]}
                    onPress={() => setValue("amount", amt)}
                  >
                    <Text
                      style={[
                        styles.quickAmountText,
                        {
                          color: watchedAmount === amt ? "#fff" : textSecondary,
                        },
                      ]}
                    >
                      ${amt}
                    </Text>
                  </TouchableOpacity>
                ))}
              </ScrollView>
            </View>

            {/* Memo */}
            <View style={styles.field}>
              <Text style={[styles.label, { color: textPrimary }]}>
                Memo{" "}
                <Text style={{ color: textSecondary, fontWeight: "400" }}>
                  (Optional)
                </Text>
              </Text>
              <Controller
                control={control}
                name="memo"
                render={({ field: { value, onChange, onBlur } }) => (
                  <View
                    style={[
                      styles.inputWrap,
                      { backgroundColor: inputBg, borderColor: border },
                    ]}
                  >
                    <Ionicons
                      name="chatbubble-outline"
                      size={16}
                      color={textSecondary}
                      style={styles.inputIcon}
                    />
                    <TextInput
                      style={[styles.input, { color: textPrimary }]}
                      placeholder="What's this payment for?"
                      placeholderTextColor={textSecondary}
                      value={value}
                      onChangeText={onChange}
                      onBlur={onBlur}
                    />
                  </View>
                )}
              />
            </View>

            {/* Submit */}
            <TouchableOpacity
              style={[
                styles.submitBtn,
                isSubmitting && styles.submitBtnDisabled,
              ]}
              onPress={handleSubmit(onSubmit)}
              disabled={isSubmitting}
              activeOpacity={0.8}
            >
              <LinearGradient
                colors={[Colors.primary, Colors.primaryDark]}
                style={styles.submitGradient}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 0 }}
              >
                {isSubmitting ? (
                  <ActivityIndicator color="#fff" size="small" />
                ) : (
                  <>
                    <Ionicons name="send" size={16} color="#fff" />
                    <Text style={styles.submitText}>Send Money</Text>
                    <Ionicons
                      name="arrow-forward"
                      size={16}
                      color="rgba(255,255,255,0.7)"
                    />
                  </>
                )}
              </LinearGradient>
            </TouchableOpacity>
          </View>

          {/* Security note */}
          <View style={styles.securityNote}>
            <Ionicons
              name="shield-checkmark-outline"
              size={14}
              color={textSecondary}
            />
            <Text style={[styles.securityText, { color: textSecondary }]}>
              Secured with end-to-end encryption
            </Text>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1 },
  scroll: { padding: 20, paddingBottom: 40 },
  header: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    marginBottom: 24,
  },
  backBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: "center",
    justifyContent: "center",
    borderWidth: 1,
  },
  pageTitle: { fontSize: 20, fontWeight: "800", letterSpacing: -0.4 },
  pageSubtitle: { fontSize: 12, marginTop: 1 },
  headerIcon: {
    width: 40,
    height: 40,
    borderRadius: 14,
    alignItems: "center",
    justifyContent: "center",
  },

  successBanner: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    padding: 14,
    borderRadius: 16,
    borderWidth: 1,
    marginBottom: 16,
  },
  successIconWrap: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: "center",
    justifyContent: "center",
    flexShrink: 0,
  },
  successTitle: { fontSize: 14, fontWeight: "700" },
  successRef: {
    fontSize: 11,
    fontFamily: Platform.OS === "ios" ? "Courier" : "monospace",
    marginTop: 2,
  },

  card: {
    borderRadius: 20,
    borderWidth: 1,
    padding: 20,
    gap: 20,
    ...Shadow.sm,
  },
  cardTitle: { fontSize: 16, fontWeight: "700", marginBottom: 4 },

  field: { gap: 6 },
  label: { fontSize: 13, fontWeight: "600" },
  inputWrap: {
    flexDirection: "row",
    alignItems: "center",
    borderRadius: 14,
    borderWidth: 1.5,
    paddingHorizontal: 14,
    height: 50,
  },
  inputIcon: { marginRight: 8, flexShrink: 0 },
  currencySymbol: {
    fontSize: 16,
    fontWeight: "600",
    marginRight: 6,
    flexShrink: 0,
  },
  input: { flex: 1, fontSize: 15, height: "100%" },
  amountInput: { fontSize: 22, fontWeight: "700" },
  errorText: { fontSize: 12, color: Colors.errorMid, marginTop: 2 },
  hint: { fontSize: 11, marginTop: 2 },

  quickAmounts: { marginTop: 8 },
  quickAmountPill: {
    paddingHorizontal: 14,
    paddingVertical: 6,
    borderRadius: 20,
    borderWidth: 1,
    marginRight: 8,
  },
  quickAmountText: { fontSize: 13, fontWeight: "600" },

  submitBtn: { borderRadius: 16, overflow: "hidden", marginTop: 4 },
  submitBtnDisabled: { opacity: 0.7 },
  submitGradient: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    height: 52,
    gap: 8,
  },
  submitText: { fontSize: 16, fontWeight: "700", color: "#fff" },

  securityNote: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 6,
    marginTop: 16,
  },
  securityText: { fontSize: 12 },
});
