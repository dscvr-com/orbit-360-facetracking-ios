//
//  PageViewController.swift
//  Orbit 360 Facetracking
//
//  Created by Philipp Meyer on 14.04.17.
//  Copyright © 2017 Philipp Meyer. All rights reserved.
//

import UIKit

class ContainerViewController: UIViewController {

    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var containerView: UIView!

    var pageViewController: PageViewController? {
        didSet {
            pageViewController?.cDelegate = self
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        pageControl.addTarget(self, action: #selector(ContainerViewController.didChangePageControlValue), forControlEvents: .ValueChanged)
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let pageViewController = segue.destinationViewController as? PageViewController {
            self.pageViewController = pageViewController
        }
    }

    @IBAction func didTapNextButton(sender: UIButton) {
        pageViewController?.scrollToNextViewController()
    }

    /**
     Fired when the user taps on the pageControl to change its current page.
     */
    func didChangePageControlValue() {
        pageViewController?.scrollToViewController(index: pageControl.currentPage)
    }
}

extension ContainerViewController: PageViewControllerDelegate {

    func pageViewController(pageViewController: PageViewController, didUpdatePageCount count: Int) {
        pageControl.numberOfPages = count
    }

    func pageViewController(pageViewController: PageViewController, didUpdatePageIndex index: Int) {
        pageControl.currentPage = index
    }
    
}

