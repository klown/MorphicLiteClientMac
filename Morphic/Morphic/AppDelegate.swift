// Copyright 2020 Raising the Floor - International
//
// Licensed under the New BSD license. You may not use this file except in
// compliance with this License.
//
// You may obtain a copy of the License at
// https://github.com/GPII/universal/blob/master/LICENSE.txt
//
// The R&D leading to these results received funding from the:
// * Rehabilitation Services Administration, US Dept. of Education under
//   grant H421A150006 (APCP)
// * National Institute on Disability, Independent Living, and
//   Rehabilitation Research (NIDILRR)
// * Administration for Independent Living & Dept. of Education under grants
//   H133E080022 (RERC-IT) and H133E130028/90RE5003-01-00 (UIITA-RERC)
// * European Union's Seventh Framework Programme (FP7/2007-2013) grant
//   agreement nos. 289016 (Cloud4all) and 610510 (Prosperity4All)
// * William and Flora Hewlett Foundation
// * Ontario Ministry of Research and Innovation
// * Canadian Foundation for Innovation
// * Adobe Foundation
// * Consumer Electronics Association Foundation

import Cocoa
import OSLog
import MorphicCore
import MorphicService
import MorphicSettings

private let logger = OSLog(subsystem: "app", category: "delegate")

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    
    static var shared: AppDelegate!
    
    @IBOutlet var menu: NSMenu!
    @IBOutlet weak var showQuickStripItem: NSMenuItem?
    @IBOutlet weak var hideQuickStripItem: NSMenuItem?
    @IBOutlet weak var logoutItem: NSMenuItem?
    
    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        os_log(.info, log: logger, "applicationDidFinishLaunching")
        AppDelegate.shared = self
        os_log(.info, log: logger, "opening morphic session...")
        populateSolutions()
        createStatusItem()
        copyDefaultPreferences{
            Session.shared.open {
                os_log(.info, log: logger, "session open")
                self.logoutItem?.isHidden = Session.shared.user == nil
                if Session.shared.bool(for: .morphicQuickStripVisible) ?? true{
                    self.showQuickStrip(nil)
                }
                DistributedNotificationCenter.default().addObserver(self, selector: #selector(AppDelegate.userDidSignin), name: .morphicSignin, object: nil)
                NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.sessionUserDidChange(_:)), name: .morphicSessionUserDidChange, object: Session.shared)
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }
    
    // MARK: - Notifications
    
    @objc
    func userDidSignin(_ notification: NSNotification){
        os_log(.info, log: logger, "Got signin notification from configurator")
        Session.shared.open {
            NotificationCenter.default.post(name: .morphicSessionUserDidChange, object: Session.shared)
            let userInfo = notification.userInfo ?? [:]
            if !(userInfo["isRegister"] as? Bool ?? false){
                os_log(.info, log: logger, "Is not a registration signin, applying all preferences")
                Session.shared.applyAllPreferences {
                }
            }
        }
    }
    
    @objc
    func sessionUserDidChange(_ notification: NSNotification){
        guard let session = notification.object as? Session else{
            return
        }
        self.logoutItem?.isHidden = session.user == nil
    }
    
    // MARK: - Actions
    
    @IBAction
    func logout(_ sender: Any){
        Session.shared.signout {
            self.logoutItem?.isHidden = true
        }
    }
    
    @IBAction
    func reapplyAllSettings(_ sender: Any){
        Session.shared.open{
            os_log(.info, "Re-applying all settings")
            Session.shared.applyAllPreferences {
                
            }
        }
    }
    
    @IBAction
    func captureAllSettings(_ sender: Any){
        let prefs = Preferences(identifier: "")
        let capture = CaptureSession(settingsManager: Session.shared.settings, preferences: prefs)
        capture.captureDefaultValues = true
        capture.addAllSolutions()
        capture.run {
            for pair in capture.preferences.keyValueTuples(){
                print(pair.0, pair.1 ?? "<nil>")
            }
        }
    }
    
    // MARK: - Default Preferences
    
    func copyDefaultPreferences(completion: @escaping () -> Void){
        var prefs = Preferences(identifier: "__default__")
        guard !Session.shared.storage.contains(identifier: prefs.identifier, type: Preferences.self) else{
            completion()
            return
        }
        guard let url = Bundle.main.url(forResource: "DefaultPreferences", withExtension: "json") else{
            os_log(.error, log: logger, "Failed to find default preferences")
            return
        }
        guard let json = FileManager.default.contents(atPath: url.path) else{
            os_log(.error, log: logger, "Failed to read default preferences")
            return
        }
        do{
            let decoder = JSONDecoder()
            prefs.defaults = try decoder.decode(Preferences.PreferencesSet.self, from: json)
        }catch{
            os_log(.error, log: logger, "Failed to decode default preferences")
            return
        }
        Session.shared.storage.save(record: prefs){
            success in
            if !success{
                os_log(.error, log: logger, "Failed to save default preferences")
            }
            completion()
        }
    }
    
    // MARK: - Solutions
    
    func populateSolutions(){
        Session.shared.settings.populateSolutions(fromResource: "macos.solutions")
    }
     
    // MARK: - Status Bar Item

    /// The item that shows in the macOS menu bar
    var statusItem: NSStatusItem!
     
    /// Create our `statusItem` for the macOS menu bar
    ///
    /// Should be called during application launch
    func createStatusItem(){
        os_log(.info, log: logger, "Creating status item")
        statusItem = NSStatusBar.system.statusItem(withLength: -1)
        statusItem.menu = menu
        guard let button = statusItem.button else {
            return
        }
        button.image = NSImage(named: "MenuIcon")
        button.alternateImage = NSImage(named: "MenuIconAlternate")
    }
     
    // MARK: - Quick Strip
     
    /// The window controller for the morphic quick strip that is shown by clicking on the `statusItem`
    var quickStripWindow: QuickStripWindow?
     
    /// Show or hide the morphic quick strip
    ///
    /// - parameter sender: The UI element that caused this action to be invoked
    @IBAction
    func toggleQuickStrip(_ sender: Any?){
        if quickStripWindow != nil{
            hideQuickStrip(nil)
        }else{
            showQuickStrip(nil)
        }
    }
    
    @IBAction
    func showQuickStrip(_ sender: Any?){
        if quickStripWindow == nil{
            quickStripWindow = QuickStripWindow()
            quickStripWindow?.delegate = self
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        quickStripWindow?.makeKeyAndOrderFront(nil)
        showQuickStripItem?.isHidden = true
        hideQuickStripItem?.isHidden = false
        if sender != nil{
            Session.shared.set(true, for: .morphicQuickStripVisible)
        }
    }
    
    @IBAction
    func hideQuickStrip(_ sender: Any?){
        quickStripWindow?.close()
        showQuickStripItem?.isHidden = false
        hideQuickStripItem?.isHidden = true
        QuickHelpWindow.hide()
        if sender != nil{
            Session.shared.set(false, for: .morphicQuickStripVisible)
        }
    }
     
    func windowDidBecomeKey(_ notification: Notification) {
    }
     
    func windowDidResignKey(_ notification: Notification) {
    }
     
    func windowWillClose(_ notification: Notification) {
        quickStripWindow = nil
    }
    
    func windowDidChangeScreen(_ notification: Notification) {
        quickStripWindow?.reposition(animated: false)
    }
     
    // MARK: - Configurator App
    
    @IBAction
    func launchCapture(_ sender: Any?){
        launchConfigurator(argument: "capture")
    }
    
    @IBAction
    func launchLogin(_ sender: Any?){
        launchConfigurator(argument: "login")
    }
    
    func launchConfigurator(argument: String){
//        let url = URL(string: "morphicconfig:\(argument)")!
//        NSWorkspace.shared.open(url)
        os_log(.info, log: logger, "launching configurator")
        guard let url = Bundle.main.resourceURL?.deletingLastPathComponent().appendingPathComponent("Library").appendingPathComponent("MorphicConfigurator.app") else{
            os_log(.error, log: logger, "Failed to construct bundled configurator app URL")
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        config.arguments = [argument]
        NSWorkspace.shared.openApplication(at: url, configuration: config){
            (app, error) in
            guard error == nil else{
                os_log(.error, log: logger, "Failed to launch configurator: %{public}s", error!.localizedDescription)
                return
            }
        }
    }

}
