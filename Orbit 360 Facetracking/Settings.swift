//
//  Settings.swift
//  Orbit 360
//
//  Created by Philipp Meyer on 17.04.17.
//  Copyright © 2017 Philipp Meyer. All rights reserved.
//

import Foundation
import UIKit

class Settings: UIViewController {

    override func prefersStatusBarHidden() -> Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func settingsUnwindAction(unwindSegue: UIStoryboardSegue) {
    }

}

class table: UITableViewController {


    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        switch indexPath.row {
        case 0:
            self.performSegueWithIdentifier("settingsSegue", sender: self)
            break
        default:
            break
        }
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
        if (segue.identifier == "settingsSegue") {
            let destination = segue.destinationViewController as! ContainerViewController
            destination.fromSettings = true
        }
    }
}
