//
// GalleryMedia
// LegacyGallery
//
// Copyright (c) 2016 Eugene Egorov.
// License: MIT, https://github.com/eugeneego/legacy/blob/master/LICENSE
//

import UIKit
import AVFoundation

public enum GalleryMedia {
    case image(Image)
    case video(Video)

    public typealias PreviewImageLoader = (_ size: CGSize, _ completion: @escaping (Result<UIImage, Error>) -> Void) -> Void
    public typealias FullImageLoader = (_ completion: @escaping (Result<UIImage, Error>) -> Void) -> Void
    public typealias VideoLoader = (_ completion: @escaping (Result<VideoSource, Error>) -> Void) -> Void

    public enum VideoSource {
        case url(URL)
        case asset(AVAsset)
        case playerItem(AVPlayerItem)
    }

    public struct Image {
        public var previewImage: UIImage?
        public var previewImageLoader: PreviewImageLoader?
        public var fullImage: UIImage?
        public var fullImageLoader: FullImageLoader?

        public init(
            previewImage: UIImage? = nil,
            previewImageLoader: PreviewImageLoader? = nil,
            fullImage: UIImage? = nil,
            fullImageLoader: FullImageLoader? = nil
        ) {
            self.previewImage = previewImage
            self.previewImageLoader = previewImageLoader
            self.fullImage = fullImage
            self.fullImageLoader = fullImageLoader
        }
    }

    public struct Video {
        public var source: VideoSource?
        public var previewImage: UIImage?
        public var previewImageLoader: PreviewImageLoader?
        public var videoLoader: VideoLoader?

        public init(
            source: VideoSource? = nil,
            previewImage: UIImage? = nil,
            previewImageLoader: PreviewImageLoader? = nil,
            videoLoader: VideoLoader? = nil
        ) {
            self.source = source
            self.previewImage = previewImage
            self.previewImageLoader = previewImageLoader
            self.videoLoader = videoLoader
        }
    }
}
