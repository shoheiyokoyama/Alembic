//
//  DistilTest.swift
//  Tests
//
//  Created by Ryo Aoyama on 3/26/16.
//  Copyright © 2016 Ryo Aoyama. All rights reserved.
//

import Foundation
import XCTest
@testable import Alembic

class DistilTest: XCTestCase {
    let object = distilTestJSONObject
    
    func testDistil() {
        let j = JSON(object)
        
        do {
            let string: String = try j <| "string"
            let int: Int = try j <| "int"
            let double: Double = try j <| "double"
            let float: Float = try j <| "float"
            let bool: Bool = try j <| "bool"
            let array: [String] = try j <| "array"
            let dictionary: [String: Int] = try j <| "dictionary"
            let nestedValue: Int = try j <| ["nested", "array", 2]
            let nestedArray: [Int] = try j <| ["nested", "array"]
            
            XCTAssertEqual(string, "Alembic")
            XCTAssertEqual(int, 777)
            XCTAssertEqual(double, 77.7)
            XCTAssertEqual(float, 77.7)
            XCTAssertEqual(bool, true)
            XCTAssertEqual(array, ["A", "B", "C"])
            XCTAssertEqual(dictionary, ["A": 1, "B": 2, "C": 3])
            XCTAssertEqual(nestedValue, 3)
            XCTAssertEqual(nestedArray, [1, 2, 3, 4, 5])
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testDistilSubscript() {
        do {
            let j = JSON(object)
            
            let string: String = try j["string"].distil()
            let array: [String] = try j["array"].distil()
            let dictionary: [String: Int] = try j["dictionary"].distil()
            let nestedValue: Int = try j["nested", "array", 2].distil()
            let subscriptChain: Int = try j["nested"]["array"][2].distil()
            
            XCTAssertEqual(string, "Alembic")
            XCTAssertEqual(array, ["A", "B", "C"])
            XCTAssertEqual(dictionary, ["A": 1, "B": 2, "C": 3])
            XCTAssertEqual(nestedValue, 3)
            XCTAssertEqual(subscriptChain, 3)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testDistilHandler() {
        let j = JSON(object)
        
        j.distil(["user", "name"], as: String.self)
            .value { XCTAssertEqual($0, "ra1028") }
            .error { XCTFail("\($0)") }
        
        j.option("null", as: (String?).self)
            .value { XCTAssertEqual($0, nil) }
            .error { XCTFail("\($0)") }
        
        j.distil(["user", "name"], as: String.self)
            .map { s -> String in "User name is " + s }
            .value { XCTAssertEqual($0, "User name is ra1028") }
            .error { XCTFail("\($0)") }
            .filter { _ in false }
            .value { _ in XCTFail("Expect the error to occur") }
            .error {
                if case let DistillError.filteredValue(type, value) = $0 {
                    XCTAssertNotNil(type as? String.Type)
                    XCTAssertEqual(value as? String, "User name is ra1028")
                    return
                }
                XCTFail("\($0)")
        }
    }
    
    func testDistillError() {
        let j = JSON(object)
        
        do {
            _ = try (j <| "missing_key").to(String.self)
            
            XCTFail("Expect the error to occur")
        } catch let DistillError.missingPath(path) where path == "missing_key" {
            XCTAssert(true)
        } catch let e {
            XCTFail("\(e)")
        }
        
        do {
            _ = try (j <| "int_string").to(Int.self)
            
            XCTFail("Expect the error to occur")
        } catch let DistillError.typeMismatch(expected: expected, actual: actual, path: path) {
            XCTAssert(expected == Int.self)
            XCTAssertEqual(actual as? String, "1")
            XCTAssertEqual(path, "int_string")
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testClassMapping() {
        let j = JSON(object)
        
        do {
            let user: User = try j <| "user"
            
            XCTAssertEqual(user.id, 100)
            XCTAssertEqual(user.name, "ra1028")
            XCTAssertEqual(user.weight, 132.28)
            XCTAssertEqual(user.gender, Gender.male)
            XCTAssertEqual(user.smoker, true)
            XCTAssertEqual(user.email, "r.fe51028.r@gmail.com")
            XCTAssertEqual(user.url.absoluteString, "https://github.com/ra1028")
            XCTAssertEqual(user.friends.count, 1)
        } catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testStructMapping() {
        do {
            let j = JSON(object)
            
            let numbers: Numbers = try j <| "numbers"
            
            XCTAssertEqual(numbers.number, 1)
            XCTAssertEqual(numbers.int8, 2)
            XCTAssertEqual(numbers.uint8, 3)
            XCTAssertEqual(numbers.int16, 4)
            XCTAssertEqual(numbers.uint16, 5)
            XCTAssertEqual(numbers.int32, 6)
            XCTAssertEqual(numbers.uint32, 7)
            XCTAssertEqual(numbers.int64, 8)
            XCTAssertEqual(numbers.uint64, 9)
        } catch let e {
            XCTFail("\(e)")
        }
    }
}

#if os(Linux)
extension DistilTest {
    static var allTests: [(String, (DistilTest) -> () throws -> Void)] {
        return [
            ("testDistil", testDistil),
            ("testDistilSubscript", testDistilSubscript),
            ("testDistilHandler", testDistilHandler),
            ("testDistillError", testDistillError),
            ("testClassMapping", testClassMapping),
            ("testStructMapping", testStructMapping),
        ]
    }
}
#endif

extension URL: Distillable {
    public static func distil(json j: JSON) throws -> URL {
        return try j.distil().flatMap(self.init(string:))
    }
}

private enum Gender: String, Distillable {
    case male = "male"
    case female = "female"
}

private final class User: Brewable {
    let id: Int
    let name: String
    let weight: Double
    let gender: Gender
    let smoker: Bool
    let email: String
    let url: URL
    let friends: [User]
    
    required init(json j: JSON) throws {
        _ = try (id = j <| "id",
                 name = j <| "name",
                 weight = j <| "weight",
                 gender = j <| "gender",
                 smoker = j <| "smoker",
                 email = j <| ["contact", "email"],
                 url = j <| ["contact", "url"],
                 friends = j <| "friends")
    }
}

private struct Numbers: Distillable {
    let number: NSNumber
    let int8: Int8
    let uint8: UInt8
    let int16: Int16
    let uint16: UInt16
    let int32: Int32
    let uint32: UInt32
    let int64: Int64
    let uint64: UInt64
    
    fileprivate static func distil(json j: JSON) throws -> Numbers {
        return try Numbers(
            number: j <| "number",
            int8: j <| "int8",
            uint8: j <| "uint8",
            int16: j <| "int16",
            uint16: j <| "uint16",
            int32: j <| "int32",
            uint32: j <| "uint32",
            int64: j <| "int64",
            uint64: j <| "uint64"
        )
    }
}
