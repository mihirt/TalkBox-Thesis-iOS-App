//
//  ControllerModeViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class ControllerModeViewController: PeripheralModeViewController {

    // Constants
    private static let kPollInterval = 0.25

    // UI
    @IBOutlet weak var baseTableView: UITableView!
    @IBOutlet weak var uartWaitingLabel: UILabel!

    // Data
    private var controllerData: ControllerModuleManager!
    private var contentItems = [Int]()
    private weak var controllerPadViewController: ControllerPadViewController?
    private weak var talkBoxViewController: TalkBoxViewController?
    private weak var wordAssignmentsViewController: WordAssignmentsViewController?

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Title
        let localizationManager = LocalizationManager.shared
        let name = blePeripheral?.name ?? LocalizationManager.shared.localizedString("scanner_unnamed")
        self.title = traitCollection.horizontalSizeClass == .regular ? String(format: localizationManager.localizedString("controller_navigation_title_format"), arguments: [name]) : localizationManager.localizedString("controller_tab_title")
        
        // Init
        assert(blePeripheral != nil)
        controllerData = ControllerModuleManager(blePeripheral: blePeripheral!, delegate: self)

        updateUartUI(isReady: false)

        //
        updateContentItemsFromSensorsEnabled()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if isMovingToParent {       // To keep streaming data when pushing a child view
            controllerData.start(pollInterval: ControllerModeViewController.kPollInterval) { [unowned self] in
                self.baseTableView.reloadData()
            }

            // Watch
            WatchSessionManager.shared.updateApplicationContext(mode: .controller)

            // Notifications
            registerNotifications(enabled: true)
        } else {
            // Disable cache if coming back from Control Pad
            controllerData.isUartRxCacheEnabled = false
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if isMovingFromParent {     // To keep streaming data when pushing a child view
            controllerData.stop()

            // Watch
            WatchSessionManager.shared.updateApplicationContext(mode: .connected)

            // Notifications
            registerNotifications(enabled: false)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        DLog("ControllerModeViewController deinit")
    }

    // MARK: - UI
    private func updateUartUI(isReady: Bool) {
        // Setup UI
        uartWaitingLabel.isHidden = isReady
        baseTableView.isHidden = !isReady
    }

    private let kDetailItemOffset = 100
    private func updateContentItemsFromSensorsEnabled() {
        // Add to contentItems the current rows (ControllerType.rawValue for each sensor and kDetailItemOffset+ControllerType.rawValue for a detail cell)
        
        let availableControllers: [ControllerModuleManager.ControllerType]
        #if targetEnvironment(macCatalyst)
        // Only location is available on macCatalyst
        availableControllers = [.location]
        #else
        availableControllers = ControllerModuleManager.ControllerType.allCases
        #endif
        
        var items = [Int]()
        availableControllers.forEach { controllerType in
            
            let isSensorEnabled = controllerData.isSensorEnabled(controllerType: controllerType)
            items.append(controllerType.rawValue)
            if isSensorEnabled {
                items.append(controllerType.rawValue+kDetailItemOffset)
            }
        }

        contentItems = items
    }

    // MARK: Notifications
    private weak var didReceiveWatchCommandObserver: NSObjectProtocol?

    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default
        if enabled {
            didReceiveWatchCommandObserver = notificationCenter.addObserver(forName: .didReceiveWatchCommand, object: nil, queue: .main, using: {[weak self] notification in self?.didReceiveWatchCommand(notification: notification)})
        } else {
            if let didReceiveWatchCommandObserver = didReceiveWatchCommandObserver {notificationCenter.removeObserver(didReceiveWatchCommandObserver)}
        }
    }

    private func didReceiveWatchCommand(notification: Notification) {
        if let message = notification.userInfo, let command = message["command"] as? String {
            DLog("watchCommand notification: \(command)")
            switch command {
            case "controlPad":
                if let tag = (message["tag"] as AnyObject).integerValue {
                    sendTouchEvent(tag: tag, isPressed: true)
                    sendTouchEvent(tag: tag, isPressed: false)
                }

            case "color":
                if  let colorUInt = message["color"] as? UInt, let color = colorFrom(hex: colorUInt) {
                    sendColor(color)
                }

            default:
                DLog("watchCommand with unknown command: \(command)")
            }
        }
    }

    // MARK: - Actions
    @IBAction func onClickHelp(_  sender: UIBarButtonItem) {
        let localizationManager = LocalizationManager.shared
        #if targetEnvironment(macCatalyst)
        let helpText = localizationManager.localizedString("controller_help_text_mac")
        #else
        let helpText = localizationManager.localizedString("controller_help_text_ios_android")
        #endif
        
        let helpViewController = storyboard!.instantiateViewController(withIdentifier: "HelpViewController") as! HelpViewController
        helpViewController.setHelp(helpText, title: localizationManager.localizedString("controller_help_title"))
        let helpNavigationController = UINavigationController(rootViewController: helpViewController)
        helpNavigationController.modalPresentationStyle = .popover
        helpNavigationController.popoverPresentationController?.barButtonItem = sender

        present(helpNavigationController, animated: true, completion: nil)
    }

    // MARK: - Send Data
    private func sendColor(_ color: UIColor) {
        let brightness: CGFloat = 1
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: nil)
        red = red*brightness
        green = green*brightness
        blue = blue*brightness

        let selectedColorComponents = [UInt8(255.0 * Float(red)), UInt8(255.0 * Float(green)), UInt8(255.0 * Float(blue))]

        sendColorComponents(selectedColorComponents)
    }

    private func sendColorComponents(_ selectedColorComponents: [UInt8]) {
        var data = Data()
        let prefixData = ControllerColorWheelViewController.prefix.data(using: String.Encoding.utf8)!
        data.append(prefixData)
        for var component in selectedColorComponents {
            data.append(&component, count: MemoryLayout<UInt8>.size)
        }

        controllerData.sendCrcData(data)
    }

    func sendTouchEvent(tag: Int, isPressed: Bool) {
        let message = "!B\(tag)\(isPressed ? "1" : "0")"
        if let data = message.data(using: String.Encoding.utf8) {
            controllerData.sendCrcData(data)
        }
    }
    
    func sendWordSaveEvent(assignments: (String,String)) {
        print(assignments)
        let wordSave = "!W"
//        controllerData.sendCrcData(wordSave.data(using:String.Encoding.utf8)!)
        let saveString = wordSave + assignments.0 +  assignments.1.padding(toLength: 10, withPad: " ", startingAt: 0)
        controllerData.sendCrcData(saveString.data(using:String.Encoding.utf8)!)
    }
    
    func sendSaveEvent(enableDict: [Int:Bool]) {
//        var data = Data()
        var totalString = "!S"
//        controllerData.sendCrcData(totalString.data(using: String.Encoding.utf8)!)
//        let prefixData = prefix.data(using: String.Encoding.utf8)!
//        data.append(prefixData)
        for (num,enable) in enableDict {
            var encodedEnable = "F"
            if (enable) {
                encodedEnable = "T"
            }
            var saveString = "\(num),\(encodedEnable);"
            saveString = totalString + saveString
            controllerData.sendCrcData(saveString.data(using: String.Encoding.utf8)!)
        }
//        if let data = totalString.data(using: String.Encoding.utf8) {
//            print(data)
//            print(String(decoding: data, as: UTF8.self))
//    //        var newData = Data()
//    //        newData.append(prefixData)
////            controllerData.sendCrcData(data)
//        }
////        let message = "!B\(tag)\(isPressed ? "1" : "0")"
        
    }
}

