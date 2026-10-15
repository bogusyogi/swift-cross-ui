#if canImport(AppKitBackend)
    import AppKit
    import Testing

    @testable import AppKitBackend
    @testable @_spi(Backends) import SwiftCrossUI

    @Suite("Testing for custom views")
    @MainActor
    struct ViewTests {
        @Test(
            "Custom bodies preserve hover targets",
            .bug("https://github.com/moreSwift/swift-cross-ui/issues/789"),
            arguments: [false, true]
        )
        func hoverTarget(multipleChildren: Bool) throws {
            let backend = AppKitBackend()
            let window = makeWindow()
            defer { window.close() }
            let environment = EnvironmentValues(backend: backend).with(\.window, window)
            var events: [String] = []
            let view = HoverBody(content: content(multipleChildren: multipleChildren)) { hovering in
                events.append("initial: \(hovering)")
            }
            let node = ViewGraphNode(for: view, backend: backend, environment: environment)
            window.contentView = node.widget

            _ = node.computeLayout(proposedSize: .unspecified, environment: environment)
            let layout = node.commit()
            #expect(layout.size == expectedSize(multipleChildren: multipleChildren))
            #expect(node.widget.subviews.count == 2)
            let target = try #require(node.widget.subviews.last as? NSCustomHoverTarget)
            target.hoverChangesHandler?(true)
            #expect(events == ["initial: true"])

            let updatedView = HoverBody(content: content(multipleChildren: multipleChildren)) {
                hovering in
                events.append("updated: \(hovering)")
            }
            _ = node.computeLayout(
                with: updatedView,
                proposedSize: .unspecified,
                environment: environment
            )
            let updatedLayout = node.commit()
            #expect(updatedLayout.size == layout.size)
            #expect(node.widget.subviews.count == 2)
            #expect(node.widget.subviews.last === target)
            target.hoverChangesHandler?(false)
            #expect(events == ["initial: true", "updated: false"])
        }

        @Test(
            "Custom bodies preserve tap targets",
            .bug("https://github.com/moreSwift/swift-cross-ui/issues/789"),
            arguments: [false, true]
        )
        func tapTarget(multipleChildren: Bool) throws {
            let backend = AppKitBackend()
            let window = makeWindow()
            defer { window.close() }
            let environment = EnvironmentValues(backend: backend).with(\.window, window)
            var events: [String] = []
            let view = TapBody(content: content(multipleChildren: multipleChildren)) {
                events.append("initial")
            }
            let node = ViewGraphNode(for: view, backend: backend, environment: environment)
            window.contentView = node.widget

            _ = node.computeLayout(proposedSize: .unspecified, environment: environment)
            let layout = node.commit()
            #expect(layout.size == expectedSize(multipleChildren: multipleChildren))
            #expect(node.widget.subviews.count == 2)
            let target = try #require(node.widget.subviews.last as? NSCustomTapGestureTarget)
            target.leftClick()
            #expect(events == ["initial"])

            let updatedView = TapBody(content: content(multipleChildren: multipleChildren)) {
                events.append("updated")
            }
            _ = node.computeLayout(
                with: updatedView,
                proposedSize: .unspecified,
                environment: environment
            )
            let updatedLayout = node.commit()
            #expect(updatedLayout.size == layout.size)
            #expect(node.widget.subviews.count == 2)
            #expect(node.widget.subviews.last === target)
            target.leftClick()
            #expect(events == ["initial", "updated"])
        }

        private func makeWindow() -> AppKitBackend.Window {
            // Avoid frame autosaving and presentation in backend.createWindow.
            let window = AppKitBackend.Window(
                contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                styleMask: .borderless,
                backing: .buffered,
                defer: true
            )
            window.isReleasedWhenClosed = false
            return window
        }

        @ViewBuilder
        private func content(multipleChildren: Bool) -> some View {
            if multipleChildren {
                VStack(spacing: 5) {
                    Color.red.frame(width: 20, height: 30)
                    Color.blue.frame(width: 40, height: 10)
                }
            } else {
                Color.red.frame(width: 20, height: 30)
            }
        }

        private func expectedSize(multipleChildren: Bool) -> ViewSize {
            multipleChildren ? ViewSize(40, 45) : ViewSize(20, 30)
        }
    }

    private struct HoverBody<Content: View>: View {
        var content: Content
        var action: (Bool) -> Void

        var body: some View {
            // An explicit return leaves the modifier as the body's root.
            return content.onHover(perform: action)
        }
    }

    private struct TapBody<Content: View>: View {
        var content: Content
        var action: () -> Void

        var body: some View {
            return content.onTapGesture(perform: action)
        }
    }
#endif
