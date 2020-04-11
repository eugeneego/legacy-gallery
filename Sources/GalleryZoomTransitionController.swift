//
// GalleryZoomTransitionController
// LegacyGallery
//
// Copyright (c) 2018 Eugene Egorov.
// License: MIT, https://github.com/eugeneego/legacy/blob/master/LICENSE
//

import UIKit

open class GalleryZoomTransitionController: NSObject, UIViewControllerTransitioningDelegate {
    open weak var sourceTransition: GalleryZoomTransitionDelegate?

    open func animationController(
        forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        guard
            let sourceTransition = source as? GalleryZoomTransitionDelegate,
            let destinationTransition = presented as? GalleryZoomTransitionDelegate
        else { return nil }

        self.sourceTransition = sourceTransition

        let transition = GalleryZoomTransition(interactive: false)
        transition.sourceTransition = sourceTransition
        transition.destinationTransition = destinationTransition
        return transition
    }

    open func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        guard
            let sourceTransition = dismissed as? GalleryZoomTransitionDelegate,
            let destinationTransition = self.sourceTransition
        else { return nil }

        let transition = sourceTransition.zoomTransition ?? GalleryZoomTransition(interactive: false)
        transition.sourceTransition = sourceTransition
        transition.destinationTransition = destinationTransition
        return transition
    }

    open func interactionControllerForPresentation(
        using animator: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        nil
    }

    open func interactionControllerForDismissal(
        using animator: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        guard let transition = animator as? GalleryZoomTransition else { return nil }

        return transition.interactive ? transition : nil
    }
}
