//
//  CubicExampleTests.swift
//  CubicExampleTests
//
//  Created by Eduard Miniakhmetov on 22.04.2020.
//  Copyright © 2020 Cobalt Speech and Language Inc. All rights reserved.
//

import XCTest
import Cubic

class CubicExampleTests: XCTestCase {

    var client: Client!
    var config = Cobaltspeech_Cubic_RecognitionConfig()
    let fileName = "test.wav"
    
    func testExample() throws {
        client = Client(host: "demo.cobaltspeech.com", port: 2727, useTLS: true)
        let expectation = XCTestExpectation(description: "List models")
        client.listModels(success: { (models) in
            XCTAssertNotNil(models)
            
            guard let models = models else {
                XCTFail("'models' is nil")
                return
            }
            
            XCTAssert(models.count > 0, "models list is empty")
            
            self.config.audioEncoding = .rawLinear16
            self.config.modelID = models[0].id
            
            let urlpath = Bundle(for: self.classForCoder).path(forResource: "test", ofType: "wav")
            
            XCTAssertNotNil(urlpath)
            
            self.client.recognize(audioURL: URL(fileURLWithPath: urlpath!), config: self.config, success: { (response) in
                XCTAssert(response.results.count > 0, "results list is empty")
                expectation.fulfill()
            }) { (error) in
                XCTFail(error.localizedDescription)
            }
            
        }) { (error) in
            XCTFail(error.localizedDescription)
        }
        
        wait(for: [expectation], timeout: 10.0)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
