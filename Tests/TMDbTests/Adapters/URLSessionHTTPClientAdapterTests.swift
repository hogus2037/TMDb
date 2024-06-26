//
//  URLSessionHTTPClientAdapterTests.swift
//  TMDb
//
//  Copyright © 2024 Adam Young.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an AS IS BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

@testable import TMDb
import XCTest
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

final class URLSessionHTTPClientAdapterTests: XCTestCase {

    var httpClient: URLSessionHTTPClientAdapter!
    var baseURL: URL!
    var urlSession: URLSession!

    override func setUpWithError() throws {
        try super.setUpWithError()
        baseURL = try XCTUnwrap(URL(string: "https://some.domain.com/path"))

        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockURLProtocol.self]
        urlSession = URLSession(configuration: configuration)
        httpClient = URLSessionHTTPClientAdapter(urlSession: urlSession)
    }

    override func tearDown() async throws {
        httpClient = nil
        urlSession = nil
        baseURL = nil
        await MockURLProtocol.reset()
        try await super.tearDown()
    }

    @MainActor
    func testPerformWhenResponseStatusCodeIs401ReturnsUnauthorisedError() async throws {
        MockURLProtocol.responseStatusCode = 401
        let url = try XCTUnwrap(URL(string: "/error"))
        let request = HTTPRequest(url: url)

        let response: HTTPResponse
        do {
            response = try await httpClient.perform(request: request)
        } catch {
            XCTFail("Unexpected error thrown")
            return
        }

        XCTAssertEqual(response.statusCode, 401)
    }

    @MainActor
    func testPerformWhenResponseStatusCodeIs404ReturnsNotFoundError() async throws {
        MockURLProtocol.responseStatusCode = 404
        let url = try XCTUnwrap(URL(string: "/error"))
        let request = HTTPRequest(url: url)

        let response: HTTPResponse
        do {
            response = try await httpClient.perform(request: request)
        } catch {
            XCTFail("Unexpected error thrown")
            return
        }

        XCTAssertEqual(response.statusCode, 404)
    }

    @MainActor
    func testPerformWhenResponseStatusCodeIs404AndHasStatusMessageErrorThrowsNotFoundErrorWithMessage() async throws {
        MockURLProtocol.responseStatusCode = 404
        let expectedData = try Data(fromResource: "error-status-response", withExtension: "json")
        MockURLProtocol.data = expectedData
        let url = try XCTUnwrap(URL(string: "/error"))
        let request = HTTPRequest(url: url)

        let response: HTTPResponse
        do {
            response = try await httpClient.perform(request: request)
        } catch {
            XCTFail("Unexpected error thrown")
            return
        }

        XCTAssertEqual(response.statusCode, 404)
        XCTAssertEqual(response.data, expectedData)
    }

    @MainActor
    func testGetWhenResponseHasValidDataReturnsDecodedObject() async throws {
        let expectedStatusCode = 200
        let expectedData = Data("abc".utf8)
        MockURLProtocol.data = expectedData
        let url = try XCTUnwrap(URL(string: "/object"))
        let request = HTTPRequest(url: url)

        let response = try await httpClient.perform(request: request)

        XCTAssertEqual(response.statusCode, expectedStatusCode)
        XCTAssertEqual(response.data, expectedData)
    }

}

#if !canImport(FoundationNetworking)
    extension URLSessionHTTPClientAdapterTests {

        @MainActor
        func testPerformURLRequestHasCorrectURL() async throws {
            let path = "/object?key1=value1&key2=value2"
            let expectedURL = try XCTUnwrap(URL(string: path))
            let request = HTTPRequest(url: expectedURL)

            _ = try? await httpClient.perform(request: request)

            let result = MockURLProtocol.lastRequest?.url

            XCTAssertEqual(result, expectedURL)
        }

        @MainActor
        func testPerformWhenHeaderSetShouldBePresentInURLRequest() async throws {
            let url = try XCTUnwrap(URL(string: "/object"))
            let header1Name = "Accept"
            let header1Value = "application/json"
            let header2Name = "Content-Type"
            let header2Value = "text/html"
            let headers = [
                header1Name: header1Value,
                header2Name: header2Value
            ]
            let request = HTTPRequest(url: url, headers: headers)

            _ = try? await httpClient.perform(request: request)

            let lastURLRequest = try XCTUnwrap(MockURLProtocol.lastRequest)
            let result1 = lastURLRequest.value(forHTTPHeaderField: header1Name)
            let result2 = lastURLRequest.value(forHTTPHeaderField: header2Name)

            XCTAssertEqual(result1, header1Value)
            XCTAssertEqual(result2, header2Value)
        }

    }
#endif
