//
//  ViewController.swift
//  SendFormatMail
//
//  Created by Norizou on 2016/02/28.
//  Copyright © 2016年 Nori. All rights reserved.
/*
　　メール定型文作成アプリ、多分自分以外は使い道がないと思われる
　　　swift3、iOS10に合わせて作りました。
　　メールを作成した日に合わせて、件名、本文の日付を変えたメールを作成する
　　例えば、今日が15日だった場合、本文中にあるlastWeekDDの文字列を、一週間前の日である8日に変換したりする
　　細かい仕様は以下のメソッドを参照
　　　件名：exchangeSubject
　　　本文：exchangeMessageBody
　　件名、本文、宛先、添付画像は一度作成してsaveするか、メールを送信することで保存される
　　次から、変更無しで送ることができる
　　添付画像は縦長であることが前提です
　　TODO 送信メールアドレスを選べるようにしたい
　　TODO 署名を無しで送れるようにしたい
　　TODO 送信日時も指定したい
 */

import UIKit
import MessageUI
import Photos

class ViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate, MFMailComposeViewControllerDelegate , UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIPickerViewDelegate, UIPickerViewDataSource {
    
    @IBOutlet weak var sendDateText: UITextField!
    @IBOutlet weak var toText: UITextField!
    @IBOutlet weak var ccText: UITextField!
    @IBOutlet weak var subjectText: UITextField!
    @IBOutlet weak var attachText: UITextField!
    @IBOutlet weak var insertStatementText: UITextField!
    @IBOutlet weak var messageBodyText: UITextView!
    @IBOutlet weak var saveBtm: UIBarButtonItem!
    @IBOutlet weak var sendBtm: UIBarButtonItem!
    
    var datePicker1: UIDatePicker!
    let defDateString = "2000-01-01"
    let minDateString = "1900-01-01"
    let maxDateString = "2100-01-01"
    
    // １つめのピッカーに表示されるアイテム、挿入文insertText
    let picker1Items: NSArray = [
        "test1",
        "test2",
        "test3",
        "test4",
        "test5",
        "test6",
        "test7",
        "test8",
        "test9",
        "test10",
        "test11"
    ]
    
    var myPickerView: UIPickerView!
    // 何番目の挿入文を選択肢ているか
    var insertStatementSelectIndex: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // 保存していた情報の復元
        let defaults = UserDefaults.standard
        toText.text = defaults.string(forKey: "toText")
        ccText.text = defaults.string(forKey: "ccText")
        subjectText.text = defaults.string(forKey: "subjectText")
        attachText.text = defaults.string(forKey: "attachText")
        insertStatementSelectIndex = defaults.integer(forKey: "insertStatementSelectIndex")
        messageBodyText.text = defaults.string(forKey: "messageBodyText")
        
