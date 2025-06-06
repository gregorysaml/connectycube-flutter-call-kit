//
//  VoIPController.swift
//  connectycube_flutter_call_kit
//
//  Created by Tereha on 19.11.2021.
//

import Foundation
import PushKit

class VoIPController: NSObject {
    let callKitController: CallKitController
    var tokenListener: ((String) -> Void)?
    var voipToken: String?
    var sipServer: String?

    public required init(withCallKitController callKitController: CallKitController) {
        self.callKitController = callKitController
        super.init()

        //http://stackoverflow.com/questions/27245808/implement-pushkit-and-test-in-development-behavior/28562124#28562124
        let pushRegistry = PKPushRegistry(queue: .main)
        pushRegistry.delegate = self
        pushRegistry.desiredPushTypes = Set<PKPushType>([.voIP])
    }

    func getVoIPToken() -> String? {
        return voipToken
    }

    func getSipServer() -> String? {
        // sipServer = "test"
        return sipServer
    }
}

//MARK: VoIP Token notifications
extension VoIPController: PKPushRegistryDelegate {
    func pushRegistry(
        _ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials,
        for type: PKPushType
    ) {
        if pushCredentials.token.count == 0 {
            print("[VoIPController][pushRegistry] No device token!")
            return
        }

        print("[VoIPController][pushRegistry] token: \(pushCredentials.token)")

        let deviceToken: String = pushCredentials.token.reduce(
            "", { $0 + String(format: "%02X", $1) })
        print("[VoIPController][pushRegistry] deviceToken: \(deviceToken)")

        self.voipToken = deviceToken

        if tokenListener != nil {
            print("[VoIPController][pushRegistry] notify listener")
            tokenListener!(self.voipToken!)
        }
    }

    func pushRegistry(
        _ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType, completion: @escaping () -> Void
    ) {
        print(
            "[VoIPController][pushRegistry][didReceiveIncomingPushWith] payload: \(payload.dictionaryPayload)"
        )

        let callData = payload.dictionaryPayload

        if type == .voIP {
            let callId = callData["session_id"] as! String
            let signalingType = callData["signal_type"] as? String
            let sipServer: String? = callData["sip_server"] as? String

            if signalingType != nil && (signalingType == "endCall" || signalingType == "rejectCall")
            {
                self.callKitController.reportCallEnded(
                    uuid: UUID(uuidString: callId.lowercased())!,
                    reason: CallEndedReason.remoteEnded)

                completion()
            } else if signalingType != nil && signalingType == "startCall" {
                let callType = callData["call_type"] as! Int
                let callInitiatorId = callData["caller_id"] as! Int
                let callInitiatorName = callData["caller_name"] as! String
                let callOpponentsString = callData["call_opponents"] as! String
                let callOpponents = callOpponentsString.components(separatedBy: ",")
                    .map { Int($0) ?? 0 }
                let userInfo = callData["user_info"] as? String

                if sipServer != nil {
                    self.sipServer = sipServer
                } else {
                    self.sipServer = nil
                }

                self.callKitController.reportIncomingCall(
                    uuid: callId.lowercased(), callType: callType, callInitiatorId: callInitiatorId,
                    callInitiatorName: callInitiatorName, opponents: callOpponents,
                    userInfo: userInfo
                ) { (error) in

                    completion()

                    if error == nil {
                        print(
                            "[VoIPController][didReceiveIncomingPushWith] reportIncomingCall SUCCESS"
                        )
                    } else {
                        print(
                            "[VoIPController][didReceiveIncomingPushWith] reportIncomingCall ERROR: \(error?.localizedDescription ?? "none")"
                        )
                    }
                }
            } else {
                print(
                    "[VoIPController][didReceiveIncomingPushWith] unknown 'signal_type' was received"
                )
                completion()
            }
        } else {
            completion()
        }
    }
}
