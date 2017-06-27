//
//  ViewController.swift
//  WebrtcDemo
//
//  Created by cruzr on 2017/6/5.
//  Copyright © 2017年 cruzr. All rights reserved.
//

import UIKit
import AVFoundation

struct SocketModel {
    static let targetHost = "10.10.27.124"
    static let targetPort : UInt16 = 5556
}

class ViewController: UIViewController {

    let factory = RTCPeerConnectionFactory()
    
    var localStream : RTCMediaStream?
    
    var connection : RTCPeerConnection?
    var tcpSocket : GCDAsyncSocket?
    var accepttcpSocket : GCDAsyncSocket?
    
    var remoteVideoTrack : RTCVideoTrack?
    
    var isoffering = false
    
    var tempStr = ""
    
    var setLocal = false
    var setRemote = false
    var sentICE = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //如果你需要安全一点，用到SSL验证，那就加上这句话。还没有仔细研究，先加上
        RTCPeerConnectionFactory.initializeSSL()
        
        //初始化socket
        tcpSocket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)

        //创建本地视频流，并显示到页面上
        createLocalStream()

        let ICEServers : [RTCICEServer] = [RTCICEServer]()
//        ICEServers.append(defaultSTUNServer(url: "stun:stun.l.google.com:19302"))
//        ICEServers.append(defaultSTUNServer(url: "turn:numb.viagenie.ca"))
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: [RTCPair(key: "DtlsSrtpKeyAgreement", value: "true")])
        connection = factory.peerConnection(withICEServers: ICEServers, constraints: constraints, delegate: self)
        
        //加入本地视频流
        connection?.add(localStream)
    
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
 
    func createLocalStream() {
        localStream = factory.mediaStream(withLabel: "ARDAMS")
        let audioTrack = factory.audioTrack(withID: "ARDAMSa0")
        localStream?.addAudioTrack(audioTrack)
        
        let deviceArray = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo)
        let device = deviceArray?.last as? AVCaptureDevice
        let authStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        if authStatus == .restricted || authStatus == .denied {
            
        } else {
            if (device != nil) {
                let capturer : RTCVideoCapturer = RTCVideoCapturer(deviceName: (device as AnyObject).localizedName)
                let videoSource = factory.videoSource(with: capturer, constraints: localVideoConstraints())
                let videoTrack = factory.videoTrack(withID: "ARDAMSv0", source: videoSource)
                localStream?.addVideoTrack(videoTrack)
                
                
                let localVideoView = RTCEAGLVideoView(frame: CGRect(x:0, y:0, width: 300, height: 300 * 640 /
                    480))
                localVideoView.transform = CGAffineTransform(scaleX: -1, y: 1)
                videoTrack?.add(localVideoView)
                self.view.addSubview(localVideoView)
                
            }
        }
        
    }
    
    //本地视频的约束条件
    func localVideoConstraints() -> RTCMediaConstraints {

        let maxWidth = RTCPair(key: "maxWidth", value: "640")
        let minWidth = RTCPair(key: "minWidth", value: "640")
        
        let maxHeight = RTCPair(key: "maxHeight", value: "480")
        let minHeight = RTCPair(key: "minHeight", value: "480")
        
        let minFrameRate = RTCPair(key: "minFrameRate", value: "15")
        
        let mandatory = [maxWidth, minWidth, maxHeight, minHeight, minFrameRate]
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: mandatory, optionalConstraints: nil)
        return constraints!
        
    }

    func defaultSTUNServer(url : String) -> RTCICEServer {
        let defaulturl = URL(string: url)
        return RTCICEServer(uri: defaulturl, username: "", password: "")
    }
    
    //offer或answer的约束条件
    func offerOranswerConstraint() -> RTCMediaConstraints {
        let receiveAudio = RTCPair(key: "OfferToReceiveAudio", value: "true")
        let receiveVideo = RTCPair(key: "OfferToReceiveVideo", value: "true")
        
        return RTCMediaConstraints(mandatoryConstraints: [receiveAudio, receiveVideo], optionalConstraints: nil)
    }

    @IBAction func offerBtnClicked(_ sender: UIButton) {
        connection?.createOffer(with: self, constraints: offerOranswerConstraint())
        
    }
    
    @IBAction func acceptBtn(_ sender: UIButton) {
        
        do {
            try tcpSocket?.accept(onPort: SocketModel.targetPort)
        } catch  {
            
        }
    }
}

