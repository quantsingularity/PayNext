import React, { useState } from "react";
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
import { Link, useRouter } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import { useAuth } from "@/contexts/AuthContext";
import { Colors, Shadow } from "@/lib/theme";

const schema = z
  .object({
    name: z.string().min(2, "Name must be at least 2 characters."),
    email: z.string().email("Please enter a valid email address."),
    password: z.string().min(8, "Password must be at least 8 characters."),
    confirmPassword: z.string(),
  })
  .refine((d) => d.password === d.confirmPassword, {
    message: "Passwords don't match.",
    path: ["confirmPassword"],
  });

type FormData = z.infer<typeof schema>;

export default function RegisterScreen() {
  const { register, login } = useAuth();
  const router = useRouter();
  const colorScheme = useColorScheme();
  const isDark = colorScheme === "dark";

  const [isLoading, setIsLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);

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
    formState: { errors },
  } = useForm<FormData>({
    resolver: zodResolver(schema),
    defaultValues: { name: "", email: "", password: "", confirmPassword: "" },
  });

  const onSubmit = async (data: FormData) => {
    setIsLoading(true);
    const success = await register(data.name, data.email, data.password);
    if (success) {
      // Auto-login after registration
      const loggedIn = await login(data.email, data.password);
      setIsLoading(false);
      if (loggedIn) {
        router.replace("/tabs");
      } else {
        Alert.alert(
          "Account Created!",
          "Please sign in with your new account.",
          [{ text: "OK", onPress: () => router.replace("/auth/login") }],
        );
      }
    } else {
      setIsLoading(false);
      Alert.alert(
        "Registration Failed",
        "Could not create account. Please try again.",
      );
    }
  };

  const fields = [
    {
      name: "name" as const,
      label: "Full Name",
      icon: "person-outline" as const,
      placeholder: "John Doe",
      keyboard: "default" as const,
      autoCapitalize: "words" as const,
      secure: false,
    },
    {
      name: "email" as const,
      label: "Email",
      icon: "mail-outline" as const,
      placeholder: "you@example.com",
      keyboard: "email-address" as const,
      autoCapitalize: "none" as const,
      secure: false,
    },
    {
      name: "password" as const,
      label: "Password",
      icon: "lock-closed-outline" as const,
      placeholder: "Min. 8 characters",
      keyboard: "default" as const,
      autoCapitalize: "none" as const,
      secure: true,
    },
    {
      name: "confirmPassword" as const,
      label: "Confirm Password",
      icon: "lock-closed-outline" as const,
      placeholder: "Re-enter password",
      keyboard: "default" as const,
      autoCapitalize: "none" as const,
      secure: true,
    },
  ];

  return (
    <SafeAreaView
      style={[styles.safe, { backgroundColor: bg }]}
      edges={["top", "bottom"]}
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
          <LinearGradient
            colors={[Colors.primary, Colors.primaryDark]}
            style={styles.hero}
          >
            <View style={styles.heroDecor1} />
            <View style={styles.heroDecor2} />
            <View style={styles.backRow}>
              <Link href="/auth/login" asChild>
                <TouchableOpacity style={styles.backBtn}>
                  <Ionicons name="arrow-back" size={20} color="#fff" />
                </TouchableOpacity>
              </Link>
            </View>
            <View style={styles.heroContent}>
              <View style={styles.logoIcon}>
                <Ionicons name="wallet" size={28} color={Colors.primary} />
              </View>
              <Text style={styles.heroTitle}>Create Account</Text>
              <Text style={styles.heroSubtitle}>
                Join thousands of PayNext users
              </Text>
            </View>
          </LinearGradient>

          {/* Form */}
          <View
            style={[
              styles.card,
              { backgroundColor: surface, borderColor: border },
            ]}
          >
            {fields.map((f) => {
              const isPassword = f.name === "password";
              const showPwd = isPassword ? showPassword : showConfirm;
              return (
                <View key={f.name} style={styles.field}>
                  <Text style={[styles.label, { color: textPrimary }]}>
                    {f.label}
                  </Text>
                  <Controller
                    control={control}
                    name={f.name}
                    render={({ field: { value, onChange, onBlur } }) => (
                      <View
                        style={[
                          styles.inputWrap,
                          {
                            backgroundColor: inputBg,
                            borderColor: errors[f.name]
                              ? Colors.errorMid
                              : border,
                          },
                        ]}
                      >
                        <Ionicons
                          name={f.icon}
                          size={18}
                          color={textSecondary}
                          style={styles.inputIcon}
                        />
                        <TextInput
                          style={[styles.input, { color: textPrimary }]}
                          placeholder={f.placeholder}
                          placeholderTextColor={textSecondary}
                          value={value}
                          onChangeText={onChange}
                          onBlur={onBlur}
                          autoCapitalize={f.autoCapitalize}
                          keyboardType={f.keyboard}
                          secureTextEntry={f.secure && !showPwd}
                        />
                        {f.secure && (
                          <TouchableOpacity
                            onPress={() =>
                              isPassword
                                ? setShowPassword(!showPassword)
                                : setShowConfirm(!showConfirm)
                            }
                            style={styles.eyeBtn}
                          >
                            <Ionicons
                              name={showPwd ? "eye-off-outline" : "eye-outline"}
                              size={18}
                              color={textSecondary}
                            />
                          </TouchableOpacity>
                        )}
                      </View>
                    )}
                  />
                  {errors[f.name] && (
                    <Text style={styles.errorText}>
                      {errors[f.name]?.message}
                    </Text>
                  )}
                </View>
              );
            })}

            {/* Terms */}
            <Text style={[styles.terms, { color: textSecondary }]}>
              By creating an account you agree to our{" "}
              <Text style={{ color: Colors.primary, fontWeight: "600" }}>
                Terms of Service
              </Text>{" "}
              and{" "}
              <Text style={{ color: Colors.primary, fontWeight: "600" }}>
                Privacy Policy
              </Text>
            </Text>

            {/* Submit */}
            <TouchableOpacity
              style={[styles.submitBtn, isLoading && { opacity: 0.7 }]}
              onPress={handleSubmit(onSubmit)}
              disabled={isLoading}
              activeOpacity={0.85}
            >
              <LinearGradient
                colors={[Colors.primary, Colors.primaryDark]}
                style={styles.submitGradient}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 0 }}
              >
                {isLoading ? (
                  <ActivityIndicator color="#fff" />
                ) : (
                  <>
                    <Text style={styles.submitText}>Create Account</Text>
                    <Ionicons
                      name="arrow-forward"
                      size={18}
                      color="rgba(255,255,255,0.8)"
                    />
                  </>
                )}
              </LinearGradient>
            </TouchableOpacity>

            {/* Login link */}
            <View style={styles.loginRow}>
              <Text style={[styles.loginPrompt, { color: textSecondary }]}>
                Already have an account?
              </Text>
              <Link href="/auth/login" asChild>
                <TouchableOpacity>
                  <Text style={[styles.loginLink, { color: Colors.primary }]}>
                    Sign In
                  </Text>
                </TouchableOpacity>
              </Link>
            </View>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1 },
  scroll: { flexGrow: 1 },

  hero: {
    paddingTop: 50,
    paddingBottom: 40,
    paddingHorizontal: 20,
    position: "relative",
    overflow: "hidden",
  },
  heroDecor1: {
    position: "absolute",
    top: -40,
    right: -40,
    width: 160,
    height: 160,
    borderRadius: 80,
    backgroundColor: "rgba(255,255,255,0.08)",
  },
  heroDecor2: {
    position: "absolute",
    bottom: -60,
    left: -60,
    width: 200,
    height: 200,
    borderRadius: 100,
    backgroundColor: "rgba(255,255,255,0.05)",
  },
  backRow: { marginBottom: 20 },
  backBtn: {
    width: 38,
    height: 38,
    borderRadius: 19,
    backgroundColor: "rgba(255,255,255,0.15)",
    alignItems: "center",
    justifyContent: "center",
  },
  heroContent: { alignItems: "center", gap: 8 },
  logoIcon: {
    width: 56,
    height: 56,
    borderRadius: 18,
    backgroundColor: "#fff",
    alignItems: "center",
    justifyContent: "center",
    ...Shadow.md,
  },
  heroTitle: {
    fontSize: 26,
    fontWeight: "900",
    color: "#fff",
    letterSpacing: -0.5,
  },
  heroSubtitle: { fontSize: 14, color: "rgba(255,255,255,0.75)" },

  card: {
    margin: 20,
    borderRadius: 24,
    borderWidth: 1,
    padding: 24,
    gap: 16,
    ...Shadow.md,
  },

  field: { gap: 6 },
  label: { fontSize: 13, fontWeight: "600" },
  inputWrap: {
    flexDirection: "row",
    alignItems: "center",
    borderRadius: 14,
    borderWidth: 1.5,
    paddingHorizontal: 14,
    height: 52,
  },
  inputIcon: { marginRight: 10, flexShrink: 0 },
  input: { flex: 1, fontSize: 15 },
  eyeBtn: { padding: 4, marginLeft: 4 },
  errorText: { fontSize: 12, color: Colors.errorMid },

  terms: { fontSize: 12, lineHeight: 18, textAlign: "center" },

  submitBtn: { borderRadius: 16, overflow: "hidden" },
  submitGradient: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    height: 54,
    gap: 10,
  },
  submitText: { fontSize: 16, fontWeight: "800", color: "#fff" },

  loginRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 6,
  },
  loginPrompt: { fontSize: 14 },
  loginLink: { fontSize: 14, fontWeight: "700" },
});
