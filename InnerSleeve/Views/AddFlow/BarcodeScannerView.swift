import SwiftUI
#if canImport(VisionKit)
import VisionKit
#endif

struct BarcodeScannerView: View {
    @State private var manualBarcode = ""
    var onBarcode: (String) -> Void

    var body: some View {
        VStack(spacing: 18) {
            #if canImport(VisionKit) && !targetEnvironment(simulator)
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                BarcodeScannerRepresentable(onBarcode: onBarcode)
            } else {
                manualFallback
            }
            #else
            manualFallback
            #endif
        }
        .navigationTitle("Scan barcode")
    }

    private var manualFallback: some View {
        VStack(spacing: 14) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 42))
                .foregroundStyle(Palette.inkOnStage.opacity(0.45))
            TextField("Barcode", text: $manualBarcode)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 24)
            Button {
                onBarcode(manualBarcode)
            } label: {
                Label("Use barcode", systemImage: "checkmark")
            }
            .buttonStyle(.glassProminent)
            .tint(Palette.orangeAccent)
            .disabled(manualBarcode.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

#if canImport(VisionKit) && !targetEnvironment(simulator)
private struct BarcodeScannerRepresentable: UIViewControllerRepresentable {
    var onBarcode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcode: onBarcode)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onBarcode: (String) -> Void
        private var didRead = false

        init(onBarcode: @escaping (String) -> Void) {
            self.onBarcode = onBarcode
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            read(item)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            addedItems.first.map(read)
        }

        private func read(_ item: RecognizedItem) {
            guard !didRead else { return }
            if case let .barcode(barcode) = item, let payload = barcode.payloadStringValue {
                didRead = true
                onBarcode(payload)
            }
        }
    }
}
#endif
