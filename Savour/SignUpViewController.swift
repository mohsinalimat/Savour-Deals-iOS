//
//  SignUpViewController.swift
//  Savour
//
//  Created by Chris Patterson on 8/1/17.
//  Copyright © 2017 Chris Patterson. All rights reserved.
//

import UIKit
import Firebase
import FBSDKCoreKit
import FBSDKLoginKit

class SignUpViewController: UIViewController, FBSDKLoginButtonDelegate{

    @IBOutlet weak var img: UIImageView!
    @IBOutlet weak var NameField: UITextField!
    @IBOutlet weak var EmailField: UITextField!
    @IBOutlet weak var SignupButton: UIButton!
    @IBOutlet weak var PasswordField: UITextField!
    var keyboardShowing = false
    var keyboardHeight: CGFloat!

    @IBOutlet weak var fbButton: FBSDKLoginButton!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var loadingView: UIView!
    @IBOutlet weak var loadingText: UILabel!
    
    @IBOutlet weak var loadingLabel: UIView!
    var handle: AuthStateDidChangeListenerHandle?
    var ref: DatabaseReference!
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if isUserVerified(user: Auth.auth().currentUser) {
            // User is signed in and verified.
            self.gotoMain()
        }
        else {
            // No user is not verified or signed in.
            ref = Database.database().reference()
            FBSDKLoginManager().logOut()
            fbButton.delegate = self
            fbButton.readPermissions = ["public_profile", "email", "user_friends"]

        }
        SignupButton.addTarget(self, action: #selector(SignupPressed), for: .touchUpInside)
        let statusBar = UIApplication.shared.value(forKey: "statusBar") as! UIView
        statusBar.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0)
        let rounded = EmailField.layer.frame.height/2
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = self.view.bounds
        gradientLayer.colors = [#colorLiteral(red: 0.2848863602, green: 0.6698332429, blue: 0.6656947136, alpha: 0).cgColor, #colorLiteral(red: 0.2848863602, green: 0.6698332429, blue: 0.6656947136, alpha: 0.4).cgColor]
        self.view.layer.insertSublayer(gradientLayer, at: 0)
        SignupButton.layer.cornerRadius = rounded
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        NameField.layer.borderColor = UIColor.white.cgColor
        NameField.layer.borderWidth = 2
        EmailField.layer.borderColor = UIColor.white.cgColor
        EmailField.layer.borderWidth = 2
        SignupButton.layer.borderColor = UIColor.white.cgColor
        SignupButton.layer.borderWidth = 2
        
        PasswordField.layer.borderColor = UIColor.white.cgColor
        PasswordField.layer.borderWidth = 2
        NameField.textColor = UIColor.white
        EmailField.textColor = UIColor.white
        PasswordField.textColor = UIColor.white
        NameField.layer.cornerRadius = rounded
        EmailField.layer.cornerRadius = rounded
        PasswordField.layer.cornerRadius = rounded
        loadingView.layer.cornerRadius = rounded
        // Obtain all constraints for the button:
        let layoutConstraintsArr = fbButton.constraints
        // Iterate over array and test constraints until we find the correct one:
        for lc in layoutConstraintsArr { // or attribute is NSLayoutAttributeHeight etc.
            if ( lc.constant == 28 ){
                // Then disable it...
                lc.isActive = false
                break
            }
        }

    }
    func isLoading(){
        loadingIndicator.startAnimating()
        loadingView.isHidden = false
        loadingLabel.isHidden = false
        SignupButton.isEnabled = false
        fbButton.isHidden = true
    }
    
