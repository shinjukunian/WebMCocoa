//
//  VPXTests.swift
//  VPXTests
//
//  Created by Morten Bertz on 2020/12/22.
//  Copyright © 2020 telethon k.k. All rights reserved.
//

import XCTest
import CoreGraphics
@testable import VPX

class VPXTests: XCTestCase {
    
    let timeInterval:TimeInterval=0.03
    
    #if SWIFT_PACKAGE
    lazy var imageURLS:[URL]={
        let currentURL=URL(fileURLWithPath: #file).deletingLastPathComponent()
        let imageURL=currentURL.appendingPathComponent("testData", isDirectory: true)
        let imageURLs=try! FileManager.default.contentsOfDirectory(at: imageURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            .sorted(by: {u1,u2 in
                return u1.lastPathComponent.compare(u2.lastPathComponent, options:[.numeric]) == .orderedAscending
                
            })
        
        XCTAssertGreaterThan(imageURLs.count, 1, "insufficient images loaded")

        return imageURLs
    }()
    #else
    lazy var imageURLS:[URL]={
        guard let urls=Bundle(for: type(of: self)).urls(forResourcesWithExtension: "png", subdirectory:nil)?.sorted(by: {u1,u2 in
            return u1.lastPathComponent.compare(u2.lastPathComponent, options:[.numeric]) == .orderedAscending
        }) else{
            XCTFail("No Images Loaded")
            return [URL]()
        }
        XCTAssertGreaterThan(urls.count, 1, "insufficient images loaded")
        return urls
    }()
    #endif

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
    }

    func testVersion() throws {
        let version=VPXEncoder2.version()
        XCTAssert(version.count > 0)
    }
    
    lazy var testItems:[(CGImage, Double)] = {
        let images=self.imageURLS.compactMap({url->CGImage? in
            guard let source=CGImageSourceCreateWithURL(url as CFURL, nil) else{return nil}
            XCTAssert(CGImageSourceGetCount(source) == 1, "Image Source has image count too high")
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        })
        XCTAssertEqual(images.count, self.imageURLS.count)
        let presentationTimes=images.indices.map({return Double($0) * timeInterval})
        return Array(zip(images, presentationTimes))
    }()
    
    
    func testEncodeOpaque() throws{
        let outURL=URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("TestOpaque").appendingPathExtension("webm")
        
        let first=testItems.first?.0
        XCTAssertNotNil(first)
        
        let encoder=VPXEncoder2(url: outURL, framerate: UInt(1/timeInterval), size: CGSize(width: first?.width ?? 0, height: first?.height ?? 0), preserveAlpha: false)
        
        
        
        for item in testItems{
            encoder.addFrame(item.0, atTime: item.1)
        }
        
        encoder.finalize(completion: {success in
            XCTAssert(success)
        })
        
        addTeardownBlock {
            do{
                try FileManager.default.removeItem(at: outURL)
            }
            catch let error{
                XCTFail(error.localizedDescription)
            }
            
        }
        
    }
    
    func testEncodeOpaqueGreen() throws{
        let outURL=URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("TestOpaqueGreen").appendingPathExtension("webm")
        
        let first=testItems.first?.0
        XCTAssertNotNil(first)
        
        let encoder=VPXEncoder2(url: outURL, framerate: UInt(1/timeInterval), size: CGSize(width: first?.width ?? 0, height: first?.height ?? 0), preserveAlpha: false)
        encoder.backgroundColor =  CGColor(red: 0, green: 1, blue: 0, alpha: 1)
        
        for item in testItems{
            encoder.addFrame(item.0, atTime: item.1)
        }
        
        encoder.finalize(completion: {success in
            XCTAssert(success)
        })
        
        addTeardownBlock {
            do{
                try FileManager.default.removeItem(at: outURL)
            }
            catch let error{
                XCTFail(error.localizedDescription)
            }
            
        }
        
    }
    
    func testEncodeAlpha() throws{
        let outURL=URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("TestAlpha").appendingPathExtension("webm")
        
        let first=testItems.first?.0
        XCTAssertNotNil(first)
        
        let encoder=VPXEncoder2(url: outURL, framerate: UInt(1/timeInterval), size: CGSize(width: first?.width ?? 0, height: first?.height ?? 0), preserveAlpha: true)
        
        
        for item in testItems{
            encoder.addFrame(item.0, atTime: item.1)
        }
        
        encoder.finalize(completion: {success in
            XCTAssert(success)
        })
        
        addTeardownBlock {
            do{
                try FileManager.default.removeItem(at: outURL)
            }
            catch let error{
                XCTFail(error.localizedDescription)
            }
            
        }
        
    }

    
    
//    func testEncodeOpaqueVP9() throws{
//        let outURL=URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("TestOpaqueVP9").appendingPathExtension("webm")
//        
//        let first=testItems.first?.0
//        XCTAssertNotNil(first)
//        
//        let encoder = VPXEncoder2(url: outURL, framerate: UInt(1/timeInterval), size: CGSize(width: first?.width ?? 0, height: first?.height ?? 0), preserveAlpha: false, encoder: .VP9)
//        
//        
//        for item in testItems{
//            encoder.addFrame(item.0, atTime: item.1)
//        }
//        
//        encoder.finalize(completion: {success in
//            XCTAssert(success)
//        })
//        
//        addTeardownBlock {
//            do{
//                try FileManager.default.removeItem(at: outURL)
//            }
//            catch let error{
//                XCTFail(error.localizedDescription)
//            }
//            
//        }
//        
//    }
    
//    func testEncodeAlphaVP9() throws{
//        let outURL=URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("TestOpaque").appendingPathExtension("webm")
//
//        let first=testItems.first?.0
//        XCTAssertNotNil(first)
//
//        let encoder = VPXEncoder2(url: outURL, framerate: UInt(1/timeInterval), size: CGSize(width: first?.width ?? 0, height: first?.height ?? 0), preserveAlpha: true, encoder: .VP9)
//
//
//        for item in testItems{
//            encoder.addFrame(item.0, atTime: item.1)
//        }
//
//        encoder.finalize(completion: {success in
//            XCTAssert(success)
//        })
//
//        addTeardownBlock {
//            do{
//                try FileManager.default.removeItem(at: outURL)
//            }
//            catch let error{
//                XCTFail(error.localizedDescription)
//            }
//
//        }
//
//    }
    

}