// MARK: - ControllerColorWheelViewControllerDelegate
extension ControllerModeViewController: ControllerColorWheelViewControllerDelegate {
    func onSendColorComponents(_ colorComponents: [UInt8]) {
        sendColorComponents(colorComponents)
    }
}

// MARK: - ControllerPadViewControllerDelegate
extension ControllerModeViewController: ControllerPadViewControllerDelegate {
    func onSendControllerPadButtonStatus(tag: Int, isPressed: Bool) {
        sendTouchEvent(tag: tag, isPressed: isPressed)
    }
}

extension ControllerModeViewController: TalkBoxViewControllerDelegate {
    func onSendTalkBoxButtonStatus(tag: Int, isPressed: Bool) {
        sendTouchEvent(tag: tag, isPressed: isPressed)
    }
    func onSendTalkBoxSave(enableDict: [Int:Bool]) {
        sendSaveEvent(enableDict: enableDict)
    }
}

extension ControllerModeViewController: WordAssignmentsViewControllerDelegate {
    func onSendWordSave(assignment assignments: (String, String)) {
        sendWordSaveEvent(assignments: assignments)
    }
}
// MARK: - UITableViewDataSource
extension ControllerModeViewController : UITableViewDataSource {
    private static let kSensorTitleKeys: [String] = ["controller_sensor_quaternion", "controller_sensor_accelerometer", "controller_sensor_gyro", "controller_sensor_magnetometer", "controller_sensor_location"]
    private static let kModuleTitleKeys: [String] = ["controller_module_pad", "controller_module_colorpicker", "talk_box_configure", "word_assignments"]
    