extension ViewController : RTCPeerConnectionDelegate{
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, addedStream stream: RTCMediaStream!) {
        print("addedStream")
        DispatchQueue.main.async {
            if stream.videoTracks.count > 0{
                self.remoteVideoTrack = stream.videoTracks.last as? RTCVideoTrack
                
                let remoteVideoView = RTCEAGLVideoView(frame: CGRect(x:0, y:0, width: 100, height: 100 * 640 /
                    480))
                remoteVideoView.backgroundColor = UIColor.red
                remoteVideoView.transform = CGAffineTransform(scaleX: -1, y: 1)
                self.remoteVideoTrack?.add(remoteVideoView)
                
                self.view.addSubview(remoteVideoView)
            }
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, removedStream stream: RTCMediaStream!) {
        print("removedStream")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, gotICECandidate candidate: RTCICECandidate!) {
        print("gotICECandidate = \(candidate)")
        if sentICE {
            return
        }
        
        var dic = [String:String]()
        dic["event"] = "candidate"
        dic["sdp"] = candidate.sdp
        dic["label"] = String(candidate.sdpMLineIndex)
        dic["id"] = candidate.sdpMid
        
        let data : Data? = try? JSONSerialization.data(withJSONObject: dic)
        var str = String(data: data!, encoding: String.Encoding.utf8)!
        str += "|"
        
        if isoffering {
            tcpSocket?.write(str.data(using: .utf8)!, withTimeout: -1, tag: 0)
        } else {
            accepttcpSocket?.write(str.data(using: .utf8)!, withTimeout: -1, tag: 0)
        }
        
        sentICE = true
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, iceGatheringChanged newState: RTCICEGatheringState) {
        print("iceGatheringChanged")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, iceConnectionChanged newState: RTCICEConnectionState) {
        print("iceConnectionChanged, \(newState)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, signalingStateChanged stateChanged: RTCSignalingState) {
        print("signalingStateChanged")
    }
    
    func peerConnection(onRenegotiationNeeded peerConnection: RTCPeerConnection!) {
        print("onRenegotiationNeeded")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, didOpen dataChannel: RTCDataChannel!) {
        print("didOpen")
    }
}

extension ViewController : RTCSessionDescriptionDelegate {
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, didCreateSessionDescription sdp: RTCSessionDescription!, error: Error!) {
        print("didCreateSessionDescription")
        
        if !setLocal {
            peerConnection.setLocalDescriptionWith(self, sessionDescription: sdp)
            setLocal = true
        }
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, didSetSessionDescriptionWithError error: Error!) {
        print("didSetSessionDescriptionWithError")
        
        if peerConnection.signalingState == RTCSignalingHaveLocalOffer {

            print("send offer")
            var dic = [String:String]()
            dic["event"] = "offer"
            dic["sdp"] = peerConnection.localDescription.description
            
            let data : Data? = try? JSONSerialization.data(withJSONObject: dic)
            do {
                try tcpSocket!.connect(toHost: SocketModel.targetHost, onPort: SocketModel.targetPort, withTimeout: -1)
            } catch  {
                print("Error connect:\(error)")
            }
            
            var str = String(data: data!, encoding: String.Encoding.utf8)!
            str += "|"
            tcpSocket?.write(str.data(using: .utf8)!, withTimeout: -1, tag: 0)
            
            isoffering = true
            
        } else if peerConnection.signalingState == RTCSignalingStable {
            if !isoffering {
                var dic = [String:String]()
                dic["event"] = "answer"
                dic["sdp"] = peerConnection.localDescription.description
                let data : Data? = try? JSONSerialization.data(withJSONObject: dic)
                var str = String(data: data!, encoding: String.Encoding.utf8)!
                str += "|"
                accepttcpSocket?.write(str.data(using: .utf8)!, withTimeout: -1, tag: 0)
            }
        }
        
    }
}


extension ViewController : GCDAsyncSocketDelegate {
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("did connect to host = \(host)")
        tcpSocket?.readData(withTimeout: -1, tag: 0)
        
    }
    
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        accepttcpSocket = newSocket
        accepttcpSocket?.delegate = self
        accepttcpSocket?.readData(withTimeout: -1, tag: 0)
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        
        tcpSocket?.readData(withTimeout: -1, tag: 0)
        accepttcpSocket?.readData(withTimeout: -1, tag: 0)
        
        if let str = String(data: data, encoding: .utf8) {
            print("Message didReceiveData : \(str)")
            
            for c in str.characters {
                if c != "|" {
                    tempStr += String(c)
                    
                } else {
                    parseDic(msg: tempStr)
                    tempStr = ""
                }
                
            }
            
        }
       
    }
    
    func parseDic(msg : String)  {
        
        var parsedJSON: Any?
        do {
            parsedJSON = try JSONSerialization.jsonObject(with: msg.data(using: .utf8)!, options: JSONSerialization.ReadingOptions.mutableLeaves)
        } catch let error {
            print(error)
        }
        if let dic = parsedJSON as? [String : String] {
            if dic["event"] == "offer" {
                if isoffering {
                    return
                }
                let remoteSdp = RTCSessionDescription(type: "offer", sdp: dic["sdp"])
                
                connection?.setRemoteDescriptionWith(self, sessionDescription: remoteSdp)
                connection?.createAnswer(with: self, constraints: offerOranswerConstraint())
                
                
            } else if dic["event"] == "answer" {
                if !isoffering {
                    return
                }
                let remoteSdp = RTCSessionDescription(type: "answer", sdp: dic["sdp"])
                connection?.setRemoteDescriptionWith(self, sessionDescription: remoteSdp)
            } else if dic["event"] == "candidate" {
                let candidate = RTCICECandidate(mid: dic["id"], index: Int(dic["label"]!)!, sdp: dic["sdp"])
                connection?.add(candidate)
            }
        }
    }
    
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        print("didWriteDataWithTag")
    }
    
    func socket(_ sock: GCDAsyncSocket, shouldTimeoutWriteWithTag tag: Int, elapsed: TimeInterval, bytesDone length: UInt) -> TimeInterval {
        
        return -1;
    }
}
