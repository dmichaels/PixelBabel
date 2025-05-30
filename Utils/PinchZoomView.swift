import SwiftUI
import UIKit

// TODO
// Have not used this yet. Straight from ChatGPT.
// Supposedly how to take finger position into account with zoom gesutures.
//
//  struct ContentView: View {
//      @State private var zoom: CGFloat = 1.0
//      @State private var anchor: CGPoint = .zero
//  
//      var body: some View {
//          ZStack {
//              Image("example")
//                  .resizable()
//                  .aspectRatio(contentMode: .fit)
//                  .scaleEffect(zoom, anchor: UnitPoint(x: anchor.x, y: anchor.y))
//  
//              PinchZoomView { scale, location, state in
//                  switch state {
//                  case .began, .changed:
//                      zoom = scale
//                      anchor = UnitPoint(x: location.x / UIScreen.main.bounds.width,
//                                         y: location.y / UIScreen.main.bounds.height)
//                  case .ended:
//                      // Optionally finalize state
//                      break
//                  default:
//                      break
//                  }
//              }
//          }
//      }
//  }
//
struct PinchZoomView: UIViewRepresentable {
    var onPinch: (CGFloat, CGPoint, UIGestureRecognizer.State) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let pinch = UIPinchGestureRecognizer(target: context.coordinator,
                                             action: #selector(Coordinator.handlePinch(_:)))
        view.addGestureRecognizer(pinch)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPinch: onPinch)
    }

    class Coordinator: NSObject {
        var onPinch: (CGFloat, CGPoint, UIGestureRecognizer.State) -> Void

        init(onPinch: @escaping (CGFloat, CGPoint, UIGestureRecognizer.State) -> Void) {
            self.onPinch = onPinch
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            let scale = recognizer.scale
            let location = recognizer.location(in: recognizer.view)
            onPinch(scale, location, recognizer.state)
        }
    }
}
