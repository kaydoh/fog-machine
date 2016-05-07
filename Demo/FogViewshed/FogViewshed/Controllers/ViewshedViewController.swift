import UIKit
import MapKit
import FogMachine
import SwiftEventBus

class ViewshedViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, UITabBarControllerDelegate {

    // MARK: Class Variables

    var model = ObserverFacade()
    var settingsObserver = Observer() //Only use for segue from ObserverSettings
    var isLogShown: Bool!
    var locationManager: CLLocationManager!
    var isInitialAuthorizationCheck = false

    // MARK: IBOutlets

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var mapTypeSelector: UISegmentedControl!
    @IBOutlet weak var logBox: UITextView!
    @IBOutlet weak var mapViewProportionalHeight: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tabBarController!.delegate = self
        mapView.delegate = self
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(ViewshedViewController.addAnnotationGesture(_:)))
        gesture.minimumPressDuration = 1.0
        mapView.addGestureRecognizer(gesture)

        // TODO: What should happen when the viewshed is done?
        SwiftEventBus.onMainThread(self, name: "viewShedComplete") { result in
            ActivityIndicator.hide(success: true, animated: true)
        }
        
        // log any info from Fog Machine to our textbox
        SwiftEventBus.onMainThread(self, name: "onLog") { result in
            let format:String = result.object as! String
            self.ViewshedLog(format)
        }
        
        // for debugging only
        SwiftEventBus.onMainThread(self, name: "drawDebugging") { result in
            let polygon:MKPolygon = result.object as! MKPolygon
            self.mapView.addOverlay(polygon)
        }
        
        isLogShown = false

        drawObservers()
        drawDataRegions()

        locationManagerSettings()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    // MARK: - TabBarController Delegates

    func tabBarController(tabBarController: UITabBarController, didSelectViewController viewController: UIViewController) {
        //If the selected viewController is the main mapViewController
        if viewController == tabBarController.viewControllers?[1] {
            drawDataRegions()
        }
    }

    // MARK: Location Delegate Methods

    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if (status == .AuthorizedWhenInUse || status == .AuthorizedAlways) {
            self.locationManager.startUpdatingLocation()
            self.isInitialAuthorizationCheck = true
            self.mapView.showsUserLocation = true
        }
    }

    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

        if (self.isInitialAuthorizationCheck) {
            let location = locations.last
            let center = CLLocationCoordinate2D(latitude: location!.coordinate.latitude, longitude: location!.coordinate.longitude)
            let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5))
            self.mapView.tintColor = UIColor.blueColor()
            self.mapView?.centerCoordinate = location!.coordinate
            self.mapView.setRegion(region, animated: true)
            self.locationManager.stopUpdatingLocation()
        }
    }


    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        print("Error: " + error.localizedDescription)
    }
    
    
    func centerMapOnLocation(location: CLLocationCoordinate2D) {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location, 10000, 10000)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    func locationManagerSettings() {
        if (self.locationManager == nil) {
            self.locationManager = CLLocationManager()
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
            self.locationManager.delegate = self
        }
        let status = CLLocationManager.authorizationStatus()
        if (status == .NotDetermined || status == .Denied || status == .Restricted)  {
            // present an alert indicating location authorization required
            // and offer to take the user to Settings for the app via
            self.locationManager.requestWhenInUseAuthorization()
            self.mapView.tintColor = UIColor.blueColor()
        }
        if let coordinate = mapView.userLocation.location?.coordinate {
            let center = CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1))
            self.mapView.setRegion(region, animated: true)
        }
    }


    // MARK: Display Stuff

    func drawObservers() {
        mapView.removeAnnotations(mapView.annotations)
        
        for observer in model.getObservers() {
            drawPin(observer)
        }
    }

    func drawDataRegions() {
        var dataRegionOverlays = [MKOverlay]()
        for overlay in mapView.overlays {
            if overlay is MKPolygon {
                dataRegionOverlays.append(overlay)
            }
        }
        mapView.removeOverlays(dataRegionOverlays)
        
        for hgtFile in HGTManager.getLocalHGTFiles() {
            self.mapView.addOverlay(hgtFile.getBoundingBox().asMKPolygon())
            let llPin = MKPointAnnotation()
            llPin.coordinate = hgtFile.getBoundingBox().getLowerLeft()
            mapView.addAnnotation(llPin)
            let urPin = MKPointAnnotation()
            urPin.coordinate = hgtFile.getBoundingBox().getUpperRight()
            mapView.addAnnotation(urPin)
        }
    }

    func drawPin(observer: Observer) {
        let dropPin = MKPointAnnotation()
        dropPin.coordinate = observer.position
        dropPin.title = observer.name
        mapView.addAnnotation(dropPin)
    }

    func addAnnotationGesture(gestureRecognizer: UIGestureRecognizer) {
        if (gestureRecognizer.state == UIGestureRecognizerState.Began) {
            let newObserver = Observer()
            newObserver.name = "Observer \(model.getObservers().count + 1)"
            newObserver.position = mapView.convertPoint(gestureRecognizer.locationInView(mapView), toCoordinateFromView: mapView)
            model.add(newObserver)
            drawPin(newObserver)
        }
    }

    func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
        var polygonView:MKPolygonRenderer? = nil
        if overlay is MKPolygon {
            polygonView = MKPolygonRenderer(overlay: overlay)
            polygonView!.lineWidth = 0.5
            // FIXME : if fill color is set, the viewsheds combine with the yellow tint and look like crap.  We should look at the compositing of the views/images to fix this.
            polygonView!.fillColor = UIColor.yellowColor().colorWithAlphaComponent(0.08)
            polygonView!.strokeColor = UIColor.redColor().colorWithAlphaComponent(0.6)
        } else if overlay is Cell {
            polygonView = MKPolygonRenderer(overlay: overlay)
            polygonView!.lineWidth = 0.1
            let color:UIColor = (overlay as! Cell).color!
            polygonView!.strokeColor = color
            polygonView!.fillColor = color.colorWithAlphaComponent(0.3)
        } else if overlay is ViewshedOverlay {
            let imageToUse = (overlay as! ViewshedOverlay).image
            let overlayView = ViewshedOverlayView(overlay: overlay, overlayImage: imageToUse)

            return overlayView
        }

        return polygonView!
    }

    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {

        var view:MKPinAnnotationView? = nil
        let identifier = "pin"
        if (annotation is MKUserLocation) {
            //if annotation is not an MKPointAnnotation (eg. MKUserLocation),
            //return nil so map draws default view for it (eg. blue bubble)...
            return nil
        }
        if let dequeuedView = mapView.dequeueReusableAnnotationViewWithIdentifier(identifier) as? MKPinAnnotationView {
            dequeuedView.annotation = annotation
            view = dequeuedView
        } else {
            view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view!.canShowCallout = true
            view!.calloutOffset = CGPoint(x: -5, y: 5)

            let image = UIImage(named: "Viewshed")
            let button = UIButton(type: UIButtonType.DetailDisclosure)
            button.setImage(image, forState: UIControlState.Normal)

            view!.leftCalloutAccessoryView = button as UIView
            view!.rightCalloutAccessoryView = UIButton(type: UIButtonType.DetailDisclosure) as UIView
        }

        return view
    }

    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if let selectedObserver = retrieveObserver((view.annotation?.coordinate)!) {
            if control == view.rightCalloutAccessoryView {
                performSegueWithIdentifier("observerSettings", sender: selectedObserver)
            } else if control == view.leftCalloutAccessoryView {
                self.initiateFogViewshed(selectedObserver)
            }
        } else {
            print("Observer not found for \((view.annotation?.coordinate)!)")
        }
    }

    func changeMultiplier(constraint: NSLayoutConstraint, multiplier: CGFloat) -> NSLayoutConstraint {
        let newConstraint = NSLayoutConstraint(
            item: constraint.firstItem,
            attribute: constraint.firstAttribute,
            relatedBy: constraint.relation,
            toItem: constraint.secondItem,
            attribute: constraint.secondAttribute,
            multiplier: multiplier,
            constant: constraint.constant)

        newConstraint.priority = constraint.priority

        NSLayoutConstraint.deactivateConstraints([constraint])
        NSLayoutConstraint.activateConstraints([newConstraint])

        return newConstraint
    }

    func setMapLogDisplay() {
        guard let isLogShown = self.isLogShown else {
            mapViewProportionalHeight = changeMultiplier(mapViewProportionalHeight, multiplier: 1.0)
            return
        }

        if(isLogShown) {
            mapViewProportionalHeight = changeMultiplier(mapViewProportionalHeight, multiplier: 0.8)
        } else {
            mapViewProportionalHeight = changeMultiplier(mapViewProportionalHeight, multiplier: 1.0)
        }
    }

    func retrieveObserver(coordinate: CLLocationCoordinate2D) -> Observer? {
        var foundObserver: Observer? = nil

        for observer in model.getObservers() {
            if coordinate.latitude == observer.position.latitude && coordinate.longitude == observer.position.longitude {
                foundObserver = observer
                break
            }
        }
        return foundObserver
    }

    func redraw() {
        
        mapView.removeOverlays(mapView.overlays)
        
        drawObservers()
        drawDataRegions()
    }


    // MARK: Viewshed

    func initiateFogViewshed(observer: Observer) {
        ActivityIndicator.show("Calculating Viewshed")
        self.ViewshedLog("Running viewshed")
        (FogMachine.fogMachineInstance.getTool() as! ViewshedTool).createWorkViewshedObserver = observer
        (FogMachine.fogMachineInstance.getTool() as! ViewshedTool).createWorkViewshedAlgorithmName = ViewshedAlgorithmName.FranklinRay
        FogMachine.fogMachineInstance.execute()
    }

    // MARK: IBActions

    @IBAction func mapTypeChanged(sender: AnyObject) {
        let mapType = MapType(rawValue: mapTypeSelector.selectedSegmentIndex)
        switch (mapType!) {
        case .Standard:
            mapView.mapType = MKMapType.Standard
        case .Hybrid:
            mapView.mapType = MKMapType.Hybrid
        case .Satellite:
            mapView.mapType = MKMapType.Satellite
        }
    }

    @IBAction func focusToCurrentLocation(sender: AnyObject) {
        locationManagerSettings()
    }


    // MARK: Segue

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "observerSettings" {
            let navController = segue.destinationViewController as! UINavigationController
            let viewController: ObserverSettingsViewController = navController.topViewController as! ObserverSettingsViewController
            viewController.originalObserver = sender as! ObserverEntity?
        } else if segue.identifier == "settings" {
            let navController = segue.destinationViewController as! UINavigationController
            let viewController: SettingsViewController = navController.topViewController as! SettingsViewController
            viewController.isLogShown = self.isLogShown
        }
    }

    @IBAction func unwindFromModal(segue: UIStoryboardSegue) {
        setMapLogDisplay()
        drawDataRegions()
    }

    @IBAction func applyOptions(segue: UIStoryboardSegue) {

    }

    @IBAction func removeViewshedFromSettings(segue: UIStoryboardSegue) {
        setMapLogDisplay()
        redraw()
    }

    @IBAction func removePinFromSettings(segue: UIStoryboardSegue) {
        redraw()
    }

    @IBAction func deleteAllPins(segue: UIStoryboardSegue) {
        setMapLogDisplay()
        model.clearEntity()
        redraw()
    }


    @IBAction func runSelectedFogViewshed(segue: UIStoryboardSegue) {
        redraw()
        self.initiateFogViewshed(self.settingsObserver)
    }


    @IBAction func applyObserverSettings(segue:UIStoryboardSegue) {
        if segue.sourceViewController.isKindOfClass(ObserverSettingsViewController) {
            mapView.removeAnnotations(mapView.annotations)
            drawObservers()
        }
    }

    // MARK: Logging

    func ViewshedLog(format: String, writeToDebugLog:Bool = false, clearLog: Bool = false) {
        if(writeToDebugLog) {
            NSLog(format)
        }
        dispatch_async(dispatch_get_main_queue()) {
            if(clearLog) {
                self.logBox.text = ""
            }
            let dateFormater = NSDateFormatter()
            dateFormater.dateFormat = NSDateFormatter.dateFormatFromTemplate("HH:mm:ss.SSS", options: 0, locale:  NSLocale.currentLocale())
            let currentTimestamp:String = dateFormater.stringFromDate(NSDate());
            dispatch_async(dispatch_get_main_queue()) {
                self.logBox.text.appendContentsOf(currentTimestamp + " " + format + "\n")
                self.logBox.scrollRangeToVisible(NSMakeRange(self.logBox.text.characters.count - 1, 1));
            }
        }
    }

}