    enum ControllerSection: Int {
        case sensorData = 0
        case module = 1
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch ControllerSection(rawValue: section)! {
        case .sensorData:
            //let enabledCount = sensorsEnabled.filter{ $0 }.count
            //return ControllerModeViewController.kSensorTitleKeys.count + enabledCount
            return contentItems.count
        case .module:
            return ControllerModeViewController.kModuleTitleKeys.count
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        var localizationKey: String!

        switch ControllerSection(rawValue: section)! {
        case .sensorData:
            localizationKey = "controller_sensor_title"
        case .module:
            localizationKey = "controller_module_title"
        }

        return LocalizationManager.shared.localizedString(localizationKey)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let localizationManager = LocalizationManager.shared
        var cell: UITableViewCell!
        switch ControllerSection(rawValue: indexPath.section)! {

        case .sensorData:
            let item = contentItems[indexPath.row]
            let isDetailCell = item>=kDetailItemOffset

            if isDetailCell {
                let controllerType = ControllerModuleManager.ControllerType(rawValue: item - kDetailItemOffset)!
                let reuseIdentifier = "ComponentsCell"
                let componentsCell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! ControllerComponentsTableViewCell
                
                if let sensorData = controllerData.getSensorData(controllerType: controllerType) {
                    let componentNameId: [String]
                    if controllerType == ControllerModuleManager.ControllerType.location {
                        componentNameId = ["controller_component_lat", "controller_component_long", "controller_component_alt"]
                    } else {
                        componentNameId = ["controller_component_x", "controller_component_y", "controller_component_z", "controller_component_w"]
                    }
                    
                    var i=0
                    for subview in componentsCell.componentsStackView.subviews {
                        let hasComponent = i<sensorData.count
                        subview.isHidden = !hasComponent
                        if let label = subview as? UILabel, hasComponent {
                            let componentName = LocalizationManager.shared.localizedString(componentNameId[i])
                            let attributedText = NSMutableAttributedString(string: "\(componentName): \(sensorData[i])")
                            let titleLength = componentName.lengthOfBytes(using: String.Encoding.utf8)
                            attributedText.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: 12, weight: UIFont.Weight.medium), range: NSMakeRange(0, titleLength))
                            label.attributedText = attributedText
                        }

                        i += 1
                    }
                } else {
                    for subview in componentsCell.componentsStackView.subviews {
                        subview.isHidden = true
                    }
                }

                cell = componentsCell
            } else {
                let controllerType = ControllerModuleManager.ControllerType(rawValue: item)!
                let reuseIdentifier = "SensorCell"
                let sensorCell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! ControllerSensorTableViewCell
                sensorCell.titleLabel!.text = localizationManager.localizedString( ControllerModeViewController.kSensorTitleKeys[item])

                sensorCell.enableSwitch.isOn = controllerData.isSensorEnabled(controllerType: controllerType)
                sensorCell.onSensorEnabled = { [unowned self] (enabled) in

                    if self.controllerData.isSensorEnabled(controllerType: controllerType) != enabled {       // if changed
                        let errorMessage = self.controllerData.setSensorEnabled(enabled, controllerType:controllerType)

                        if let errorMessage = errorMessage {
                            let alertController = UIAlertController(title: localizationManager.localizedString("dialog_error"), message: errorMessage, preferredStyle: .alert)

                            let okAction = UIAlertAction(title: localizationManager.localizedString("dialog_ok"), style: .default, handler:nil)
                            alertController.addAction(okAction)
                            self.present(alertController, animated: true, completion: nil)
                        }

                        self.updateContentItemsFromSensorsEnabled()

                        /* Not used because the animation for the section title looks weird. Used a reloadData instead
                        if let currentRow = self.contentItems.indexOf(item) {
                            let detailIndexPath = NSIndexPath(forRow: currentRow+1, inSection: indexPath.section)
                            if enabled {
                                tableView.insertRowsAtIndexPaths([detailIndexPath], withRowAnimation: .Top)
                            }
                            else {
                                tableView.deleteRowsAtIndexPaths([detailIndexPath], withRowAnimation: .Bottom)
                            }
                        }
                        */

                    }

                    self.baseTableView.reloadData()
                }
                cell = sensorCell
            }

