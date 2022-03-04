//
//  UIApplicationExtension.swift
//  DiathekeEmbeddedDemo
//
//  Created by Eduard Miniakhmetov on 17.12.2021.
//  Copyright © 2021 Cobalt Speech and Language Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIApplication {
   
   public var mainKeyWindow: UIWindow? {
       let scene = self.connectedScenes.first as? UIWindowScene
       return scene?.windows.first(where: { $0.isKeyWindow })
   }

   public var rootViewController: UIViewController? {
       guard let keyWindow = UIApplication.shared.mainKeyWindow, let rootViewController = keyWindow.rootViewController else {
           return nil
       }
       return rootViewController
   }

   public func topViewController(controller: UIViewController? = UIApplication.shared.rootViewController) -> UIViewController? {

       if controller == nil {
           return topViewController(controller: rootViewController)
       }
       
       if let navigationController = controller as? UINavigationController {
           return topViewController(controller: navigationController.visibleViewController)
       }

       if let tabController = controller as? UITabBarController {
           if let selectedViewController = tabController.selectedViewController {
               return topViewController(controller: selectedViewController)
           }
       }

       if let presentedViewController = controller?.presentedViewController {
           return topViewController(controller: presentedViewController)
       }

       return controller
   }
}
