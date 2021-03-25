import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    // Example of configuring a controller
    let API_Controller = APIController()
    try router.register(collection: API_Controller)
}