        case .module:
            let reuseIdentifier = "ModuleCell"
            cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
            if cell == nil {
                cell = UITableViewCell(style: .default, reuseIdentifier: reuseIdentifier)
            }
            cell.accessoryType = .disclosureIndicator
            cell.textLabel!.text = localizationManager.localizedString(ControllerModeViewController.kModuleTitleKeys[indexPath.row])
        }

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch ControllerSection(rawValue: indexPath.section)! {
        case .sensorData:
            let item = contentItems[indexPath.row]
            let isDetailCell = item>=kDetailItemOffset
            return isDetailCell ? 120: 44
        default:
            return 44
        }
    }
}

// MARK: UITableViewDelegate
extension ControllerModeViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        switch ControllerSection(rawValue: indexPath.section)! {
        case .module:
            if indexPath.row == 0 {
                if let viewController = storyboard!.instantiateViewController(withIdentifier: "ControllerPadViewController") as? ControllerPadViewController {
                    controllerPadViewController = viewController
                    viewController.delegate = self
                    navigationController?.show(viewController, sender: self)

                    // Enable cache for control pad
                    controllerData.uartRxCacheReset()
                    controllerData.isUartRxCacheEnabled = true
                }
            } else if indexPath.row == 1 {
                if let viewController = storyboard!.instantiateViewController(withIdentifier: "ControllerColorWheelViewController") as? ControllerColorWheelViewController {
                    viewController.delegate = self
                    navigationController?.show(viewController, sender: self)
                }
            } else if indexPath.row == 2 {
                if let viewController = storyboard!.instantiateViewController(withIdentifier: "TalkBoxViewController") as? TalkBoxViewController {
                    talkBoxViewController = viewController
                    viewController.delegate = self
                    navigationController?.show(viewController, sender: self)

                    // Enable cache for control pad
                    controllerData.uartRxCacheReset()
                    controllerData.isUartRxCacheEnabled = true
                }
            }
            else if indexPath.row == 3 {
                if let viewController = storyboard!.instantiateViewController(withIdentifier: "WordAssignmentsViewController") as? WordAssignmentsViewController {
                    wordAssignmentsViewController = viewController
                    viewController.delegate = self
                    navigationController?.show(viewController, sender: self)

                    // Enable cache for control pad
                    controllerData.uartRxCacheReset()
                    controllerData.isUartRxCacheEnabled = true
                }
            }
        default:
            break
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - ControllerModuleManagerDelegate
extension ControllerModeViewController: ControllerModuleManagerDelegate {
    func onControllerUartIsReady(error: Error?) {
        DispatchQueue.main.async {
            self.updateUartUI(isReady: error == nil)
            guard error == nil else {
                DLog("Error initializing uart")
                self.dismiss(animated: true, completion: { [weak self] in
                    guard let context = self else { return }
                    let localizationManager = LocalizationManager.shared
                    showErrorAlert(from: context, title: localizationManager.localizedString("dialog_error"), message: localizationManager.localizedString("uart_error_peripheralinit"))
                    
                    if let blePeripheral = context.blePeripheral {
                        BleManager.shared.disconnect(from: blePeripheral)
                    }
                })
                return
            }

            // Uart Ready
            self.baseTableView.reloadData()
        }
    }

    func onUarRX() {
        // Uart data recevied

        // Only reloadData when controllerPadViewController is loaded
        guard (talkBoxViewController != nil || controllerPadViewController != nil || wordAssignmentsViewController != nil) else { return }

        self.enh_throttledReloadData()      // it will call self.reloadData without overloading the main thread with calls
    }

    @objc func reloadData() {
        // Refresh the controllerPadViewController uart text
        self.controllerPadViewController?.setUartText(self.controllerData.uartTextBuffer())
        self.talkBoxViewController?.setUartText(self.controllerData.uartTextBuffer())
        self.wordAssignmentsViewController?.setUartText(self.controllerData.uartTextBuffer())

    }
}
