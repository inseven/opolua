// Copyright (c) 2021-2025 Jason Morley, Tom Sutcliffe
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

import Combine
import UIKit

import OpoLuaCore

class SoundViewController: UIViewController {

    enum State {
        case idle
        case playing
    }

    private let url: URL
    private var cancellable: Cancellable?

    private var state = State.idle {
        didSet {
            dispatchPrecondition(condition: .onQueue(.main))
            switch state {
            case .idle:
                playButton.isHidden = false
                pauseButton.isHidden = true
            case .playing:
                pauseButton.isHidden = false
                playButton.isHidden = true
            }
        }
    }

    lazy var playButton: UIButton = {
        var configuration = UIButton.Configuration.borderedTinted()
        configuration.image = UIImage(systemName: "play.fill",
                                      withConfiguration: UIImage.SymbolConfiguration(pointSize: 48))
        configuration.cornerStyle = .capsule
        configuration.buttonSize = .large
        let button = UIButton(configuration: configuration, primaryAction: UIAction() { [weak self] action in
            guard let self = self else {
                return
            }
            self.play()
        })
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    lazy var pauseButton: UIButton = {
        var configuration = UIButton.Configuration.borderedTinted()
        configuration.image = UIImage(systemName: "pause.fill",
                                      withConfiguration: UIImage.SymbolConfiguration(pointSize: 48))
        configuration.cornerStyle = .capsule
        configuration.buttonSize = .large
        let button = UIButton(configuration: configuration, primaryAction: UIAction() { [weak self] action in
            guard let self = self else {
                return
            }
            self.pause()
        })
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
        title = url.localizedName
        view.backgroundColor = .systemBackground

        pauseButton.isHidden = true

        view.addSubview(playButton)
        view.addSubview(pauseButton)
        NSLayoutConstraint.activate([
            playButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            pauseButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pauseButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        cancellable?.cancel()
        cancellable = nil
    }

    func play() {
        state = .playing
        do {
            let env = PsiLuaEnv()
            let fileInfo = env.getFileInfo(path: url.path)
            guard case PsiLuaEnv.FileInfo.sound(let soundFile) = fileInfo else {
                throw OpoLuaError.unsupportedFile
            }
            cancellable = Sound.play(data: soundFile.data) { [weak self] error in
                DispatchQueue.main.async {
                    guard let self = self else {
                        return
                    }
                    self.state = .idle
                    if let error = error {
                        self.present(error: error)
                    }
                }
            }
        } catch {
            self.present(error: error)
        }
    }

    func pause() {
        cancellable?.cancel()
    }

}
