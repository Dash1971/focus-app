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
            model.lastError = nil // The unsigned host has no App Group entitlement.
            try await Task.sleep(for: .seconds(1))
            window.layoutIfNeeded()
            var rendered = false
            let image = UIGraphicsImageRenderer(size: size).image { _ in
                rendered = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            XCTAssertTrue(rendered, "The visible view hierarchy must be rendered, not an empty layer snapshot.")
            let data = try XCTUnwrap(image.pngData())
            XCTAssertGreaterThan(data.count, 1000)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("20261122_v0_restrictions_\(label).png")
            try data.write(to: url, options: .atomic)
            print("Layout review artifact: \(url.path)")
            let attachment = XCTAttachment(image: image)
            attachment.name = "Restrictions \(label)"
            attachment.lifetime = .keepAlways
            add(attachment)
            window.isHidden = true
        }
    }
}
