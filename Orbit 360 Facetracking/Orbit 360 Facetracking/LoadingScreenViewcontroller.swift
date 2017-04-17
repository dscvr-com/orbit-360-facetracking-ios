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
    @IBOutlet weak var logo: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        logo.image = UIImage.animatedImageNamed("tmp-", duration: 0.1)
    }
}
