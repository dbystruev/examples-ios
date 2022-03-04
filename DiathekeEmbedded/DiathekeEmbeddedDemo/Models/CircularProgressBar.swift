//
//  CircularProgressBar.swift
//  DiathekeEmbeddedDemo
//
//  Created by Eduard Miniakhmetov on 10.12.2021.
//  Copyright © 2021 Cobalt Speech and Language Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIColor {
    
    static let system = UIView().tintColor!
    
}

class CircularProgressBar: UIButton {
    
    var progressLyr = CAShapeLayer()
    var trackLyr = CAShapeLayer()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        makeCircularPath()
    }
    
    var progressClr = UIColor.system {
        didSet {
            progressLyr.strokeColor = progressClr.cgColor
        }
    }
    
    var trackClr = UIColor.lightGray {
        didSet {
            trackLyr.strokeColor = trackClr.cgColor
        }
    }
    
    func makeCircularPath() {
        self.backgroundColor = UIColor.clear
        let width = self.frame.size.width
        let frameWidth = frame.size.width
        
        self.layer.cornerRadius = width / 2
        let circlePath = UIBezierPath(arcCenter: CGPoint(x: frameWidth/2, y: frameWidth/2),
                                      radius: (frameWidth / 1.7 - 1.5)/2,
                                      startAngle: CGFloat(-0.5 * .pi),
                                      endAngle: CGFloat(1.5 * .pi),
                                      clockwise: true)
        trackLyr.path = circlePath.cgPath
        trackLyr.fillColor = UIColor.clear.cgColor
        trackLyr.strokeColor = trackClr.cgColor
        trackLyr.lineWidth = 2.0
        trackLyr.strokeEnd = 1.0
        layer.addSublayer(trackLyr)
        progressLyr.path = circlePath.cgPath
        progressLyr.fillColor = UIColor.clear.cgColor
        progressLyr.strokeColor = progressClr.cgColor
        progressLyr.lineWidth = 2.0
        progressLyr.strokeEnd = 0.0
        layer.addSublayer(progressLyr)
    }
    
    func setProgressWithAnimation(duration: TimeInterval, value: Float) {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.duration = duration
        animation.fromValue = 0
        animation.toValue = value
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        progressLyr.strokeEnd = CGFloat(value)
        progressLyr.add(animation, forKey: "animateprogress")
    }
    
    func setProgress(value: Float) {
        progressLyr.strokeEnd = CGFloat(value)
    }
    
}