        ///// 日付選択ピッカー
        // テキストフィールドにDatePickerを表示する
        datePicker1 = UIDatePicker()
        datePicker1.addTarget(self, action: #selector(ViewController.changedDateEvent(sender: )), for: UIControlEvents.valueChanged)
        // 日本の日付表示形式にする、年月日の表示にする
        datePicker1.datePickerMode = UIDatePickerMode.date
        // 最小値、最大値、初期値を設定
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-DD"
        datePicker1.minimumDate = dateFormatter.date(from: minDateString)
        datePicker1.maximumDate = dateFormatter.date(from: maxDateString)
        datePicker1.date = Date()
        self.changeLabelDate(date: datePicker1.date as NSDate)
        sendDateText.inputView = datePicker1
        
        //// 挿入文選択ピッカー
        //PickerView作成
        myPickerView = UIPickerView()
        myPickerView.delegate = self
        myPickerView.dataSource = self
        
        // UITextField の入力としてこのピッカーを使用するよう設定
        insertStatementText.placeholder = picker1Items[insertStatementSelectIndex] as? String
        insertStatementText.inputView = myPickerView
        
        // toText の情報を受け取るための delegate を設定
        sendDateText.delegate = self
        toText.delegate = self
        ccText.delegate = self
        subjectText.delegate = self
        attachText.delegate = self
        insertStatementText.delegate = self
        messageBodyText.delegate = self
        
        
        // 仮のサイズでツールバー生成
        let kbToolBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 40))
        kbToolBar.barStyle = UIBarStyle.default  // スタイルを設定
        kbToolBar.sizeToFit()  // 画面幅に合わせてサイズを変更
        // スペーサー
        let spacer = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: self, action: nil)
        // 閉じるボタン
        let commitButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.done, target: self, action: #selector(ViewController.commitButtonTapped))
        kbToolBar.items = [spacer, commitButton]
        messageBodyText.inputAccessoryView = kbToolBar

    }
    
    override func viewDidAppear(_ animated: Bool) {
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // 画面の適当なところをタッチした時、キーボードを隠す
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        super.touchesEnded(touches, with: event)
        sendDateText.resignFirstResponder()
        toText.resignFirstResponder()
        ccText.resignFirstResponder()
        subjectText.resignFirstResponder()
        attachText.resignFirstResponder()
        insertStatementText.resignFirstResponder()
        
        for touch: AnyObject in touches {
            let t: UITouch = touch as! UITouch
            if t.view!.tag == self.messageBodyText.tag {
                NSLog("Label touched")
            }
        }
    }
    
    // 書式指定に従って日付を文字列に変換します
    // パラメータ
    //  date : 日付データ(NSDate型)を指定します
    //  style : 書式を指定します
    //          yyyy 西暦,MM 月,dd 日,HH 時,mm 分,ss 秒
    //
    func format(date : NSDate, style : String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = NSLocale(localeIdentifier: "ja_JP") as Locale!
        dateFormatter.dateFormat = style
        return  dateFormatter.string(from: date as Date)
    }
    
    // 日付の変更イベント
    func changedDateEvent(sender:AnyObject?){
        self.changeLabelDate(date: datePicker1.date as NSDate)
    }
    // 日付の変更
    func changeLabelDate(date:NSDate) {
        sendDateText.text = format(date: datePicker1.date as NSDate,style: "yyyy年 MM月 dd日")
    }
    
    // 名前の入力完了時に閉じる
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendDateText.resignFirstResponder()
        toText.resignFirstResponder()
        ccText.resignFirstResponder()
        subjectText.resignFirstResponder()
        attachText.resignFirstResponder()
        insertStatementText.resignFirstResponder()
        messageBodyText.resignFirstResponder()
        return true
    }
    
    @IBAction func saveBtm(_ sender: AnyObject) {
        saveInfo()
    }
    @IBAction func startMailerBtm(_ sender: AnyObject) {
        saveInfo()
        startMailer()
    }
    @IBAction func selectPhoto(_ sender: AnyObject) {
        pickImageFromLibrary()
    }
    
    // 保存
    func saveInfo() {
        let defaults = UserDefaults.standard
        //        defaults.setObject(sendDateText.text, forKey: "sendDateText")
        defaults.set(toText.text, forKey: "toText")
        defaults.set(ccText.text, forKey: "ccText")
        defaults.set(subjectText.text, forKey: "subjectText")
        defaults.set(attachText.text, forKey: "attachText")
        defaults.set(insertStatementSelectIndex, forKey: "insertStatementSelectIndex")
        defaults.set(messageBodyText.text, forKey: "messageBodyText")
        defaults.synchronize()
    }
    
    // メーラー起動
    func startMailer() {
        if MFMailComposeViewController.canSendMail()==false {
            print("Email Send Failed")
            return
        }
        
        let mailViewController = MFMailComposeViewController()
        let toRecipients = toText.text!.components(separatedBy: ",")
        let CcRecipients = ccText.text!.components(separatedBy: ",")
        let subjectTextStr = exchangeSubject(subject: subjectText.text!)
        let messageBodyTextStr = exchangeMessageBody(subject: messageBodyText.text!)
        
        mailViewController.mailComposeDelegate = self
        mailViewController.setSubject(subjectTextStr)
        mailViewController.setToRecipients(toRecipients) //Toアドレスの表示
        mailViewController.setCcRecipients(CcRecipients) //Ccアドレスの表示
        mailViewController.setMessageBody(messageBodyTextStr, isHTML: false)
        
        let tmp = NSTemporaryDirectory()+"/test.png"
        let img = UIImage(named: tmp)
        if img != nil {
            let imageDataq = UIImageJPEGRepresentation(img!, 1.0)
            mailViewController.addAttachmentData(imageDataq!, mimeType: "image/png", fileName: "image")
        }
        
        self.present(mailViewController, animated: true, completion: nil)
    }
    
    // メールキャンセル
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        
        switch result.rawValue {
        case MFMailComposeResult.cancelled.rawValue:
            print("Email Send Cancelled")
            break
        case MFMailComposeResult.saved.rawValue:
            print("Email Saved as a Draft")
            break
        case MFMailComposeResult.sent.rawValue:
            print("Email Sent Successfully")
            break
        case MFMailComposeResult.failed.rawValue:
            print("Email Send Failed")
            break
        default:
            break
        }
        
        self.dismiss(animated: true, completion: nil)
    }
    
    // 件名の変換
    func exchangeSubject(subject: String) -> String {
        // 日付の変換 YYYY MM DD
        var cal = Calendar.current
        // *** define calendar components to use as well Timezone to UTC ***
        let unitFlags = Set<Calendar.Component>([.hour, .year, .minute])
        cal.timeZone = TimeZone(identifier: "UTC")!
        //        let comp = cal.components(
        //            [NSCalendar.Unit.Year, NSCalendar.Unit.Month, NSCalendar.Unit.Day,
        //                NSCalendar.Unit.Hour, NSCalendar.Unit.Minute, NSCalendar.Unit.Second],
        //            fromDate: datePicker1.date)
        let comp = cal.dateComponents(unitFlags, from: datePicker1.date as Date)
        
        // 返還前：aaa：YYYY年MM月DD日bbb
        // 返還後：aaa：2016年2月24日bbb
        var str:String = subject
        //        str = str.stringByReplacingOccurrencesOfString("YYYY", withString: String(comp.year))
        //        str = str.stringByReplacingOccurrencesOfString("MM", withString: String(comp.month))
        //        str = str.stringByReplacingOccurrencesOfString("DD", withString: String(comp.day))
        str = str.replacingOccurrences(of: "YYYY", with: String(describing: comp.year))
        str = str.replacingOccurrences(of: "MM", with: String(describing: comp.month))
        str = str.replacingOccurrences(of: "DD", with: String(describing: comp.day))
        
        return str
    }
    
    // 本文の変換、メールを送るときに呼ばれる
    func exchangeMessageBody(subject: String) -> String {
        // 日付の変換 YYYY MM DD
        var cal = Calendar.current
        // *** define calendar components to use as well Timezone to UTC ***
        let unitFlags = Set<Calendar.Component>([.hour, .year, .minute])
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comp = cal.dateComponents(unitFlags, from: datePicker1.date as Date)
        
        // 今日
        var str:String = subject
        str = str.replacingOccurrences(of: "TodayYYYY", with: String(describing: comp.year))
        str = str.replacingOccurrences(of: "TodayMM", with: String(describing: comp.month))
        str = str.replacingOccurrences(of: "TodayDD", with: String(describing: comp.day))
        
        // 昨日
        let yesterdayDate = Date(timeInterval: -60*60*24, since: datePicker1.date)
        let yesterdayComp = cal.dateComponents(unitFlags, from: yesterdayDate as Date)
        str = str.replacingOccurrences(of: "yesterdayYYYY", with: String(describing: yesterdayComp.year))
        str = str.replacingOccurrences(of: "yesterdayMM", with: String(describing: yesterdayComp.month))
        str = str.replacingOccurrences(of: "yesterdayDD", with: String(describing: yesterdayComp.day))
        
        // 一週間前
        let lastWeekDate = Date(timeInterval: -60*60*24*7, since: datePicker1.date)
        let lastWeekComp = cal.dateComponents(unitFlags, from: lastWeekDate as Date)
        str = str.replacingOccurrences(of: "lastWeekYYYY", with: String(describing: lastWeekComp.year))
        str = str.replacingOccurrences(of: "lastWeekMM", with: String(describing: lastWeekComp.month))
        str = str.replacingOccurrences(of: "lastWeekDD", with: String(describing: lastWeekComp.day))
        
        // 挿入文の置換
        str = str.replacingOccurrences(of: "insertText", with: insertStatementText.text!)
        return str
    }
    
    /**
     ライブラリから写真を選択する
     */
    func pickImageFromLibrary() {
        
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.photoLibrary) {    //追記
            
            //写真ライブラリ(カメラロール)表示用のViewControllerを宣言しているという理解
            let controller = UIImagePickerController()
            
            //おまじないという認識で今は良いと思う
            controller.delegate = self
            
            //新しく宣言したViewControllerでカメラとカメラロールのどちらを表示するかを指定
            //以下はカメラロールの例
            //.Cameraを指定した場合はカメラを呼び出し(シミュレーター不可)
            controller.sourceType = UIImagePickerControllerSourceType.photoLibrary
            
            //新たに追加したカメラロール表示ViewControllerをpresentViewControllerにする
            self.present(controller, animated: true, completion: nil)
        }
    }
    
    /**
     画像が選択された時に呼ばれる.
     TODO warningでprivateをつけろとでるけど、付けたらこの処理が呼ばれない。
     */
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        
        let toURL = URL(fileURLWithPath: NSTemporaryDirectory()+"/test.png")
        //選択された画像を取得.
        let myImage: AnyObject?  = info[UIImagePickerControllerOriginalImage]
        let resizeImage = resize(image: myImage as! UIImage, width: 320, height: 480)
        let data = UIImagePNGRepresentation(resizeImage)!
        //data.writeToURL(toURL, atomically: true)
        do {
            try data.write(to: toURL, options: .atomic)
        } catch {
            print(error)
        }
        
        attachText.text = toURL.absoluteString

