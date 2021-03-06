//
//  Deal.swift
//  Savour
//
//  Created by Chris Patterson on 9/18/18.
//  Copyright © 2018 Chris Patterson. All rights reserved.
//

import Foundation
import UIKit
import FirebaseDatabase
import FirebaseAuth
import MapKit
import GeoFire

fileprivate let locationManager = CLLocationManager()

class DealsData{
    private let ref = Database.database().reference()
    private let userid = Auth.auth().currentUser?.uid
    private var geoFire: GFCircleQuery!
    
    
    private var activeDeals = Dictionary<String,DealData>()
    private var inactiveDeals = Dictionary<String,DealData>()
    
    
    private var vendors = Dictionary<String,VendorData>()
    private var favoriteIDs = Dictionary<String, String>()
    
    private var favoritesLoaded = false
    private var dealsLoaded = false
    var loadingComplete = false
    
    init(completion: @escaping (Bool) -> Void){
        let favGroup = DispatchGroup()
        var favLoaded = false
        self.ref.keepSynced(true)
        favGroup.enter()
        self.ref.child("Users").child(self.userid!).child("favorites").observe(.value, with: { (snapshot) in
            if let dictionary = snapshot.children.allObjects as? [DataSnapshot] {
                self.favoriteIDs.removeAll()
                for fav in dictionary{
                    if let _ = fav.value{
                        //Get Favorites
                        self.favoriteIDs[fav.key] = fav.key
                        if let _ = self.activeDeals[fav.key]{
                            self.activeDeals[fav.key]?.favorited = true
                        }else if let _ = self.inactiveDeals[fav.key] {
                            self.inactiveDeals[fav.key]?.favorited = true
                        }
                    }
                }
            }
            if !favLoaded{
                favGroup.leave()
            }
        })
        favGroup.notify(queue: .main){
            //Get Deals
            favLoaded = true
            var first = true
            let vendorGroup = DispatchGroup()
            var vendorLoaded = false
            let geofireRef = Database.database().reference().child("Vendors_Location")
            while (locationManager.location == nil){//wait until location is available
//                print("waiting for location")
            }//even if the location is old, dont worry, we will update later when tabbar location update is called
            self.geoFire = GeoFire(firebaseRef: geofireRef).query(at: locationManager.location!, withRadius: 80.5)
            vendorGroup.enter()
            self.geoFire.observe(.keyEntered, with: { (key: String!, thislocation: CLLocation!) in //50 miles
                if !vendorLoaded{
                    vendorGroup.enter()
                }
                Database.database().reference().child("Vendors").queryOrderedByKey().queryEqual(toValue: key).observe(.value, with: { (snapshot) in
                    for child in snapshot.children{
                        let snap = child as! DataSnapshot
                        self.vendors[key] = VendorData(snap: snap, ID: key, location: thislocation, myLocation: locationManager.location)
                    }
                    if !vendorLoaded{
                        vendorGroup.leave()
                    }else{
                        self.queryDeals(forEnteredVendor: self.vendors[key]!)
                    }
                })
            })
            self.geoFire.observe(.keyExited, with: { (key: String!, thislocation: CLLocation!) in //50 miles
                //remove vendor and all deals for vendor
                self.vendors.removeValue(forKey: key)
                for deal in self.activeDeals{
                    if deal.value.rID == key{
                        self.activeDeals.removeValue(forKey: deal.key)
                    }
                }
                for deal in self.inactiveDeals{
                    if deal.value.rID == key{
                        self.inactiveDeals.removeValue(forKey: deal.key)
                    }
                }
            })
            self.geoFire.observeReady({
                if !vendorLoaded && first{ //check that we havent called leave from here yet
                    //observeReady may happemn multiple times. Only care bout first one
                    first = false
                    print("All initial vendor data has been loaded and events have been fired!")
                    vendorGroup.leave()
                }
            })
            vendorGroup.notify(queue: .main){
                vendorLoaded = true
                let dealGroup = DispatchGroup()
                var dealsLoaded = false
                if self.vendors.count < 1 {
                    dealGroup.enter()
                    self.activeDeals["SVR"] = DealData(snap: nil, ID: "SVR", vendors: self.vendors)
                    dealGroup.leave()//When we found no vendors, just leave
                }else{
                    self.activeDeals.removeValue(forKey: "SVR")
                    for vendor in self.vendors {
                        if !dealsLoaded{
                            dealGroup.enter()
                        }
                        self.ref.child("Deals").queryOrdered(byChild: "vendor_id").queryEqual(toValue: vendor.key).observe(.value, with: { (snapshot) in
                            for entry in snapshot.children {
                                let snap = entry as! DataSnapshot
                                if let _ = snap.value{
                                    let temp = DealData(snap: snap, ID: self.userid!, vendors: self.vendors)
                                    if self.favoriteIDs[temp.id!] != nil{
                                        temp.favorited = true
                                    }else{
                                        temp.favorited = false
                                    }
                                    //if the deal is not expired or redeemed less than half an hour ago, show it
                                    if temp.isAvailable(){
                                        if temp.active{
                                            self.activeDeals[temp.id!] = temp
                                            self.inactiveDeals.removeValue(forKey: temp.id!)
                                        }else{
                                            self.inactiveDeals[temp.id!] = temp
                                            self.activeDeals.removeValue(forKey: temp.id!)
                                        }
                                    }else if let time = temp.redeemedTime{
                                        if (Int(Date().timeIntervalSince1970) - time) < 1800{
                                            self.activeDeals[temp.id!] = temp
                                            self.inactiveDeals.removeValue(forKey: temp.id!)
                                        }
                                    }
                                }else{
                                    let snap = entry as! DataSnapshot
                                    let key = snap.key
                                    self.activeDeals.removeValue(forKey: key)
                                    self.inactiveDeals.removeValue(forKey: key)
                                }
                            }
                            if !dealsLoaded{
                                dealGroup.leave()
                            }
                        })
                    }
                }
                dealGroup.notify(queue: .main){
                    dealsLoaded = true
                    print("Finished gathering deals.")
                    completion(true)
                }
            }
        }
    }
    
