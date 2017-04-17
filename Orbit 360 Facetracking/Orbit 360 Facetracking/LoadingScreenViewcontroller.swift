//
//  loadingScreenViewcontroller.swift
//  Orbit 360
//
//  Created by Philipp Meyer on 17.04.17.
//  Copyright © 2017 Philipp Meyer. All rights reserved.
//

import Foundation
import UIKit

class LoadingScreenViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let logoGif = UIImage.gifImageWithName("tracker-circle-logo_01")
        let imageView = UIImageView(image: logoGif)
        imageView.frame = CGRect(x: self.view.frame.size.width / 2 - 75, y: self.view.frame.size.height / 2 - 75, width: 150, height: 150.0)
        view.addSubview(imageView)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(true)
        let firstRunKey = "firstRun"
        let defaults = NSUserDefaults.standardUserDefaults()
        let firstRun = defaults.boolForKey(firstRunKey)
        if firstRun {
            _ = NSTimer.scheduledTimerWithTimeInterval(2, target: self, selector: #selector(LoadingScreenViewController.performJumpGuideSegue), userInfo: nil, repeats: false)
            return
        } else {
            _ = NSTimer.scheduledTimerWithTimeInterval(2, target: self, selector: #selector(LoadingScreenViewController.performGuideSegue), userInfo: nil, repeats: false)
        }
        defaults.setBool(true, forKey: firstRunKey)
    }

    func performGuideSegue() {
        self.performSegueWithIdentifier("returnFromSplashScreen", sender: self)
    }

    func performJumpGuideSegue() {
        self.performSegueWithIdentifier("jumpGuide", sender: self)
    }

}
