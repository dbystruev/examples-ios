//
//  DiathekeSDKExampleTests.swift
//  DiathekeSDKExampleTests
//
//  Created by Eduard Miniakhmetov on 20.04.2020.
//  Copyright © 2020 Cobalt Speech and Language Inc. All rights reserved.
//

import XCTest
import Diatheke
@testable import DiathekeSDKExample

class DiathekeSDKExampleTests: XCTestCase {
    
    var client: Client!

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        client = Client(host: "demo.cobaltspeech.com", port: 2727, useTLS: false)
        let expectation = XCTestExpectation(description: "List models")
        
        client.listModels { (models) in
            XCTAssert(models.count > 0, "models list is empty")
            expectation.fulfill()
        } failure: { (error) in
            XCTFail(error.localizedDescription)
        }

        wait(for: [expectation], timeout: 100.0)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
