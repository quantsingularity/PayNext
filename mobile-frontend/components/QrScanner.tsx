import React, { useState, useEffect, useRef } from "react";
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Alert,
  Dimensions,
} from "react-native";
import { Camera, CameraView } from "expo-camera";
import { Ionicons } from "@expo/vector-icons";
import { SafeAreaView } from "react-native-safe-area-context";
import { Colors } from "@/lib/theme";

const { width } = Dimensions.get("window");
const SCAN_BOX_SIZE = width * 0.65;

interface QrScannerProps {
  onScanSuccess: (data: string) => void;
  onClose: () => void;
}

export default function QrScannerScreen({
  onScanSuccess,
  onClose,
}: QrScannerProps) {
  const [hasPermission, setHasPermission] = useState<boolean | null>(null);
  const [scanned, setScanned] = useState(false);
  const [torchOn, setTorchOn] = useState(false);

  // Keep the latest onClose in a ref so the mount-only permission effect does not
  // need it as a dependency (which would re-run the permission request).
  const onCloseRef = useRef(onClose);
  onCloseRef.current = onClose;

  useEffect(() => {
    (async () => {
      const { status } = await Camera.requestCameraPermissionsAsync();
      setHasPermission(status === "granted");
      if (status !== "granted") {
        Alert.alert(
          "Camera Permission Required",
          "PayNext needs camera access to scan QR codes. Please enable it in your device settings.",
          [{ text: "OK", onPress: () => onCloseRef.current() }],
        );
      }
    })();
  }, []);

  const handleBarCodeScanned = ({ data }: { data: string }) => {
    if (scanned) return;
    setScanned(true);
    onScanSuccess(data);
  };

  if (hasPermission === null) {
    return (
      <SafeAreaView style={styles.centered}>
        <Text style={styles.permText}>Requesting camera permission…</Text>
      </SafeAreaView>
    );
  }

  if (hasPermission === false) {
    return (
      <SafeAreaView style={styles.centered}>
        <Ionicons name="camera-outline" size={48} color="#64748b" />
        <Text style={styles.permTitle}>Camera Access Denied</Text>
        <Text style={styles.permText}>
          Enable camera in Settings to scan QR codes.
        </Text>
        <TouchableOpacity style={styles.closeBtn} onPress={onClose}>
          <Text style={styles.closeBtnText}>Close</Text>
        </TouchableOpacity>
      </SafeAreaView>
    );
  }

  return (
    <View style={styles.container}>
      {/* Camera */}
      <CameraView
        style={StyleSheet.absoluteFillObject}
        facing="back"
        enableTorch={torchOn}
        onBarcodeScanned={scanned ? undefined : handleBarCodeScanned}
        barcodeScannerSettings={{ barcodeTypes: ["qr"] }}
      />

      {/* Overlay */}
      <View style={styles.overlay}>
        {/* Top bar */}
        <SafeAreaView edges={["top"]} style={styles.topBar}>
          <TouchableOpacity style={styles.iconBtn} onPress={onClose}>
            <Ionicons name="close" size={24} color="#fff" />
          </TouchableOpacity>
          <Text style={styles.title}>Scan QR Code</Text>
          <TouchableOpacity
            style={styles.iconBtn}
            onPress={() => setTorchOn(!torchOn)}
          >
            <Ionicons
              name={torchOn ? "flash" : "flash-outline"}
              size={24}
              color={torchOn ? "#fbbf24" : "#fff"}
            />
          </TouchableOpacity>
        </SafeAreaView>

        <Text style={styles.instruction}>
          Point your camera at a PayNext QR code
        </Text>

        {/* Scan frame */}
        <View style={styles.scanFrameWrap}>
          <View
            style={[
              styles.scanFrame,
              { width: SCAN_BOX_SIZE, height: SCAN_BOX_SIZE },
            ]}
          >
            {/* Corner accents */}
            {[
              styles.cornerTL,
              styles.cornerTR,
              styles.cornerBL,
              styles.cornerBR,
            ].map((cornerStyle, i) => (
              <View key={i} style={cornerStyle} />
            ))}
          </View>
        </View>

        {/* Bottom actions */}
        <SafeAreaView edges={["bottom"]} style={styles.bottomBar}>
          {scanned && (
            <TouchableOpacity
              style={styles.rescanBtn}
              onPress={() => setScanned(false)}
              activeOpacity={0.8}
            >
              <Ionicons name="refresh" size={18} color="#fff" />
              <Text style={styles.rescanText}>Tap to Scan Again</Text>
            </TouchableOpacity>
          )}
        </SafeAreaView>
      </View>
    </View>
  );
}

