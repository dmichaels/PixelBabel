import SwiftUI

extension View {
    @ViewBuilder
    public func conditionalModifier<Content: View>(
        _ condition: Bool,
        apply: (Self) -> Content
    ) -> some View {
        if condition {
            apply(self)
        } else {
            self
        }
    }
}
