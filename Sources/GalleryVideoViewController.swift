//
// GalleryVideoViewController
// LegacyGallery
//
// Copyright (c) 2016 Eugene Egorov.
// License: MIT, https://github.com/eugeneego/legacy/blob/master/LICENSE
//

import UIKit
import AVKit
import AVFoundation

open class GalleryVideoViewController: GalleryItemViewController {
    public let video: GalleryMedia.Video
    private var source: GalleryMedia.VideoSource?
    private var previewImage: UIImage?

    open var setupAppearance: ((GalleryVideoViewController) -> Void)?

    private var isShown: Bool = false
    private var isStarted: Bool = false

    public let playerController: AVPlayerViewController = AVPlayerViewController()
    public let previewImageView: UIImageView = UIImageView()

    public init(video: GalleryMedia.Video) {
        self.video = video
        source = video.source
        previewImage = video.previewImage

        super.init(nibName: nil, bundle: nil)
    }

    required public init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    override open func viewDidLoad() {
        super.viewDidLoad()

        // Video Player

        addChild(playerController)

        playerController.view.translatesAutoresizingMaskIntoConstraints = false
        playerController.showsPlaybackControls = false
        view.addSubview(playerController.view)

        previewImageView.contentMode = .scaleAspectFit
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewImageView)

        // Constraints

        NSLayoutConstraint.activate([
            // Adding an inset to the top constraint to avoid AVPlayerViewController's bugs of fullscreen determination.
            playerController.view.topAnchor.constraint(equalTo: view.topAnchor, constant: topInset),
            playerController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            playerController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewImageView.topAnchor.constraint(equalTo: view.topAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            previewImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        // Other

        playerController.didMove(toParent: self)

        setupTransition()
        setupCommonControls()
        setupAppearance?(self)

        updatePreviewImage()
    }

    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !isShown {
            isShown = true
            load()
        }
    }

    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        pause()
    }

    // MARK: - Logic

    private func load() {
        if let source = source {
            load(source: source)
        } else if let videoLoader = video.videoLoader {
            loadingIndicatorView.startAnimating()
            Task { [weak self] in
                let result = await videoLoader()
                self?.loadingIndicatorView.stopAnimating()
                if case .success(let source) = result {
                    self?.load(source: source)
                }
            }
        }
    }

    private func load(source: GalleryMedia.VideoSource) {
        self.source = source

        let player: AVPlayer
        switch source {
            case .url(let url):
                player = AVPlayer(url: url)
            case .asset(let asset):
                player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
            case .playerItem(let playerItem):
                player = AVPlayer(playerItem: playerItem)
        }

        playerController.player = player
        playerController.showsPlaybackControls = true

        updateControls()

        previewImageView.isHidden = true

        if !isTransitioning && autoplay {
            play()
        }
    }

    private func play() {
        previewImageView.isHidden = true
        playerController.showsPlaybackControls = true
        playerController.view.isHidden = false
        isStarted = true
        playerController.player?.play()
    }

    private func pause() {
        playerController.player?.pause()
    }

    private func updatePreviewImage() {
        if let previewImage = previewImage {
            previewImageView.image = previewImage
            mediaSize = previewImage.size
        } else if let previewImageLoader = video.previewImageLoader {
            Task { [weak self] in
                let result = await previewImageLoader(.zero)
                if case .success(let image) = result {
                    self?.previewImage = image
                    self?.previewImageView.image = image
                    self?.mediaSize = image.size
                }
            }
        }
    }

    private func generatePreview() {
        guard let item = playerController.player?.currentItem else { return }

        let asset = item.asset
        let time = item.currentTime()
        if let image = generateVideoPreview(asset: asset, time: time, exact: true) {
            previewImage = image
            updatePreviewImage()
        }
    }

    private func generateVideoPreview(asset: AVAsset, time: CMTime = .zero, exact: Bool = false) -> UIImage? {
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        if exact {
            imageGenerator.requestedTimeToleranceBefore = .zero
            imageGenerator.requestedTimeToleranceAfter = .zero
        }
        let cgImage = try? imageGenerator.copyCGImage(at: time, actualTime: nil)
        let image = cgImage.map(UIImage.init)
        return image
    }

    // MARK: - Controls

    open var sourceUrl: URL? {
        switch source {
            case .url(let url):
                return url
            case .asset(let asset):
                return (asset as? AVURLAsset)?.url
            case .playerItem(let playerItem):
                return (playerItem.asset as? AVURLAsset)?.url
            case nil:
                return nil
        }
    }

    open override var isShareAvailable: Bool {
        sourceUrl?.isFileURL ?? false
    }

    open override func closeTap() {
        pause()
        generatePreview()

        super.closeTap()
    }

    open override func shareTap() {
        guard let sourceUrl = sourceUrl else { return }

        let controller = UIActivityViewController(activityItems: [ sourceUrl ], applicationActivities: nil)
        present(controller, animated: true, completion: nil)
    }

    // MARK: - Transition

    open override func zoomTransitionPrepareAnimatingView(_ animatingImageView: UIImageView) {
        super.zoomTransitionPrepareAnimatingView(animatingImageView)

        animatingImageView.image = previewImage

        var frame: CGRect = .zero

        if mediaSize.width > 0.1 && mediaSize.height > 0.1 {
            let imageFrame = previewImageView.frame
            let widthRatio = imageFrame.width / mediaSize.width
            let heightRatio = imageFrame.height / mediaSize.height
            let ratio = min(widthRatio, heightRatio)

            let size = CGSize(width: mediaSize.width * ratio, height: mediaSize.height * ratio)
            let position = CGPoint(
                x: imageFrame.origin.x + (imageFrame.width - size.width) / 2,
                y: imageFrame.origin.y + (imageFrame.height - size.height) / 2
            )
            frame = CGRect(origin: position, size: size)
        }

        animatingImageView.frame = frame
    }

    open override func zoomTransitionOnStart() {
        super.zoomTransitionOnStart()

        pause()
        generatePreview()
    }

    open override func zoomTransitionHideViews(hide: Bool) {
        super.zoomTransitionHideViews(hide: hide)

        if !isStarted {
            previewImageView.isHidden = hide
        }
        playerController.view.isHidden = hide
    }
}