    func doneLoading(){
        loadingIndicator.stopAnimating()
        loadingView.isHidden = true
        loadingLabel.isHidden = true
        SignupButton.isEnabled = true
        fbButton.isHidden = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // [START auth_listener]
        handle = Auth.auth().addStateDidChangeListener { (auth, user) in
            // [START_EXCLUDE]
            // [END_EXCLUDE]
        }
        // [END auth_listener]
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // [START remove_auth_listener]
        Auth.auth().removeStateDidChangeListener(handle!)
        // [END remove_auth_listener]
    }

 

    
    @objc func SignupPressed(_ sender: Any) {
        loadingText.text = "Signing Up"

        isLoading()
        if let password = PasswordField.text, let email = EmailField.text, let name = NameField.text {//let username = UsernameField.text {
            // [START create_user]
            //let userDict = ["Username": username]
            Auth.auth().createUser(withEmail: email, password: password) { (user, error) in
                // [START_EXCLUDE]
                user?.user.sendEmailVerification(completion: { (err) in
                    if err != nil{
                        print(err!)
                    }
                })
                if let error = error {
                    let alert = UIAlertController(title: "Alert", message: error.localizedDescription, preferredStyle: UIAlertController.Style.alert)
                    alert.addAction(UIAlertAction(title: "Okay", style: UIAlertAction.Style.default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                    return
                }
                self.ref = Database.database().reference()
                
                self.ref.child("Users").child(user!.user.uid).child("full_name").setValue(name)
                self.ref.child("Users").child(user!.user.uid).child("email").setValue(email)
                if let user = user {
                    let changeRequest = user.user.createProfileChangeRequest()
                    
                    changeRequest.displayName = name
                    //changeRequest.photoURL =
                    changeRequest.commitChanges { error in
                        if error != nil {
                            // An error happened.
                        } else {
                            // Profile updated.
                        }
                    }
                }
                let alert = UIAlertController(title: "Verify Email", message: "Please check your email to verify your account. Then come back to login!", preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "Okay", style: UIAlertAction.Style.default, handler: nil))
                alert.addAction(UIAlertAction(title: "Resend Email", style: UIAlertAction.Style.default, handler: { (alert: UIAlertAction!) in
                    user?.user.sendEmailVerification(completion: { (err) in
                        if err != nil{
                            print(err!)
                        }
                    })
                }))
                self.present(alert, animated: true, completion: nil)
            }
            // [END_EXCLUDE]
        }
        // [END create_user]
        else {
            let alert = UIAlertController(title: "Alert", message: "Username or password can't be empty", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Okay", style: UIAlertAction.Style.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
        self.doneLoading()
    }
    
    
    @IBAction func FBLoginPressed(_ sender: Any) {
        
    }
    
    func loginButtonDidLogOut(_ loginButton: FBSDKLoginButton!) {
        print("Did log out of facebook")
    }
    
    func loginButton(_ loginButton: FBSDKLoginButton!, didCompleteWith result: FBSDKLoginManagerLoginResult!, error: Error!){
        loadingText.text = "Logging in"
        isLoading()
        if error != nil {
            print(error)
            self.doneLoading()
            return
        }
        if result.isCancelled {
            self.doneLoading()
            return
        }
        print("Successfully logged in with facebook...")
        let credential = FacebookAuthProvider.credential(withAccessToken: FBSDKAccessToken.current().tokenString)
        Auth.auth().signInAndRetrieveData(with: credential) { (userdata, error) in
            if error != nil {
                print(error.debugDescription)
                return
            }
            let graphRequest:FBSDKGraphRequest = FBSDKGraphRequest(graphPath: "me", parameters: ["fields":"name,email, picture.type(large), birthday"])
            
            graphRequest.start(completionHandler: { (connection, result, error) -> Void in
                if ((error) != nil)
                {
                    print("Error: \(String(describing: error))")
                }
                else
                {
                    let user = userdata?.user
                    if let data = result as? [String : AnyObject]{
                        if let name = data["name"] as? String{
                            self.ref.child("Users").child(user!.uid).child("full_name").setValue(name)
                        }
                        if let id = data["id"] as? String{
                            self.ref.child("Users").child(user!.uid).child("facebook_id").setValue(id)
                        }
                        if let email = data["email"] as? String{
                            user?.updateEmail(to: email, completion: { (error) in
                                if ((error) != nil){
                                    print("Error: \(String(describing: error))")
                                }
                            })
                        }
                        if let birthday = data["birthday"] {
                            self.ref.child("Users").child(user!.uid).child("birthday").setValue(birthday)
                        }
                    }
                }
            })
            self.doneLoading()
            self.gotoMain()
        }
    }
    @IBAction func toLogin(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    func gotoMain(){
        //Set root as our tab view controller
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let tabVC = storyboard.instantiateViewController(withIdentifier: "tabMain") as! UITabBarController
        tabVC.selectedIndex = 0
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.window!.rootViewController = tabVC
    }
    
    
    @objc func keyboardWillShow(notification: NSNotification){
        if !keyboardShowing{
            keyboardShowing = true
            img.isHidden = true
            if ((notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue) != nil {
                //if self.view.frame.origin.y == 0{
                    let keyboardRectValue = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
                    keyboardHeight = keyboardRectValue?.height
                    self.view.frame.origin.y -= keyboardHeight!
               // }
            }
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification){
           if keyboardShowing{
            keyboardShowing = false
            img.isHidden = false
            if ((notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue) != nil {
                if self.view.frame.origin.y != 0{
                    self.view.frame.origin.y += keyboardHeight!
                }
            }
        }
    }
   
    
}
