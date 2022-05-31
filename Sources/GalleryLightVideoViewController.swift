//
// GalleryLightVideoViewController
// LegacyGallery
//
// Copyright (c) 2018 Eugene Egorov.
// License: MIT, https://github.com/eugeneego/legacy/blob/master/LICENSE
//

import UIKit
import AVFoundation

open class GalleryLightVideoViewController: GalleryItemViewController {
    public let video: GalleryMedia.Video
    private var source: GalleryMedia.VideoSource?
    private var previewImage: UIImage?

    open var loop: Bool = true

    open var setupAppearance: ((GalleryLightVideoViewController) -> Void)?

    private var isShown: Bool = false
    private var isStarted: Bool = false

    public let videoView: GalleryVideoView = GalleryVideoView()
    public let previewImageView: UIImageView = UIImageView()
    public let progressView: UIProgressView = UIProgressView(progressViewStyle: .default)

    public init(video: GalleryMedia.Video) {
        self.video = video
        source = video.source
        previewImage = video.previewImage

        super.init(nibName: nil, bundle: nil)
    }

    required public init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override open func viewDidLoad() {
        super.viewDidLoad()

        videoView.clipsToBounds = true
        videoView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(videoView)

        previewImageView.contentMode = .scaleAspectFit
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewImageView)

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.trackTintColor = .clear
        view.addSubview(progressView)

        // Constraints

        NSLayoutConstraint.activate([
            videoView.topAnchor.constraint(equalTo: view.topAnchor),
            videoView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            videoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewImageView.topAnchor.constraint(equalTo: view.topAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            previewImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),
            progressView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        // Other

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
        } else {
            play()
        }
    }

    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        pause()
    }

    // MARK: - Controls

    open override func toggleTap() {
        super.toggleTap()

        if controlsVisibility {
            pause()
        } else {
            play()
        }
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

        player.actionAtItemEnd = .none
        videoView.player = player

        let interval = CMTime(seconds: 0.016, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) { [weak self] _ in
            self?.updatePlaybackProgress()
        }

        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playbackEnded), name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem)

        updateControls()

        previewImageView.isHidden = true

        if !isTransitioning && autoplay {
            play()
        }
    }

    private func play() {
        previewImageView.isHidden = true
        videoView.isHidden = false
        isStarted = true
        videoView.player?.play()
    }

    private func pause() {
        videoView.player?.pause()
    }

    private func updatePlaybackProgress() {
        let item = videoView.player?.currentItem
        let time = item?.currentTime()
        let duration = item?.duration
        if let time = time, time.isValid, !time.isIndefinite, let duration = duration, duration.isValid, !duration.isIndefinite {
            progressView.progress = Float(time.seconds / duration.seconds)
        } else {
            progressView.progress = 0
        }
    }

    @objc private func playbackEnded(_ notification: Notification) {
        (notification.object as? AVPlayerItem)?.seek(to: .zero, completionHandler: nil)
        if !loop {
            pause()
        }
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
        guard let item = videoView.player?.currentItem else { return }

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

        let controller = UIActivityViewController(activityItems: [sourceUrl], applicationActivities: nil)
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
        videoView.isHidden = hide
    }
}
