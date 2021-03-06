//
//  ResultInjectionTests.swift
//  Operations
//
//  Created by Daniel Thorpe on 16/12/2015.
//
//

import XCTest
@testable import Operations

class DataProcessing: Operation, AutomaticInjectionOperationType {

    var requirement: String? = .None

    override init() {
        super.init()
        name = "Data Processing"
    }

    override func execute() {
        let output = requirement ?? "No requirements provided!"
        log.info(output)
        finish()
    }
}

class ResultInjectionTests: OperationTests {

    var retrieval: TestOperation!
    var processing: DataProcessing!

    override func setUp() {
        super.setUp()
        retrieval = TestOperation()
        processing = DataProcessing()
    }
}

class ManualResultInjectionTests: ResultInjectionTests {

    func test__block_is_executed() {
        processing.injectResultFromDependency(retrieval) { op, dep, errors in
            XCTAssertEqual(dep.result, "Hello World")
        }

        addCompletionBlockToTestOperation(processing, withExpectation: expectationWithDescription("Test: \(__FUNCTION__)"))
        runOperations(retrieval, processing)
        waitForExpectationsWithTimeout(3, handler: nil)
    }

    func test__block_passes_through_errors() {
        retrieval = TestOperation(error: TestOperation.Error.SimulatedError)
        processing.injectResultFromDependency(retrieval) { op, dep, errors in
            XCTAssertEqual(errors.count, 1)
            guard let _ = errors.first as? TestOperation.Error else {
                XCTFail("Incorrect error received")
                return
            }
        }

        addCompletionBlockToTestOperation(processing, withExpectation: expectationWithDescription("Test: \(__FUNCTION__)"))
        runOperations(retrieval, processing)
        waitForExpectationsWithTimeout(3, handler: nil)
    }
}

class AutomaticResultInjectionTests: ResultInjectionTests {

    func test__requirement_is_injected() {
        processing.injectResultFromDependency(retrieval)

        addCompletionBlockToTestOperation(processing, withExpectation: expectationWithDescription("Test: \(__FUNCTION__)"))
        runOperations(retrieval, processing)
        waitForExpectationsWithTimeout(3, handler: nil)

        XCTAssertEqual(processing.requirement, retrieval.result)
    }

    func test__processing_cancels_with_errors_if_dependency_errors() {
        retrieval = TestOperation(error: TestOperation.Error.SimulatedError)
        processing.injectResultFromDependency(retrieval)
        processing.addObserver(CancelledObserver { op in
            XCTAssertEqual(op.errors.count, 1)
            guard let error = op.errors.first as? AutomaticInjectionError else {
                XCTFail("Incorrect error received")
                return
            }

            switch error {
            case .DependencyFinishedWithErrors(let errors):
                XCTAssertEqual(errors.count, 1)
                guard let _ = errors.first as? TestOperation.Error else {
                    XCTFail("Incorrect error received")
                    return
                }
            default:
                XCTFail("Incorrect error received")
            }
        })

        addCompletionBlockToTestOperation(processing, withExpectation: expectationWithDescription("Test: \(__FUNCTION__)"))
        runOperations(retrieval, processing)
        waitForExpectationsWithTimeout(3, handler: nil)

        XCTAssertTrue(processing.cancelled)
    }
}
