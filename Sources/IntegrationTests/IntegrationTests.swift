import Foundation
import Utilities

public struct IntegrationTest: Equatable, Decodable {
    let source: String
    let test: String
    let reference: String
    let environmentVariableForExecutable: String
    let arguments: [String]
}

public struct LocatedIntegrationTest: Equatable {
    let relativeDirectory: String
    let integrationTest: IntegrationTest
    
    func url(forTopDirectory topDirectory: URL) -> URL {
        topDirectory.appending(relativePath: relativeDirectory)
    }
    
    func url(forRelativePath relativePath: String, forTopDirectory topDirectory: URL) -> URL {
        url(forTopDirectory: topDirectory).appending(component: relativePath)
    }
}

public func getTests(in directory: URL) throws -> [LocatedIntegrationTest] {
    try directory.files(withPattern: /^test\.json$/, findRecursively: true).map { file in
        let integrationTest: IntegrationTest
        do {
            integrationTest = try JSONDecoder().decode(IntegrationTest.self, from: try Data(contentsOf: file))
        } catch {
            throw ErrorWithDescription("could not decode \(file.osPath): \(String(describing: error))")
        }
        return LocatedIntegrationTest(
            relativeDirectory: try file.deletingLastPathComponent().relativePathComponents(to: directory).joined(separator: "/"),
            integrationTest: integrationTest
        )
    }
}

func differentFiles(in lhs: URL, comparedTo rhs: URL, except: [String]? = nil) throws -> [String] {
    var differentFiles = [String]()
    for lhsFile in try lhs.files(withPattern: ".*", findRecursively: true) {
        let fileName = lhsFile.lastPathComponent
        if except?.contains(fileName) == true { continue }
        guard let lhsData = try? Data(contentsOf: lhsFile) else {
            throw ErrorWithDescription("could not read \(lhsFile.osPath)")
        }
        let rhsFile = rhs.appending(component: fileName)
        guard let rhsData = try? Data(contentsOf: rhsFile) else {
            throw ErrorWithDescription("could not read \(rhsFile.osPath)")
        }
        if lhsData != rhsData {
            differentFiles.append(fileName)
        }
    }
    return differentFiles
}

/// returns a list of non-equal files for every test directory
public func executeTests(in directory: URL) async throws  -> [String:[String]] {
    try await execute(locatedIntgrationTests: getTests(in: directory), withTopDirectory: directory)
}

/// returns a list of non-equal files for every test directory
public func execute(locatedIntgrationTests: [LocatedIntegrationTest], withTopDirectory topDirectory: URL) async throws -> [String:[String]] {
    var nonEqualFilesForTests = [String:[String]]()
    for locatedIntgrationTest in locatedIntgrationTests {
        nonEqualFilesForTests[locatedIntgrationTest.relativeDirectory] =  try await execute(locatedIntgrationTest: locatedIntgrationTest, withTopDirectory: topDirectory)
    }
    return nonEqualFilesForTests
}

let ignoredFiles = [
    ".gitignore"
]

func allFiles(in directory: URL) throws -> [URL] {
    try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [])
        .filter({!ignoredFiles.contains($0.lastPathComponent)  })
}

/// returns a list of non-equal files
public func execute(locatedIntgrationTest: LocatedIntegrationTest, withTopDirectory topDirectory: URL) async throws -> [String] {
    
    print("\n------- TEST: \(locatedIntgrationTest.relativeDirectory)")
    
    let sourceDirectory = locatedIntgrationTest.url(forRelativePath: locatedIntgrationTest.integrationTest.source, forTopDirectory: topDirectory)
    let testDirectory = locatedIntgrationTest.url(forRelativePath: locatedIntgrationTest.integrationTest.test, forTopDirectory: topDirectory)
    let referenceDirectory = locatedIntgrationTest.url(forRelativePath: locatedIntgrationTest.integrationTest.reference, forTopDirectory: topDirectory)
    
    func test(directory: URL, description: String) throws {
        print("\(description): \(directory.osPath)")
        guard directory.exists else {
            throw ErrorWithDescription("\(description) \(directory.osPath) does not exist")
        }
        guard directory.isDirectory else {
            throw ErrorWithDescription("\(description) \(directory.osPath) is not a directory")
        }
    }
    
    try test(directory: sourceDirectory, description: "source")
    try test(directory: testDirectory, description: "test")
    try test(directory: referenceDirectory, description: "reference")
    
    for file in try allFiles(in: testDirectory) {
        try FileManager.default.removeItem(at: file)
    }
    
    for file in try allFiles(in: sourceDirectory) {
        try FileManager.default.copyItem(at: file, to: testDirectory.appending(component: file.lastPathComponent))
    }
    
    guard let executablePath = ProcessInfo.processInfo.environment[locatedIntgrationTest.integrationTest.environmentVariableForExecutable] else {
        throw ErrorWithDescription("could not find environment variable \"\(locatedIntgrationTest.integrationTest.environmentVariableForExecutable)\"")
    }
    
    let executable = URL(fileURLWithPath: executablePath)
    
    do {
        let returnValue = await runProgram(
            executableURL: executable,
            arguments: locatedIntgrationTest.integrationTest.arguments,
            currentDirectoryURL: testDirectory,
            outputHandler: { print($0) }
        )
        guard let returnValue else {
            throw ErrorWithDescription("clould not call \(executable.osPath)")
        }
        guard returnValue == 0 else {
            throw ErrorWithDescription("execution of \(executable.osPath) resulted in return value \(returnValue)")
        }
    }
    
    return try differentFiles(in: testDirectory, comparedTo: referenceDirectory, except: ignoredFiles)
}