    func updateLocation(location: CLLocation){
        if let _ = geoFire{
            self.geoFire.center = location
        }
    }
    
    func queryDeals(forEnteredVendor vendor: VendorData){
        self.ref.child("Deals").queryOrdered(byChild: "vendor_id").queryEqual(toValue: vendor.id).observe(.value, with: { (snapshot) in
            for entry in snapshot.children {
                let snap = entry as! DataSnapshot
                if let _ = snap.value{
                    let temp = DealData(snap: snap, ID: self.userid!, vendors: self.vendors)
                    if self.favoriteIDs[temp.id!] != nil{
                        temp.favorited = true
                    }else{
                        temp.favorited = false
                    }
                    //if the deal is not expired or redeemed less than half an hour ago, show it
                    if temp.isAvailable(){
                        if temp.active{
                            self.activeDeals[temp.id!] = temp
                            self.inactiveDeals.removeValue(forKey: temp.id!)
                        }else{
                            self.inactiveDeals[temp.id!] = temp
                            self.activeDeals.removeValue(forKey: temp.id!)
                        }
                    }else if let time = temp.redeemedTime{
                        if (Int(Date().timeIntervalSince1970) - time) < 1800{
                            self.activeDeals[temp.id!] = temp
                            self.inactiveDeals.removeValue(forKey: temp.id!)
                        }
                    }
                }else{
                    let snap = entry as! DataSnapshot
                    let key = snap.key
                    self.activeDeals.removeValue(forKey: key)
                    self.inactiveDeals.removeValue(forKey: key)
                }
            }
        })
    }
    
