import XCTest
import SwiftUI
import UIKit
@testable import LockIn

// Render review artifacts at constrained sizes, without manufacturing Screen Time
// tokens or treating an unsigned simulator as proof of real-device enforcement.
@MainActor
final class UpdateLayoutTests: XCTestCase {
    func testCaptureCompactAndLargeRestrictionsLayouts() async throws {
        for (label, size) in [("compact", CGSize(width: 320, height: 568)),
                              ("large", CGSize(width: 440, height: 956))] {
            let model = AppModel()
            let timekeeper = TimekeeperController()
            let root = RootView().environmentObject(model).environmentObject(timekeeper)
            try await capture(root, size: size, name: "restrictions_\(label)") {
                model.lastError = nil // The unsigned host has no App Group entitlement.
            }
        }
    }

    func testCaptureAccessibleRestrictionsLayout() async throws {
        let model = AppModel()
        let root = RootView().environmentObject(model).environmentObject(TimekeeperController())
            .environment(\.dynamicTypeSize, .accessibility3)
        try await capture(root, size: CGSize(width: 320, height: 568), name: "restrictions_accessible") {
            model.lastError = nil
        }
    }

    func testCaptureMiniGameIconLayouts() async throws {
        for (label, size) in [("compact", CGSize(width: 320, height: 568)),
                              ("large", CGSize(width: 440, height: 956))] {
            try await capture(NavigationStack { MiniGamesView() }, size: size, name: "minigames_\(label)")
        }
        try await capture(PushupChallengeIcon().frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black).ignoresSafeArea(), size: CGSize(width: 100, height: 100), name: "pushup_icon")
    }

    func testCaptureActualUnlockLabelWithAccessibleText() async throws {
        // The real label/style, without inventing protected Screen Time tokens.
        let button = Button("Temporary unlock") {}.buttonStyle(LockInPrimaryButtonStyle())
            .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .background(.black).environment(\.dynamicTypeSize, .accessibility3)
        try await capture(button, size: CGSize(width: 320, height: 240), name: "unlock_button_accessible")
    }

    private func capture<V: View>(_ root: V, size: CGSize, name: String,
                                  clearUnsignedError: () -> Void = {}) async throws {
            let host = UIHostingController(rootView: root)
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(origin: .zero, size: size)
            window.rootViewController = host
            window.overrideUserInterfaceStyle = .dark
            window.makeKeyAndVisible()
            window.frame = CGRect(origin: .zero, size: size)
            host.view.frame = window.bounds
            try await Task.sleep(for: .seconds(1))
            clearUnsignedError()
            try await Task.sleep(for: .seconds(1))
            window.layoutIfNeeded()
            var rendered = false
            let image = UIGraphicsImageRenderer(size: size).image { _ in
                rendered = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            XCTAssertTrue(rendered, "The visible view hierarchy must be rendered, not an empty layer snapshot.")
            let data = try XCTUnwrap(image.pngData())
            XCTAssertGreaterThan(data.count, 1000)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("20261122_v1_\(name).png")
            try data.write(to: url, options: .atomic)
            print("Layout review artifact: \(url.path)")
            let attachment = XCTAttachment(image: image)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
            window.isHidden = true
    }
}
