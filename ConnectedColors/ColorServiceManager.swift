//
//  ColorServiceManager.swift
//  ConnectedColors
//
//  Created by RyanWang on 2017/5/17.
//  Copyright © 2017年 Example. All rights reserved.
//

import UIKit
import MultipeerConnectivity
var usedid : [MCPeerID] = []

class ColorServiceManager: NSObject {

    private let ColorServicetype = "example-color"
    
    let myPeerID = MCPeerID.init(displayName: UIDevice.current.name)
    
    private let serviceAdvertiser : MCNearbyServiceAdvertiser
    
    private let serviceBrowser : MCNearbyServiceBrowser
    
    private var rootTag : Bool
    
    var sendArray : [MCPeerID]
    
    var havedone : Bool
    
    lazy var session : MCSession = {
        let session = MCSession(peer: self.myPeerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        return session
    }()
    
    var delegate : ColorServiceManagerDelegate?
    
    override init() {
        self.serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo : nil, serviceType: ColorServicetype)
        self.serviceBrowser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: ColorServicetype)
        self.rootTag = false
        self.havedone = false
        self.sendArray = []
        super.init()
        
        self.serviceAdvertiser.delegate = self
        self.serviceAdvertiser.startAdvertisingPeer()
    
        self.serviceBrowser.delegate = self
        self.serviceBrowser.startBrowsingForPeers()
    }
    
    deinit {
        self.serviceAdvertiser.stopAdvertisingPeer()
    }
    
    func sendString(_ theData: String) {
        print("send string\n")
        
        let dataToSend = NSKeyedArchiver.archivedData(withRootObject: theData)
        
        if session.connectedPeers.count > 0 {
            
            var idArray : [MCPeerID] = session.connectedPeers
            
            for id in usedid {
                if idArray.contains(id) {
                    idArray.remove(at: idArray.index(of: id)!)
                }
            }
            
            if (idArray.count < 2) {
                sendArray = [idArray[0]]
            } else {
                sendArray = [idArray[0], idArray[1]]
            }
            
            /* Update used ID array */
            for id in sendArray {
                usedid.append(id)
            }
            if !usedid.contains(self.myPeerID) {
                usedid.append(self.myPeerID)
            }
            
            self.sendUsedID(usedid)
            
            do {
                try self.session.send(dataToSend, toPeers: sendArray, with: .reliable)
            } catch let error {
                NSLog("%@", "Error for sending: \(error)")
            }
            
            usedid.removeAll()
        }
    }
    
    func sendUsedID(_ theData: Array<MCPeerID>) {
        print("send int array\n")
        
        let dataToSend = NSKeyedArchiver.archivedData(withRootObject: theData)
        
        if session.connectedPeers.count > 0 {
            
            var idArray : [MCPeerID] = session.connectedPeers
            
            for id in usedid {
                if idArray.contains(id) {
                    if !(sendArray.contains(id)) {
                        idArray.remove(at: idArray.index(of: id)!)
                    }
                }
            }
            
            do {
                try self.session.send(dataToSend, toPeers: idArray, with: .reliable)
            } catch let error {
                NSLog("%@", "Error for sending array: \(error)")
            }
        }
    }
}

extension ColorServiceManager : MCNearbyServiceAdvertiserDelegate {
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        NSLog("%@", "didNotStartAdvertisingPeer: \(error)")
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        NSLog("%@", "didReceiveInvitationFromPeer \(peerID)")
        invitationHandler(true, self.session)
    }
    
}

extension ColorServiceManager : MCNearbyServiceBrowserDelegate {
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        NSLog("%@", "didNotStartBrowsingForPeers: \(error)")
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        NSLog("%@", "foundPeer: \(peerID)")
        NSLog("%@", "invitePeer: \(peerID)")
        browser.invitePeer(peerID, to : self.session, withContext: nil, timeout: 5)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("%@", "lostPeer: \(peerID)")
    }
    
}

extension ColorServiceManager : MCSessionDelegate {
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        NSLog("%@", "peer \(peerID) didChangeState: \(state.rawValue)")
        self.delegate?.connectedDevicesChanged(manager: self, connectedDevices: session.connectedPeers.map{$0.displayName})
    }
    
    /*func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        
        if(certificateHandler != nil) {
            certificateHandler(true);
            print("In Certificate\n")
        }
    }*/
    
    /* Called when received data */
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        /* ?????? work??????? */
            
        //NSLog("%@", "didReceiveData: \(data)")
        var checkEqual : Bool = true
        
        if let str = (NSKeyedUnarchiver.unarchiveObject(with: data) as? String) {
            if havedone == false {
                havedone = true
                self.delegate?.colorChanged(manager: self, colorString: str)
            
                var cmpArray : [MCPeerID] = usedid
                if cmpArray.contains(self.myPeerID) {
                    cmpArray.remove(at: cmpArray.index(of: self.myPeerID)!)
                }
            
                for id in session.connectedPeers {
                    if !cmpArray.contains(id) {
                        checkEqual = false
                    }
                }
            
                if (checkEqual) {
                    print("DONEEEEEE\n")
                    usedid.removeAll()
                } else {
                    sendString(str)
                }
            }
        } else if let arr = (NSKeyedUnarchiver.unarchiveObject(with: data) as? Array<MCPeerID>) {
            havedone = false
            usedid = arr
            print("Update Used ID \n")
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        NSLog("%@", "didReceiveStream")
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        NSLog("%@", "didStartReceivingResourceWithName")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL, withError error: Error?) {
        NSLog("%@", "didFinishReceivingResourceWithName")
    }
    
}

protocol ColorServiceManagerDelegate {
    func connectedDevicesChanged(manager: ColorServiceManager, connectedDevices: [String])
    
    func colorChanged(manager: ColorServiceManager, colorString: String)
}
