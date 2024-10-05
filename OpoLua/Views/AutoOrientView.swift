// Copyright (c) 2021-2024 Jason Morley, Tom Sutcliffe
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import UIKit

class AutoOrientView: UIView {
        
    var focus: CGPoint? {
        didSet {
            layoutSubviews()
        }
    }
    
    var isShowingKeyboard: Bool = false {
        didSet {
            layoutSubviews()
        }
    }

    private var contentView: UIView

    init(contentView: UIView) {
        self.contentView = contentView
        super.init(frame: .zero)
        addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let horizontalInset = max(max(max(safeAreaInsets.left,
                                          safeAreaInsets.right),
                                      layoutMargins.left),
                                  layoutMargins.right)
        let verticalInset = max(max(max(safeAreaInsets.top,
                                        safeAreaInsets.bottom),
                                    layoutMargins.top),
                                layoutMargins.bottom)
        let balancedSafeAreaInsets = UIEdgeInsets(top: verticalInset,
                                                  left: horizontalInset,
                                                  bottom: verticalInset,
                                                  right: horizontalInset)
        let frame = frame.inset(by: balancedSafeAreaInsets)
        contentView.transform = transformForSize(size: frame.size)
    }

    private func transformForSize(size: CGSize) -> CGAffineTransform {
#if targetEnvironment(macCatalyst)
        return .identity
#else
        var transform = CGAffineTransform.identity
        var screenSize = contentView.systemLayoutSizeFitting(.zero)
        let center = CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
        let focus =  focus ?? center
        
        if isShowingKeyboard {
            // If the keyboard is visible, never scale the view but instead prioritise the cursor position / focus.
            // TODO: Pick sensible scales and defaults based on the focus.
            transform = transform.concatenating(CGAffineTransform(translationX: 0, y: -(focus.y - center.y)))
            return transform
        }
            
        if size.contains(size: screenSize) {
            // The screen fits and there's nothing to do.
            return transform
        }
        
        // Only rotate the screen on the iPhone.
        if (UIDevice.current.userInterfaceIdiom == .phone &&
            UIDevice.current.orientation == .portrait &&
            !isShowingKeyboard) {
            // If our screen size is portrait, then we first apply rotation if the device screen doesn't fit.
            // We construct the transform, and then apply that effective transform to the screen size for further
            // layout operations.
            transform = transform.concatenating(CGAffineTransform(rotationAngle:  -.pi / 2))
            screenSize = CGSize(width: screenSize.height, height: screenSize.width)
        }
        
        if !size.contains(size: screenSize) {
            // If the screen still doesn't fit then we need to scale it.
            let scale = screenSize.scaleThatFits(in: size)
            transform = transform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
        }

        return transform
#endif
    }

}
