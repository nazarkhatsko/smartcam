//
//  ViewController.swift
//  SmartCam
//
//  Created by Nazar Khatsko on 1/27/20.
//  Copyright © 2020 Nazar Khatsko. All rights reserved.
//

import UIKit
import AVKit
import Vision

class ViewController: UIViewController {
    @IBOutlet weak var viewScan: UIView!
    @IBOutlet weak var labelNameScan: UILabel!
    @IBOutlet weak var labelInterestScan: UILabel!
    
    @IBOutlet weak var blurScan: UIVisualEffectView!
    @IBOutlet weak var buttonScan: UIButton!
        
    var isScan:Bool = false
    
    var session:AVCaptureSession = AVCaptureSession()
    var device:AVCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)!
    var layer:AVCaptureVideoPreviewLayer?
    
    @IBAction func buttonVoiceAction_TouchUp(_ sender: UIButton) {
        AVSpeechSynthesizer().speak(AVSpeechUtterance(string: labelNameScan.text!))
    }
    
    @IBAction func buttonScanAction_TouchUp(_ sender: UIButton) {
        if (isScan) {
            isScan = false
            
            UIView.animate(withDuration: 0.5, delay: 0, options: [], animations: {
                self.viewScan.alpha = 0
                self.viewScan.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                
                self.blurScan.transform = CGAffineTransform(scaleX: 1, y: 1)
                sender.transform = CGAffineTransform(scaleX: 1, y: 1)
                sender.backgroundColor = .clear
            }, completion: nil)
        } else {
            isScan = true
            
            UIView.animate(withDuration: 0.5, delay: 0, options: [], animations: {
                self.viewScan.alpha = 1
                self.viewScan.transform = CGAffineTransform(scaleX: 1, y: 1)
                
                self.blurScan.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                sender.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                sender.backgroundColor = .white
            }, completion: nil)
        }
    }
    
    @IBAction func buttonFlashAction_TouchUp(_ sender: UIButton) {
        var torchMode:AVCaptureDevice.TorchMode?
        if sender.currentImage == #imageLiteral(resourceName: "flash-off") {
            sender.setImage(#imageLiteral(resourceName: "flash-on"), for: .normal)
            sender.backgroundColor = .white
            torchMode = .on
        } else {
            sender.setImage(#imageLiteral(resourceName: "flash-off"), for: .normal)
            sender.backgroundColor = .clear
            torchMode = .off
        }
            
        if device.hasTorch {
            try? device.lockForConfiguration()
            device.torchMode = torchMode!
            device.unlockForConfiguration()
        }
    }
    
    @IBAction func buttonRotateAction_TouchUp(_ sender: UIButton) {
        var postiton:AVCaptureDevice.Position?
        if sender.currentImage == #imageLiteral(resourceName: "camera-back") {
            sender.setImage(#imageLiteral(resourceName: "camera-front"), for: .normal)
            sender.backgroundColor = .white
            postiton = .front
        } else {
            sender.setImage(#imageLiteral(resourceName: "camera-back"), for: .normal)
            sender.backgroundColor = .clear
            postiton = .back
        }
        
        session.stopRunning()
        device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: postiton!)!
        do {
            session = AVCaptureSession()
            
            let input = try? AVCaptureDeviceInput(device: device)
            session.addInput(input!)
            
            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            session.addOutput(output)
            
            let layer_new = AVCaptureVideoPreviewLayer(session: session)
            layer_new.frame = view.frame
            view.layer.replaceSublayer(layer!, with:layer_new)
            layer = layer_new
            
            session.startRunning()
        } catch {
            print("error")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewScan.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        buttonScan.layer.borderColor = UIColor.white.cgColor
        
        let input = try? AVCaptureDeviceInput(device: device)
        session.addInput(input!)
        
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        session.addOutput(output)
        
        layer = AVCaptureVideoPreviewLayer(session: session)
        layer!.frame = view.frame
        view.layer.insertSublayer(layer!, at: 0)
                
        session.startRunning()
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixleBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let model = try? VNCoreMLModel(for: Resnet50().model) else { return }
        let request = VNCoreMLRequest(model: model) { (finishedReq, err) in
            guard let results = finishedReq.results as? [VNClassificationObservation] else { return }
            guard let firstObservation = results.first else { return }
            
            DispatchQueue.main.async {
                if (self.isScan) {
                    self.labelNameScan.text = firstObservation.identifier
                    self.labelInterestScan.text = String(Int(firstObservation.confidence * 100)) + "%"
                }
            }
        }
        try? VNImageRequestHandler(cvPixelBuffer: pixleBuffer, options: [:]).perform([request])
    }
}