const CORNER_SIZE = 24;
const CORNER_THICKNESS = 3;
const CORNER_COLOR = Colors.primary;
const CORNER_RADIUS = 4;

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#000" },
  centered: {
    flex: 1,
    backgroundColor: "#0f172a",
    alignItems: "center",
    justifyContent: "center",
    gap: 16,
    padding: 24,
  },
  permTitle: { fontSize: 18, fontWeight: "700", color: "#fff" },
  permText: { fontSize: 14, color: "#94a3b8", textAlign: "center" },
  closeBtn: {
    marginTop: 8,
    paddingHorizontal: 24,
    paddingVertical: 12,
    backgroundColor: Colors.primary,
    borderRadius: 12,
  },
  closeBtnText: { color: "#fff", fontWeight: "700", fontSize: 15 },

  overlay: { ...StyleSheet.absoluteFillObject, alignItems: "center" },

  topBar: {
    width: "100%",
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  iconBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: "rgba(0,0,0,0.4)",
    alignItems: "center",
    justifyContent: "center",
  },
  title: { fontSize: 17, fontWeight: "700", color: "#fff" },

  instruction: {
    color: "rgba(255,255,255,0.8)",
    fontSize: 14,
    textAlign: "center",
    marginVertical: 16,
    paddingHorizontal: 40,
  },

  scanFrameWrap: { flex: 1, alignItems: "center", justifyContent: "center" },
  scanFrame: { position: "relative" },

  // Corner pieces
  cornerTL: {
    position: "absolute",
    top: 0,
    left: 0,
    width: CORNER_SIZE,
    height: CORNER_SIZE,
    borderTopWidth: CORNER_THICKNESS,
    borderLeftWidth: CORNER_THICKNESS,
    borderColor: CORNER_COLOR,
    borderTopLeftRadius: CORNER_RADIUS,
  },
  cornerTR: {
    position: "absolute",
    top: 0,
    right: 0,
    width: CORNER_SIZE,
    height: CORNER_SIZE,
    borderTopWidth: CORNER_THICKNESS,
    borderRightWidth: CORNER_THICKNESS,
    borderColor: CORNER_COLOR,
    borderTopRightRadius: CORNER_RADIUS,
  },
  cornerBL: {
    position: "absolute",
    bottom: 0,
    left: 0,
    width: CORNER_SIZE,
    height: CORNER_SIZE,
    borderBottomWidth: CORNER_THICKNESS,
    borderLeftWidth: CORNER_THICKNESS,
    borderColor: CORNER_COLOR,
    borderBottomLeftRadius: CORNER_RADIUS,
  },
  cornerBR: {
    position: "absolute",
    bottom: 0,
    right: 0,
    width: CORNER_SIZE,
    height: CORNER_SIZE,
    borderBottomWidth: CORNER_THICKNESS,
    borderRightWidth: CORNER_THICKNESS,
    borderColor: CORNER_COLOR,
    borderBottomRightRadius: CORNER_RADIUS,
  },

  bottomBar: {
    width: "100%",
    paddingHorizontal: 24,
    paddingBottom: 40,
    alignItems: "center",
  },
  rescanBtn: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    backgroundColor: Colors.primary,
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 24,
  },
  rescanText: { color: "#fff", fontWeight: "700", fontSize: 15 },
});
