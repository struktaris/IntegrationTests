import Testing
import Foundation
@testable import IntegrationTests

@Suite struct IntegrationTestsTests {
    
    @Test func gettingTests() throws {
        let testResources = URL(fileURLWithPath: ProcessInfo.processInfo.environment["PACKAGE_DIRECTORY"]!).appending(component: "TestResources")
        let tests = try getTests(
            in: testResources,
            usingEnvironmentVariables: false // keeping the references to the environment variables for this test!
        )
        #expect(
            tests == [
                LocatedIntegrationTest(
                    relativeDirectory: "tests/1",
                    integrationTest: IntegrationTest(
                        source: "source",
                        test: "test",
                        reference: "reference",
                        executable: "$EXECUTABLE",
                        arguments: ["$FILE1", "$FILE2"],
                        ignoreFileNames: ["*.log"],
                        ignoreRelativePaths: nil
                        
                    )
                ),
                LocatedIntegrationTest(
                    relativeDirectory: "tests/2",
                    integrationTest: IntegrationTest(
                        source: "source",
                        test: "test",
                        reference: "reference",
                        executable: "$EXECUTABLE",
                        arguments: ["$FILE1", "$FILE2"],
                        ignoreFileNames: nil,
                        ignoreRelativePaths: ["*.log"]
                    )
                )
            ]
        )
    }
    
    @Test func makingRegexText() throws {
        #expect(makeRegexText(from: "*.log") == #"^.*\.log$"#)
        #expect(makeRegexText(from: #"*.\*"#) == #"^.*\.\*$"#)
    }
    
    @Test func directoryComparison() throws {
        let comparisonTests = URL(fileURLWithPath: ProcessInfo.processInfo.environment["PACKAGE_DIRECTORY"]!).appending(component: "TestResources").appending(component: "comparisonTests")
        
        func doIt(ignoreEmptyDirectories: Bool, ignoringFileNames: [String]? = nil, ignoringRelativePaths: [String]? = nil) throws -> [String] {
            try differentFiles(
                in: comparisonTests.appending(component: "test"),
                comparedTo: comparisonTests.appending(component: "reference"),
                ignoreEmptyDirectories: ignoreEmptyDirectories,
                ignore: { fileNameWithRelativePath in
                    ([".gitignore", ".DS_Store", "Thumbs.db"] + (ignoringFileNames ?? [])).contains(fileNameWithRelativePath.fileName) ||
                    ignoringRelativePaths?.contains(fileNameWithRelativePath.relativePath) == true
                }
            ).sorted(by: { $0.compare($01, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedAscending})
        }
        
        do {
            let result = try doIt(ignoreEmptyDirectories: true)
            #expect(result == ["2.txt", "a/a3.txt", "a/aa/aa2.txt", "x"])
        }
        
        do {
            let result = try doIt(ignoreEmptyDirectories: true, ignoringFileNames: ["a3.txt"])
            #expect(result == ["2.txt", "a/aa/aa2.txt", "x"])
        }
        
        do {
            let result = try doIt(ignoreEmptyDirectories: true, ignoringRelativePaths: ["a/a3.txt"])
            #expect(result == ["2.txt", "a/aa/aa2.txt", "x"])
        }
        
        do {
            let result = try doIt(ignoreEmptyDirectories: true, ignoringRelativePaths: ["a/aa"])
            #expect(result == ["2.txt", "a/a3.txt", "x"])
        }
        
        do {
            let result = try doIt(ignoreEmptyDirectories: false)
            #expect(result == ["2.txt", "a/a3.txt", "a/aa/aa2.txt", "a/ab", "c", "d", "x"])
        }
    }
    
    @Test func executingTests() async throws {
        let testResources = URL(fileURLWithPath: ProcessInfo.processInfo.environment["PACKAGE_DIRECTORY"]!).appending(component: "TestResources")
        print()
        let differentFilesForTests = try await executeTests(in: testResources)
        print()
        print(differentFilesForTests)
        #expect(differentFilesForTests == ["tests/1": [], "tests/2": ["b.txt"]])
        print()
    }
    
}
