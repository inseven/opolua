//
//  AppDelegate.swift
//  OpoLua
//
//  Created by Tom Sutcliffe on 15/11/2021.
//

import UIKit

//import Cocoa
//
//func f(_ L: OpaquePointer?) -> Int32 {
//    print("Wowsers this worked!")
//    let arg = String(validatingUTF8: luaL_tolstring(L, 1, nil)!)
//    print("arg1=\(arg!)")
//    return 0
//}
//
//func lua_pushfstring(_ L: OpaquePointer?, fmt: UnsafePointer<CChar>, arguments:CVarArg...) -> UnsafePointer<CChar> {
//    return withVaList(arguments) { va_list in
//        lua_pushvfstring(L, fmt, va_list)
//    }
//}
//
//@main
//class AppDelegate: NSObject, NSApplicationDelegate {
//
//    @IBOutlet var window: NSWindow!
//    var L: OpaquePointer?
//
//    func applicationWillFinishLaunching(_ aNotification: Notification) {
//        L = luaL_newstate()
////        lua_pushcfunction(L) { L in
////            print("Wowsers this worked")
////            return 0
////        }
//        lua_pushcfunction(L, f)
//        let _ = lua_pushfstring(L, fmt: "%d", arguments: 1)
//    }
//
//    func applicationDidFinishLaunching(_ notification: Notification) {
//        lua_callk(L, 1, 0, 0, nil)
//    }
//    func applicationWillTerminate(_ aNotification: Notification) {
//        // Insert code here to tear down your application
//    }
//
//
//}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let viewController = ScreenViewController()
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.navigationBar.prefersLargeTitles = true

        let window = UIWindow()
        window.rootViewController = navigationController
        window.tintColor = UIColor(named: "TintColor")
        window.makeKeyAndVisible()
        self.window = window

        return true
    }
}
