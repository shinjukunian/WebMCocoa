//
//  VPXTests.swift
//  VPXTests
//
//  Created by Morten Bertz on 2020/12/22.
//  Copyright © 2020 telethon k.k. All rights reserved.
//

import XCTest
@testable import VPX

class VPXTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testVersion() throws {
        let version=VPXEncoder2.version()
        XCTAssert(version.count > 0)
    }
    
    func testEncode() throws{
        
        
        
        
    }

    

}
