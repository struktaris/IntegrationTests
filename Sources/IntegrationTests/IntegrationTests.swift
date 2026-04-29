import Foundation
import Utilities

public struct IntegrationTest: Equatable, Decodable {
    
    let source: String
    let test: String
    let reference: String
    let executable: String
    let arguments: [String]
    let ignore: [String]
    
    func usingEnvironmentVariables() throws -> IntegrationTest {
        
        func usingEnvironmentVariable(for value: String) throws -> String {
            if value.hasPrefix("$") {
                let environmentVariable = String(value.dropFirst())
                guard let newValue = ProcessInfo.processInfo.environment[environmentVariable] else {
                    throw ErrorWithDescription("environment variable \"\(environmentVariable)\" not set")
                }
                return newValue
            } else {
                return value
            }
        }
        
        return IntegrationTest(
            source: source,
            test: test,
            reference: try usingEnvironmentVariable(for: reference),
            executable: try usingEnvironmentVariable(for: executable),
            arguments: try arguments.map { try usingEnvironmentVariable(for: $0) },
            ignore: ignore
        )
        
    }
    
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

public func getTests(in directory: URL, usingEnvironmentVariables: Bool = true) throws -> [LocatedIntegrationTest] {
    try directory.files(withPattern: /^test\.json$/, findRecursively: true).map { file in
        let integrationTest: IntegrationTest
        do {
            integrationTest = try JSONDecoder().decode(IntegrationTest.self, from: try Data(contentsOf: file))
        } catch {
            throw ErrorWithDescription("could not decode \(file.osPath): \(String(describing: error))")
        }
        return LocatedIntegrationTest(
            relativeDirectory: try file.deletingLastPathComponent().relativePathComponents(to: directory).joined(separator: "/"),
            integrationTest: try usingEnvironmentVariables ? integrationTest.usingEnvironmentVariables() : integrationTest
        )
    }
}

func differentFiles(
    in lhs: URL,
    comparedTo rhs: URL,
    ignoreEmptyDirectories: Bool = true,
    ignore: ((String) -> Bool)? = nil
) throws -> Set<String> {
    var collectedDifferentFiles = Set<String>()
    
    try doTraversal(directoryToBeTraversed: lhs, directoryToBeComparedWith: rhs, ignoreExistingOther: false)
    try doTraversal(directoryToBeTraversed: rhs, directoryToBeComparedWith: lhs, ignoreExistingOther: true)
    
    func doTraversal(directoryToBeTraversed: URL, directoryToBeComparedWith: URL, ignoreExistingOther: Bool) throws {
        guard directoryToBeTraversed.isDirectory else { return }
        for file in try FileManager.default.contentsOfDirectory(at: directoryToBeTraversed, includingPropertiesForKeys: nil) {
            let fileName = file.lastPathComponent
            if ignore?(fileName) == true { continue }
            if file.isDirectory {
                let subdirectoryToBeComparedWith = directoryToBeComparedWith.appending(component: fileName)
                guard subdirectoryToBeComparedWith.isDirectory else {
                    if !ignoreEmptyDirectories || subdirectoryToBeComparedWith.exists {
                        collectedDifferentFiles.insert(fileName)
                    }
                    continue
                }
                guard !ignoreExistingOther else {
                    continue
                }
                for differentFile in try differentFiles(
                    in: file,
                    comparedTo: subdirectoryToBeComparedWith,
                    ignoreEmptyDirectories: ignoreEmptyDirectories,
                    ignore: ignore
                ) {
                    collectedDifferentFiles.insert("\(fileName)/\(differentFile)")
                }
                continue
            }
            
            let fileToBeCompared = directoryToBeComparedWith.appending(component: fileName)
            guard fileToBeCompared.isFile else {
                collectedDifferentFiles.insert(fileName)
                continue
            }
            guard !ignoreExistingOther else {
                continue
            }
            guard let fileData = try? Data(contentsOf: file) else {
                throw ErrorWithDescription("could not read \(file.osPath)")
            }
            guard let fileToBeComparedData = try? Data(contentsOf: fileToBeCompared) else {
                throw ErrorWithDescription("could not read \(fileToBeCompared.osPath)")
            }
            if fileData != fileToBeComparedData {
                collectedDifferentFiles.insert(fileName)
            }
        }
    }
    
    return collectedDifferentFiles
}

/// returns a list of non-equal files for every test directory
public func executeTests(in directory: URL) async throws  -> [String:[String]] {
    try await execute(locatedIntgrationTests: getTests(in: directory), withTopDirectory: directory)
}

/// returns a list of non-equal files for every test directory
public func execute(locatedIntgrationTests: [LocatedIntegrationTest], withTopDirectory topDirectory: URL) async throws -> [String:[String]] {
    var nonEqualFilesForTests = [String:[String]]()
    var newline = false
    for locatedIntgrationTest in locatedIntgrationTests {
        if newline { print() } else { newline = true }
        nonEqualFilesForTests[locatedIntgrationTest.relativeDirectory] =  try await execute(locatedIntgrationTest: locatedIntgrationTest, withTopDirectory: topDirectory)
    }
    return nonEqualFilesForTests
}

nonisolated(unsafe) let ignoredFiles = /^(\.gitignore|\.DS_Store|Thumbs\.db|.*\.log)$/

func allFiles(in directory: URL) throws -> [URL] {
    try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [])
        .filter({ !$0.lastPathComponent.contains(ignoredFiles) })
}

/// returns a list of non-equal files
public func execute(locatedIntgrationTest: LocatedIntegrationTest, withTopDirectory topDirectory: URL) async throws -> [String] {
    
    print("------- TEST: \(locatedIntgrationTest.relativeDirectory)")
    
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
    
    let executable = URL(fileURLWithPath: locatedIntgrationTest.integrationTest.executable)
    
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
    
    let regexes = try locatedIntgrationTest.integrationTest.ignore.map { try Regex("^\($0.replacing(".", with: #"\."#).replacing("*", with: ".*"))$") }
    
    return try differentFiles(in: testDirectory, comparedTo: referenceDirectory, ignore: { fileName in regexes.contains(where: { fileName.contains($0) }) })
        .sorted(by: { $0.compare($01, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedAscending})
}
