//
//  BLETableViewCell.swift
//  Orbit 360 Facetracking
//
//  Created by Philipp Meyer on 19.10.16.
//  Copyright © 2016 Philipp Meyer. All rights reserved.
//

import UIKit

class BLETableViewCell: UITableViewCell {
    @IBOutlet weak var cellLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