    func UpdateDealsStatus(){
        var newActive = Dictionary<String, DealData>()
        var newInactive = Dictionary<String, DealData>()
        for entry in activeDeals{
            entry.value.updateTimes()
            if entry.value.active{
                newActive[entry.key] = entry.value
            }else{
                newInactive[entry.key] = entry.value
            }
        }
        for entry in inactiveDeals{
            entry.value.updateTimes()
            if entry.value.active{
                newActive[entry.key] = entry.value
            }else{
                newInactive[entry.key] = entry.value
            }
        }
        activeDeals = newActive
        inactiveDeals = newInactive
    }
    
    func getDeals(byType dealType: String? = "All") -> ([DealData],[DealData]){
        UpdateDealsStatus()
        var (active,inactive) = filter(byTitle: dealType!)
        sortDeals(array: &active)
        sortDeals(array: &inactive)
        return (active,inactive)
    }
    
    func getDeals(byName dealName: String?) -> ([DealData],[DealData]){
        UpdateDealsStatus()
        var (active,inactive) = filter(byText: dealName!)
        sortDeals(array: &active)
        sortDeals(array: &inactive)
        return (active,inactive)
    }
    
    func getDeals(forRestaurant restaurant: String) -> ([DealData],[DealData]){
        UpdateDealsStatus()
        var active = Array(activeDeals.values).filter { $0.rID == restaurant }
        var inactive = Array(inactiveDeals.values).filter { $0.rID == restaurant }
        sortDeals(array: &active)
        sortDeals(array: &inactive)
        return (active,inactive)
    }
    
    func getFavorites() -> ([DealData],[DealData]){
        UpdateDealsStatus()
        let active = Array(activeDeals.values).filter { $0.favorited == true }
        let inactive = Array(inactiveDeals.values).filter { $0.favorited == true }
        return (active,inactive)
    }
    
    func filter(byTitle title: String) -> ([DealData],[DealData]){
        var inactive = [DealData]()
        var active = [DealData]()
        if title == "All" {
            active = Array(activeDeals.values)
            inactive = Array(inactiveDeals.values)
        }else if title == "%" || title == "$"{
            active = Array(activeDeals.values).filter { ($0.dealDescription!.lowercased().contains(title.lowercased())) }
            inactive = Array(inactiveDeals.values).filter  { ($0.dealDescription!.lowercased().contains(title.lowercased())) }
        }else if  title == "BOGO" {
            // Filter the results
            active = Array(activeDeals.values).filter { ($0.dealDescription!.lowercased().contains("Buy One Get One".lowercased())) }
            inactive = Array(inactiveDeals.values).filter { ($0.dealDescription!.lowercased().contains("Buy One Get One".lowercased())) }
        } else{
            active = Array(activeDeals.values).filter { ($0.dealDescription!.lowercased().contains(title.lowercased())) }
            inactive = Array(inactiveDeals.values).filter { ($0.dealDescription!.lowercased().contains(title.lowercased())) }
        }
        sortDeals(array: &active)
        sortDeals(array: &inactive)
        return (active,inactive)
    }
    
    func filter(byText text: String) -> ([DealData],[DealData]){
        var inactive = [DealData]()
        var active = [DealData]()
        if text == "" {
            active = Array(activeDeals.values)
            inactive = Array(inactiveDeals.values)
        } else {
            // Filter the results
            active = Array(activeDeals.values).filter { ($0.name?.lowercased().contains(text.lowercased()))! || ($0.dealDescription?.lowercased().contains(text.lowercased()))! }
            inactive = Array(inactiveDeals.values).filter { ($0.name?.lowercased().contains(text.lowercased()))! || ($0.dealDescription?.lowercased().contains(text.lowercased()))! }
        }
        return (active,inactive)
    }
    
    func sortDeals(array: inout [DealData]){
        array = array.sorted(by:{ (d1, d2) -> Bool in
            //TODO: make robust with selection on how to filter!!
            return CGFloat(d1.distanceMiles!) < CGFloat(d2.distanceMiles!)
        })
    }
    
    func getNotificationDeal(dealID: String?) -> DealData?{
        if dealID != nil && activeDeals.count > 0{
            return activeDeals[dealID!]
        }
        return nil
    }
}
