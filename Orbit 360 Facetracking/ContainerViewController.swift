//
//  PageViewController.swift
//  Orbit 360 Facetracking
//
//  Created by Philipp Meyer on 14.04.17.
//  Copyright © 2017 Philipp Meyer. All rights reserved.
//

import UIKit

class ContainerViewController: UIViewController {

    var fromSettings = false
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var nextButton: UIView!
    @IBOutlet weak var unwindButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!

    var pageViewController: PageViewController? {
        didSet {
            pageViewController?.cDelegate = self
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func prefersStatusBarHidden() -> Bool {
        return true
    }

    override func shouldAutorotate() -> Bool {
        return false
    }

    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return .Portrait
    }

    override func preferredInterfaceOrientationForPresentation() -> UIInterfaceOrientation {
        return .Portrait
    }

    override func viewDidLoad() {
        pageControl.addTarget(self, action: #selector(ContainerViewController.didChangePageControlValue), forControlEvents: .ValueChanged)
//        UIApplication.sharedApplication().delegate!.window!!.rootViewController! = self
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(true)
        if fromSettings {
            unwindButton.hidden = false
            cancelButton.hidden = true
            cancelButton.enabled = false
        }
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let pageViewController = segue.destinationViewController as? PageViewController {
            self.pageViewController = pageViewController
        }
    }

    @IBAction func didTapCancelButton(sender: AnyObject) {
        self.performSegueWithIdentifier("cancelGuideSegue", sender: self)
    }

    @IBAction func didTapNextButton(sender: AnyObject) {
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

