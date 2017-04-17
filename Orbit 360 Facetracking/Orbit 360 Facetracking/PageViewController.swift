//
//  PageViewController.swift
//  Orbit 360 Facetracking
//
//  Created by Philipp Meyer on 14.04.17.
//  Copyright © 2017 Philipp Meyer. All rights reserved.
//

import UIKit

class PageViewController: UIPageViewController {

    weak var cDelegate: PageViewControllerDelegate?

    private(set) lazy var orderedViewControllers: [UIViewController] = {
        // The view controllers will be shown in this order
        return [self.newViewController("1"),
                self.newViewController("2"),
                self.newViewController("3")]
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        dataSource = self
        delegate = self

        if let initialViewController = orderedViewControllers.first {
            scrollToViewController(initialViewController)
        }

        cDelegate?.pageViewController(self, didUpdatePageCount: orderedViewControllers.count)
    }

    /**
     Scrolls to the next view controller.
     */
    func scrollToNextViewController() {
        if let visibleViewController = viewControllers?.first,
        let nextViewController = pageViewController(self, viewControllerAfterViewController: visibleViewController) {
            scrollToViewController(nextViewController)
        }
    }

    /**
     Scrolls to the view controller at the given index. Automatically calculates
     the direction.
     - parameter newIndex: the new index to scroll to
     */
    func scrollToViewController(index newIndex: Int) {
        if let firstViewController = viewControllers?.first,
            let currentIndex = orderedViewControllers.indexOf(firstViewController) {
            let direction: UIPageViewControllerNavigationDirection = newIndex >= currentIndex ? .Forward : .Reverse
            let nextViewController = orderedViewControllers[newIndex]
            scrollToViewController(nextViewController, direction: direction)
        }
    }

    private func newViewController(number: String) -> UIViewController {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("UserGuide\(number)")
    }

    /**
     Scrolls to the given 'viewController' page.
     - parameter viewController: the view controller to show.
     */
    private func scrollToViewController(viewController: UIViewController,
                                        direction: UIPageViewControllerNavigationDirection = .Forward) {
        setViewControllers([viewController],
                           direction: direction,
                           animated: true,
                           completion: { (finished) -> Void in
                            // Setting the view controller programmatically does not fire
                            // any delegate methods, so we have to manually notify the
                            // 'Delegate' of the new index.
                            self.notifyDelegateOfNewIndex()
        })
    }

    /**
     Notifies 'Delegate' that the current page index was updated.
     */
    private func notifyDelegateOfNewIndex() {
        if let firstViewController = viewControllers?.first,
            let index = orderedViewControllers.indexOf(firstViewController) {
            cDelegate?.pageViewController(self, didUpdatePageIndex: index)
        }
        guard let root = UIApplication.sharedApplication().keyWindow?.rootViewController as? ContainerViewController else {
            return
        }
        print(root)
        if root.pageControl.currentPage == 2 {
            root.nextButton.hidden = true
        } else {
            root.nextButton.hidden = false
        }
    }

}

// MARK: UIPageViewControllerDataSource

extension PageViewController: UIPageViewControllerDataSource {

    func pageViewController(pageViewController: UIPageViewController, viewControllerBeforeViewController viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = orderedViewControllers.indexOf(viewController) else {
            return nil
        }

        let previousIndex = viewControllerIndex - 1

        guard previousIndex >= 0 else {
            return nil
        }

        guard orderedViewControllers.count > previousIndex else {
            return nil
        }

        return orderedViewControllers[previousIndex]
    }

    func pageViewController(pageViewController: UIPageViewController, viewControllerAfterViewController viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = orderedViewControllers.indexOf(viewController) else {
            return nil
        }

        let nextIndex = viewControllerIndex + 1
        let orderedViewControllersCount = orderedViewControllers.count

        guard orderedViewControllersCount != nextIndex else {
            return nil
        }

        guard orderedViewControllersCount > nextIndex else {
            return nil
        }

        return orderedViewControllers[nextIndex]
    }

}

extension PageViewController: UIPageViewControllerDelegate {

    func pageViewController(pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        notifyDelegateOfNewIndex()
    }

}

protocol PageViewControllerDelegate: class {

    /**
     Called when the number of pages is updated.

     - parameter PageViewController: the PageViewController instance
     - parameter count: the total number of pages.
     */
    func pageViewController(pageViewController: PageViewController, didUpdatePageCount count: Int)

    /**
     Called when the current index is updated.

     - parameter PageViewController: the PageViewController instance
     - parameter index: the index of the currently visible page.
     */
    func pageViewController(pageViewController: PageViewController, didUpdatePageIndex index: Int)
    
}
