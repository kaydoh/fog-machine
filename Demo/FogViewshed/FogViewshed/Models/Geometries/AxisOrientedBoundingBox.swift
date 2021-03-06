import Foundation
import MapKit

/**
 
 A bounding box aligned with (lat,lon) coordinate system.
 
 FIXME: I would hate to see what some of these methods do when the box spans the 180th meridian....
 
*/
public class AxisOrientedBoundingBox : NSObject, NSCoding {
    
    private var lowerLeft: CLLocationCoordinate2D
    private var upperRight: CLLocationCoordinate2D
    
    override public var description: String{
        return "(\(getLowerLeft().latitude), \(getLowerLeft().longitude)), (\(getUpperRight().latitude), \(getUpperRight().longitude))"
    }
    
    init(lowerLeft: CLLocationCoordinate2D, upperRight: CLLocationCoordinate2D) {
        self.lowerLeft = lowerLeft
        self.upperRight = upperRight
    }
    
    func getLowerLeft() -> CLLocationCoordinate2D {
        return lowerLeft
    }
    
    func getUpperRight() -> CLLocationCoordinate2D {
        return upperRight
    }

    func getLowerRight() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2DMake(lowerLeft.latitude, upperRight.longitude)
    }

    func getUpperLeft() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2DMake(upperRight.latitude, lowerLeft.longitude)
    }
    
    func getCentroid() -> CLLocationCoordinate2D {
        let centroidLat:Double = (getLowerLeft().latitude + getUpperRight().latitude)/2
        let centroidLon:Double = (getLowerLeft().longitude + getUpperRight().longitude)/2
        return CLLocationCoordinate2DMake(centroidLat, centroidLon)
    }
    
    func intersectionExists(with:AxisOrientedBoundingBox) -> Bool {
        let aURLat = getUpperRight().latitude
        let aURLon = getUpperRight().longitude
        
        let bLLLat = with.getLowerLeft().latitude
        let bLLLon = with.getLowerLeft().longitude
        
        let aLLLat = getLowerLeft().latitude
        let aLLLon = getLowerLeft().longitude
        
        let bURLat = with.getUpperRight().latitude
        let bURLon = with.getUpperRight().longitude
        
        if(bLLLat < aURLat && bLLLon < aURLon && aLLLat < bURLat && aLLLon < bURLon) {
            return true
        }
        return false
    }
    
    // you should check if there is an intersection with isIntersection before calling this function!
    func intersection(with:AxisOrientedBoundingBox) -> AxisOrientedBoundingBox {
        let llLat:Double = max(getLowerLeft().latitude, with.getLowerLeft().latitude);
        let llLon:Double = max(getLowerLeft().longitude, with.getLowerLeft().longitude);
        
        let urLat:Double = min(getUpperRight().latitude, with.getUpperRight().latitude);
        let urLon:Double = min(getUpperRight().longitude, with.getUpperRight().longitude);
        
        return AxisOrientedBoundingBox(lowerLeft: CLLocationCoordinate2DMake(llLat, llLon), upperRight: CLLocationCoordinate2DMake(urLat, urLon))
    }
    
    func asMKPolygon() -> MKPolygon {
        var points = [
            getLowerLeft(),
            getUpperLeft(),
            getUpperRight(),
            getLowerRight()
        ]
        let polygonOverlay:MKPolygon = MKPolygon(coordinates: &points, count: points.count)
        
        return polygonOverlay
    }
    
    func asMKMapRect() -> MKMapRect {
        // convert them to MKMapPoint
        let p1:MKMapPoint = MKMapPointForCoordinate (getLowerLeft())
        let p2:MKMapPoint = MKMapPointForCoordinate (getUpperRight())
        
        // and make a MKMapRect using mins and spans
        return MKMapRectMake(fmin(p1.x,p2.x), fmin(p1.y,p2.y), fabs(p1.x-p2.x), fabs(p1.y-p2.y))
    }
    
    
    required public init(coder decoder: NSCoder) {
        let lowerLeftLat:Double = decoder.decodeObjectForKey("lowerLeftLat") as! Double
        let lowerLeftLon:Double = decoder.decodeObjectForKey("lowerLeftLon") as! Double
        let upperRightLat:Double = decoder.decodeObjectForKey("upperRightLat") as! Double
        let upperRightLon:Double = decoder.decodeObjectForKey("upperRightLon") as! Double
        
        self.lowerLeft = CLLocationCoordinate2DMake(lowerLeftLat, lowerLeftLon)
        self.upperRight = CLLocationCoordinate2DMake(upperRightLat, upperRightLon)
    }
    
    public func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(self.lowerLeft.latitude, forKey: "lowerLeftLat")
        coder.encodeObject(self.lowerLeft.longitude, forKey: "lowerLeftLon")
        coder.encodeObject(self.upperRight.latitude, forKey: "upperRightLat")
        coder.encodeObject(self.upperRight.longitude, forKey: "upperRightLon")
    }
}