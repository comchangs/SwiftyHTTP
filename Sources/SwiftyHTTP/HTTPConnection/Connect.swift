//
//  Connect.swift
//  SwiftyHTTP
//
//  Created by Helge Hess on 6/26/14.
//  Copyright (c) 2014 Always Right Institute. All rights reserved.
//

/**
 * NodeJS style Connect, well, bitz of it ;-)
 *
 * http://stephensugden.com/middleware_guide/
 *
 * Note: no error handling
 */
public class Connect : HTTPServer {
  
  var middlewarez = [MiddlewareEntry]()
  
  override public init() {
    super.init()
    self.onRequest { [unowned self] in
      self.doRequest($0, response: $1, connection: $2)
    }
  }
  
  public func use(cb: Middleware) -> Self {
    middlewarez.append(MiddlewareEntry(middleware: cb))
    return self
  }
  public func use(prefix: String, _ cb: Middleware) -> Self {
    middlewarez.append(MiddlewareEntry(urlPrefix: prefix, middleware: cb))
    return self
  }
  
  func doRequest(request: HTTPRequest, response: HTTPResponse,
                 connection: HTTPConnection) -> Void
  {
    // first lookup all middleware matching the request (i.e. the URL prefix
    // matches)
    let matchingMiddleware = middlewarez.filter { $0.matchesRequest(request) }
    
    let endNext : Next = { _ in } // a noop middleware next-block handle
    var next    : Next = { _ in } // cannot be let as it's self-referencing
    
    var i = 0 // capture position in matching-middleware array (shared)
    next = {
      args in
      
      // grab next item from matching middleware array
      let middleware = matchingMiddleware[i].middleware
      i = i + 1 // this is shared between the blocks, move position in array
      
      // call the middleware - which gets the handle to go to the 'next'
      // middleware. the latter can be the 'endNext' which won't do anything.
      middleware(request, response, connection,
                 (i == matchingMiddleware.count) ? endNext : next)
    }
    
    next()
  }

}

struct MiddlewareEntry {
  
  let urlPrefix  : String?
  let middleware : Middleware
  
  init(middleware: Middleware) {
    self.middleware = middleware
    self.urlPrefix  = nil
  }
  
  init(urlPrefix: String, middleware: Middleware) {
    self.urlPrefix  = urlPrefix
    self.middleware = middleware
  }
  
  func matchesRequest(request: HTTPRequest) -> Bool {
    if let prefix = urlPrefix {
      guard request.path.hasPrefix(prefix) else { return false }
    }
    
    return true
  }
  
}

public typealias Next       = (String...) -> Void
public typealias Middleware =
                   (HTTPRequest, HTTPResponse, HTTPConnection, Next) -> Void
