//
//  FBLiveAPI.swift
//  Orbit 360 Facetracking
//
//  Created by Philipp Meyer on 27.02.17.
//  Copyright © 2017 Philipp Meyer. All rights reserved.
//

import Foundation

enum FBLivePrivacy: StringLiteralType {
    case closed = "SELF"
    case everyone = "EVERYONE"
    case allFriends = "ALL_FRIENDS"
    case friendsOfFriends = "FRIENDS_OF_FRIENDS"
}

class FBLiveAPI {
    typealias CallbackBlock = ((Any) -> Void)
    var liveVideoId: String?

    static let shared = FBLiveAPI()

    func startLive(privacy: FBLivePrivacy, callback: CallbackBlock) {
        dispatch_async(dispatch_get_main_queue(), {
            if FBSDKAccessToken.currentAccessToken().hasGranted("publish_actions") {
                let path = "/me/live_videos"
                let params = [
                    "privacy": "{\"value\":\"\(privacy.rawValue)\"}"
                ]

                let request = FBSDKGraphRequest(
                    graphPath: path,
                    parameters: params,
                    HTTPMethod: "POST"
                )

                _ = request?.startWithCompletionHandler({ (_, result, error) in
                    if error == nil {
                        self.liveVideoId = (result as? NSDictionary)?.valueForKey("id") as? String
                        callback(result)
                    }
                })
            }
        })
    }

    func endLive(callback: CallbackBlock) {
        dispatch_async(dispatch_get_main_queue(), {
            if FBSDKAccessToken.currentAccessToken().hasGranted("publish_actions") {
                guard let id = self.liveVideoId else { return }
                let path = "/\(id)"

                let request = FBSDKGraphRequest(
                    graphPath: path,
                    parameters: ["end_live_video": true],
                    HTTPMethod: "POST"
                )

                _ = request?.startWithCompletionHandler({ (_, result, error) in
                    if error == nil {
                        callback(result)
                    }
                })
            }
        })
    }
}
