//
//  WordChoiceViewController.swift
//  Bluefruit
//
//  Created by Mihir Trivedi on 12/4/21.
//  Copyright © 2021 Adafruit. All rights reserved.
//

import UIKit

protocol WordAssignmentsViewControllerDelegate: class {
//    func onSendWordButtonStatus(tag: Int, isPressed: Bool)
    func onSendWordSave(assignment: (String, String))
}

class WordAssignmentsViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {

    // UI
//    @IBOutlet weak var directionsView: UIView!

    @IBOutlet weak var uartTextView: UITextView!
    
    @IBOutlet weak var uartView: UIView!
    @IBOutlet weak var button_number_selector: UIPickerView!
    
    @IBOutlet weak var word_picker: UIPickerView!
    
    // Data
    weak var delegate: WordAssignmentsViewControllerDelegate?

    @IBOutlet weak var saveButton2: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()

        // UI
        uartView.layer.cornerRadius = 4
        uartView.layer.masksToBounds = true
        
        word_picker!.delegate = self
        word_picker!.dataSource = self
        
        button_number_selector!.delegate = self
        button_number_selector!.dataSource = self
        
        // Setup buttons targets
//        for subview in directionsView.subviews {
//            if let button = subview as? UIButton {
//                setupButton(button)
//            }
//        }

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Fix: remove the UINavigationController pop gesture to avoid problems with the arrows left button
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.navigationController?.interactivePopGestureRecognizer?.delaysTouchesBegan = false
            self.navigationController?.interactivePopGestureRecognizer?.delaysTouchesEnded = false
            self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    //MARK: - Pickers
    var button_number_choices = [1,2,3,4,5,6,7,8]
    var word_choices = ["more","next","yes","no","slow","music","bathroom","fast","all done","TV","swing","outside","mom","dad","sister","brother","hurt ","play","tired","sleep", "drink", "help", "hug", "hungry", "pause", "play", "skip", "walk"]
    public func numberOfComponents(in pickerView: UIPickerView) -> Int{
            return 1
        }

    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int{
        if pickerView == word_picker {
            return word_choices.count
        } else {
            return button_number_choices.count
        }
        
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == word_picker {
            return String(word_choices[row])
        } else {
            return String(button_number_choices[row])
        }
        
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
//        self.textBox.text = self.list[row]
//        self.word_picker.isHidden = true
    }

    // MARK: - UI
    private func setupButton(_ button: UIButton) {
        print("run!")
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.masksToBounds = true

        button.setTitleColor(UIColor.lightGray, for: .highlighted)

        let hightlightedImage = UIImage(color: UIColor.darkGray)
        button.setBackgroundImage(hightlightedImage, for: .highlighted)
        

        button.addTarget(self, action: #selector(onTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(onTouchUp(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(onTouchUp(_:)), for: .touchDragExit)
        button.addTarget(self, action: #selector(onTouchUp(_:)), for: .touchCancel)
//        buttonStates[button.tag] = true
    }

    func setUartText(_ text: String) {

        // Remove the last character if is a newline character
        let lastCharacter = text.last
        let shouldRemoveTrailingNewline = lastCharacter == "\n" || lastCharacter == "\r" //|| lastCharacter == "\r\n"
        //let formattedText = shouldRemoveTrailingNewline ? text.substring(to: text.index(before: text.endIndex)) : text
        let formattedText = shouldRemoveTrailingNewline ? String(text[..<text.index(before: text.endIndex)]) : text
        
        //
        uartTextView.text = formattedText

        // Scroll to bottom
        let bottom = max(0, uartTextView.contentSize.height - uartTextView.bounds.size.height)
        uartTextView.setContentOffset(CGPoint(x: 0, y: bottom), animated: true)
        /*
        let textLength = text.characters.count
        if textLength > 0 {
            let range = NSMakeRange(textLength - 1, 1)
            uartTextView.scrollRangeToVisible(range)
        }*/
    }

    // MARK: - Actions
    @objc func onTouchDown(_ sender: UIButton) {
        print("touched", sender.tag);
//        sendTouchEvent(tag: sender.tag, isPressed: true)
    }

    @objc func onTouchUp(_ sender: UIButton) {
//        sendTouchEvent(tag: sender.tag, isPressed: false)
//        buttonStates[sender.tag] = !buttonStates[sender.tag]!
//        let disabledImage = UIImage(color: UIColor.darkGray)
//        let enabledImage = UIImage(color: UIColor(red: 25/255, green: 126/255, blue: 248/255, alpha: 1.0))
//        if (buttonStates[sender.tag]!) {
//            sender.setBackgroundImage(enabledImage, for: .normal)
//        } else {
//            sender.setBackgroundImage(disabledImage, for: .normal)
//        }
        
//        print(buttonStates[sender.tag])
    }

//    private func sendTouchEvent(tag: Int, isPressed: Bool) {
//        if let delegate = delegate {
//            delegate.onSendWordButtonStatus(tag: tag, isPressed: isPressed)
//        }
//    }
    
    @IBAction func saveClicked(_ sender: UIButton) {
        let button_num = String(button_number_choices[button_number_selector.selectedRow(inComponent: 0)])
        let word_choice = word_choices[word_picker.selectedRow(inComponent: 0)]
        if let delegate = delegate {
            delegate.onSendWordSave(assignment: (button_num, word_choice))
        }
//        if let delegate = delegate {
//            delegate.onSendTalkBoxSave(enableDict: buttonStates)
//        }
    }
    
    @IBAction func volumeChanged(_ sender: UISlider) {
        print(sender.value);
    }
    
    @IBAction func onClickHelp(_ sender: UIBarButtonItem) {
        let localizationManager = LocalizationManager.shared
        let helpViewController = storyboard!.instantiateViewController(withIdentifier: "HelpViewController") as! HelpViewController
        helpViewController.setHelp(localizationManager.localizedString("controlpad_help_text"), title: localizationManager.localizedString("controlpad_help_title"))
        let helpNavigationController = UINavigationController(rootViewController: helpViewController)
        helpNavigationController.modalPresentationStyle = .popover
        helpNavigationController.popoverPresentationController?.barButtonItem = sender

        present(helpNavigationController, animated: true, completion: nil)
    }
}
