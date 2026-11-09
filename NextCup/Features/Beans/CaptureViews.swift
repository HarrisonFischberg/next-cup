import AVFoundation
import SwiftUI
import UIKit
import VisionKit

/// Whether this device can take a photo (the Simulator cannot).
enum Camera {
  static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }
}

/// The system camera. Returns JPEG data, or nil when the user cancels.
struct CameraPicker: UIViewControllerRepresentable {
  let onFinish: (Data?) -> Void

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.delegate = context.coordinator
    return picker
  }

  func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
  func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

  final class Coordinator: NSObject, UIImagePickerControllerDelegate,
    UINavigationControllerDelegate
  {
    let onFinish: (Data?) -> Void
    init(onFinish: @escaping (Data?) -> Void) { self.onFinish = onFinish }

    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      onFinish((info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.85))
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onFinish(nil) }
  }
}

/// Whether live barcode scanning works here: needs a camera, a supported device and permission.
enum BarcodeScanner {
  @MainActor static var isAvailable: Bool {
    DataScannerViewController.isSupported && DataScannerViewController.isAvailable
  }

  /// `isAvailable` is false until camera access is granted, so ask first on a supported device.
  @MainActor static func requestIfNeeded() async -> Bool {
    if DataScannerViewController.isSupported,
      AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined
    {
      _ = await AVCaptureDevice.requestAccess(for: .video)
    }
    return isAvailable
  }
}

/// What the live scanner read off the bag.
enum ScannedCode: Equatable {
  /// A retail barcode's digits.
  case barcode(String)
  /// A QR code's text, usually a link to the roaster's page for the coffee.
  case qr(String)
}

/// Full-screen live scanner for retail barcodes (EAN-8, EAN-13, UPC-E) and QR codes.
/// Returns the first code it reads; nothing is looked up until it does.
struct BarcodeScannerView: View {
  let onCode: (ScannedCode) -> Void
  let onCancel: () -> Void

  var body: some View {
    ZStack(alignment: .bottom) {
      ScannerRepresentable(onCode: onCode).ignoresSafeArea()
      VStack(spacing: DS.Space.md) {
        Text("Point at the barcode or QR code on the bag")
          .font(.headline).foregroundStyle(.white)
          .padding(.horizontal, DS.Space.lg).padding(.vertical, DS.Space.sm)
          .background(.black.opacity(0.55), in: Capsule())
        Button("Cancel", action: onCancel)
          .font(.body.weight(.semibold)).foregroundStyle(.white)
          .frame(minWidth: 120, minHeight: DS.Size.control)
          .background(.black.opacity(0.55), in: Capsule())
          .accessibilityIdentifier("beans.scanner.cancel")
      }
      .padding(.bottom, DS.Space.xxl)
    }
  }
}

private struct ScannerRepresentable: UIViewControllerRepresentable {
  let onCode: (ScannedCode) -> Void

  func makeUIViewController(context: Context) -> DataScannerViewController {
    let scanner = DataScannerViewController(
      recognizedDataTypes: [.barcode(symbologies: [.ean8, .ean13, .upce, .qr])],
      qualityLevel: .balanced, isHighlightingEnabled: true)
    scanner.delegate = context.coordinator
    return scanner
  }

  // Scanning starts once the controller is on screen; starting it in make can silently fail.
  func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
    guard !controller.isScanning, !context.coordinator.done else { return }
    Task { @MainActor in try? controller.startScanning() }
  }
  func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

  @MainActor final class Coordinator: NSObject, DataScannerViewControllerDelegate {
    let onCode: (ScannedCode) -> Void
    private(set) var done = false
    init(onCode: @escaping (ScannedCode) -> Void) { self.onCode = onCode }

    func dataScanner(
      _ scanner: DataScannerViewController, didAdd items: [RecognizedItem],
      allItems: [RecognizedItem]
    ) {
      guard !done else { return }
      for case .barcode(let code) in items {
        guard let value = code.payloadStringValue else { continue }
        done = true
        scanner.stopScanning()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onCode(code.observation.symbology == .qr ? .qr(value) : .barcode(value))
        return
      }
    }
  }
}

/// One step of the AI flow, shown before its scanner or camera opens: what to point at, with
/// Continue, Skip and Stop.
struct FlowPromptView: View {
  let step: BeanFlowStep
  let onContinue: () -> Void
  let onSkip: () -> Void
  let onStop: () -> Void

  private var content: (symbol: String, title: String, detail: String, skip: String) {
    switch step {
    case .barcode:
      (
        "barcode.viewfinder", "Scan the barcode", "Point the camera at the barcode on the bag.",
        "No barcode, skip"
      )
    case .qr:
      (
        "qrcode.viewfinder", "Scan the QR code",
        "Many roasters print one that links to the coffee's page.",
        "No QR code, skip"
      )
    case .front:
      (
        "camera.viewfinder", "Scan the front of the bag", "Fit the whole label in the photo.",
        "Skip"
      )
    case .back, .reading:
      (
        "camera.viewfinder", "Scan the back of the bag",
        "Tasting notes, origin and roast date are often printed here.", "Skip"
      )
    }
  }

  var body: some View {
    let c = content
    VStack(spacing: DS.Space.lg) {
      Text("Step \(step.rawValue + 1) of 4").font(DS.Font.label).foregroundStyle(DS.ink2)
      Image(systemName: c.symbol).font(.system(size: 56)).foregroundStyle(DS.signal)
        .accessibilityHidden(true)
      VStack(spacing: DS.Space.xs) {
        Text(c.title).font(DS.Font.headline).foregroundStyle(DS.ink)
          .accessibilityAddTraits(.isHeader)
        Text(c.detail).font(.body).foregroundStyle(DS.ink2).multilineTextAlignment(.center)
      }
      VStack(spacing: DS.Space.sm) {
        SteelButton(title: "Continue", action: onContinue)
          .accessibilityIdentifier("beans.flow.continue")
        SteelButton(title: c.skip, kind: .secondary, action: onSkip)
          .accessibilityIdentifier("beans.flow.skip")
        Button("Stop the AI flow", action: onStop)
          .frame(minHeight: DS.Size.minTap)
          .accessibilityIdentifier("beans.flow.stop")
      }
    }
    .padding(DS.Space.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DS.bg)
    .presentationDetents([.medium, .large])
    .interactiveDismissDisabled()
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("beans.flow.prompt")
  }
}

/// While the AI flow reads the bag: the brewing cup and what is happening, with Cancel.
struct BrewingBeansView: View {
  let cancel: () -> Void

  var body: some View {
    VStack(spacing: DS.Space.lg) {
      Spacer()
      BrewingCupView().frame(maxWidth: 200)
      VStack(spacing: DS.Space.xs) {
        Text("Brewing up your fresh beans").font(DS.Font.headline).foregroundStyle(DS.ink)
        Text(
          DirectAI.cloudProviderTitle.map { "Reading your bag with \($0)." }
            ?? "Reading your bag on this iPhone."
        )
        .font(.body).foregroundStyle(DS.ink2)
      }
      .multilineTextAlignment(.center)
      .accessibilityElement(children: .combine)
      Spacer()
      Button("Cancel", action: cancel).frame(minHeight: DS.Size.minTap)
        .accessibilityIdentifier("beans.flow.brewing.cancel")
    }
    .padding(DS.Space.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DS.bg)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("beans.flow.brewing")
  }
}