/*        //このif条件はおまじないという認識で今は良いと思う
        if didFinishPickingMediaWithInfo[UIImagePickerControllerOriginalImage] != nil {
            let toURL = URL(fileURLWithPath: NSTemporaryDirectory()+"/test.png")
            let image = didFinishPickingMediaWithInfo[UIImagePickerControllerOriginalImage] as! UIImage
            // 画像をリサイズ
            // TODO ここでは、縦のサイズだけ使うけど、引数はそのままにしておく
            // 縦長、の写真を想定
            let resizeImage = resize(image: image, width: 320, height: 480)
            let data = UIImagePNGRepresentation(resizeImage)!
            //data.writeToURL(toURL, atomically: true)
            do {
                try data.write(to: toURL, options: .atomic)
            } catch {
                print(error)
            }
        }
 */
        //写真選択後にカメラロール表示ViewControllerを引っ込める動作
        picker.dismiss(animated: true, completion: nil)
    }
    
    // 画像をリサイズ
    func resize(image: UIImage, width: Int, height: Int) -> UIImage {
        let imageRef: CGImage = image.cgImage!
        let sourceWidth: Int = imageRef.width
        let sourceHeight: Int = imageRef.height
        
        // すでに高さが480以下ならそのままリターンする
        if height > sourceHeight {return image}
        
        // 縦横比は合わせるよ
        let newWidth = sourceWidth*height/sourceHeight
        
        let size: CGSize = CGSize(width: newWidth, height: height)
        UIGraphicsBeginImageContext(size)
        image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        let resizeImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizeImage!
    }
    
    /**
     画像選択がキャンセルされた時に呼ばれる.
     */
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        // モーダルビューを閉じる
        self.dismiss(animated: true, completion: nil)
    }
    
    // 挿入文の選択時の処理　ここから
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return picker1Items.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        insertStatementSelectIndex = row
        return picker1Items[row] as? String
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        insertStatementText.text = picker1Items[row] as? String
    }
    // 挿入文の選択時の処理　ここまで
    
    //閉じる
    func onClick(sender: UIBarButtonItem) {
        insertStatementText.resignFirstResponder()
    }
    
    // messageBodyTextを閉じる処理
    func commitButtonTapped (){
        self.view.endEditing(true)
    }
}

